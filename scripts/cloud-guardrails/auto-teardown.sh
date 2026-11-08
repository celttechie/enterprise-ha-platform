#!/usr/bin/env bash
# =============================================================================
# Automated Ephemeral Testbed Teardown & Cost Guardrail Auditor (Milestone 2.4)
# =============================================================================
# Inspects running ephemeral cloud resources, verifies TTL safety, and enforces
# automated teardown to guarantee a $0.00 idle footprint.
# =============================================================================

set -euo pipefail

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TARGET="aws"
TTL_MINUTES=0
AUDIT_ONLY=false
DRY_RUN=false
AWS_REGION="${AWS_REGION:-us-east-2}"
CLUSTER_NAME="${CLUSTER_NAME:-enterprise-ha-eks}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    --target <aws|kvm>       Target environment (default: aws)
    --audit                  Audit active cloud resources and budget status without destroying
    --ttl <minutes>          Maximum allowed testbed age in minutes (e.g. 120)
    --dry-run                Simulate teardown without deleting resources
    --region <region>        AWS region (default: us-east-2)
    --cluster <name>         EKS cluster name (default: enterprise-ha-eks)
    -h, --help               Display this help message

Examples:
    # Audit current AWS resources and budget
    $(basename "$0") --audit

    # Enforce a 60-minute TTL on active AWS testbed
    $(basename "$0") --ttl 60

    # Dry-run TTL evaluation
    $(basename "$0") --ttl 60 --dry-run
EOF
    exit 0
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --audit)
            AUDIT_ONLY=true
            shift
            ;;
        --ttl)
            TTL_MINUTES="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# -----------------------------------------------------------------------------
# AWS Verification & Resource Inspection
# -----------------------------------------------------------------------------
audit_aws() {
    log_info "Auditing AWS resources in region ${AWS_REGION}..."

    # Check caller identity
    if ! CALLER_ID=$(aws sts get-caller-identity --output json 2>/dev/null); then
        log_error "AWS credentials not configured or expired. Run 'aws configure' or set AWS environment variables."
        return 1
    fi
    ACCOUNT_ID=$(echo "$CALLER_ID" | grep -o '"Account": *"[^"]*"' | cut -d'"' -f4)
    log_info "AWS Account: ${ACCOUNT_ID}"

    # Check EKS Clusters
    CLUSTERS=$(aws eks list-clusters --region "${AWS_REGION}" --output json 2>/dev/null | grep -o '"[^"]*"' | grep -v 'clusters' || true)
    if [ -n "$CLUSTERS" ]; then
        log_warn "Active EKS Cluster(s) found in ${AWS_REGION}: ${CLUSTERS}"
    else
        log_success "Zero active EKS clusters detected in ${AWS_REGION} (\$0.00 compute spend)."
    fi

    # Check VPCs with project tag
    PROJECT_VPCS=$(aws ec2 describe-vpcs --region "${AWS_REGION}" \
        --filters "Name=tag:Project,Values=enterprise-ha-platform" \
        --query "Vpcs[*].VpcId" --output text 2>/dev/null || true)
    if [ -n "$PROJECT_VPCS" ] && [ "$PROJECT_VPCS" != "None" ]; then
        log_warn "Active VPC(s) found for enterprise-ha-platform: ${PROJECT_VPCS}"
    else
        log_success "Zero project VPCs detected (\$0.00 network spend)."
    fi

    # Check NAT Gateways
    NAT_GWS=$(aws ec2 describe-nat-gateways --region "${AWS_REGION}" \
        --filter "Name=state,Values=available,pending" \
        --query "NatGateways[*].NatGatewayId" --output text 2>/dev/null || true)
    if [ -n "$NAT_GWS" ] && [ "$NAT_GWS" != "None" ]; then
        log_warn "Active NAT Gateway(s) detected: ${NAT_GWS}"
    else
        log_success "Zero active NAT Gateways detected (\$0.00 hourly NAT spend)."
    fi

    # Check CloudWatch EKS log groups
    LOG_GROUPS=$(aws logs describe-log-groups --region "${AWS_REGION}" \
        --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}" \
        --query "logGroups[*].logGroupName" --output text 2>/dev/null || true)
    if [ -n "$LOG_GROUPS" ] && [ "$LOG_GROUPS" != "None" ]; then
        log_warn "Lingering CloudWatch log group detected: ${LOG_GROUPS}"
    else
        log_success "Zero lingering CloudWatch log groups detected."
    fi

    # Check AWS Budgets if available
    log_info "Checking AWS Budgets status..."
    BUDGET_OUTPUT=$(aws budgets describe-budgets --account-id "${ACCOUNT_ID}" --region us-east-1 --query "Budgets[?BudgetName=='${CLUSTER_NAME}-monthly-budget']" --output json 2>/dev/null || true)
    if [ -n "$BUDGET_OUTPUT" ] && [ "$BUDGET_OUTPUT" != "[]" ] && [ "$BUDGET_OUTPUT" != "null" ]; then
        LIMIT=$(echo "$BUDGET_OUTPUT" | grep -A2 '"BudgetLimit"' | grep -o '"Amount": *"[^"]*"' | cut -d'"' -f4 || echo "N/A")
        SPEND=$(echo "$BUDGET_OUTPUT" | grep -A2 '"ActualSpend"' | grep -o '"Amount": *"[^"]*"' | cut -d'"' -f4 || echo "0.00")
        log_success "AWS Budget '${CLUSTER_NAME}-monthly-budget' active: Limit=\$${LIMIT} USD, ActualSpend=\$${SPEND} USD."
    else
        log_info "No budget alarm '${CLUSTER_NAME}-monthly-budget' currently provisioned."
    fi
}

# -----------------------------------------------------------------------------
# TTL Enforcement & Teardown
# -----------------------------------------------------------------------------
enforce_ttl_aws() {
    log_info "Checking cluster age for TTL enforcement (${TTL_MINUTES}m limit)..."

    # Check if cluster exists
    if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
        log_success "Cluster '${CLUSTER_NAME}' does not exist. No teardown needed."
        return 0
    fi

    # Get createdAt timestamp (Unix epoch or ISO8601)
    CREATED_AT=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
        --query "cluster.createdAt" --output text 2>/dev/null || true)

    if [ -z "$CREATED_AT" ] || [ "$CREATED_AT" = "None" ]; then
        log_warn "Unable to retrieve createdAt timestamp for cluster '${CLUSTER_NAME}'."
        return 0
    fi

    # Convert to epoch seconds
    # createdAt can be floating point unix timestamp or ISO8601 string depending on AWS CLI version
    if [[ "$CREATED_AT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        CREATED_EPOCH=$(printf "%.0f" "$CREATED_AT")
    else
        CREATED_EPOCH=$(date -d "$CREATED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED_AT" +%s 2>/dev/null || echo 0)
    fi

    CURRENT_EPOCH=$(date +%s)
    AGE_SECONDS=$(( CURRENT_EPOCH - CREATED_EPOCH ))
    AGE_MINUTES=$(( AGE_SECONDS / 60 ))

    log_info "Cluster '${CLUSTER_NAME}' age: ${AGE_MINUTES} minutes (TTL: ${TTL_MINUTES} minutes)."

    if [ "$AGE_MINUTES" -ge "$TTL_MINUTES" ]; then
        log_warn "Cluster age (${AGE_MINUTES}m) exceeds configured TTL (${TTL_MINUTES}m). Initiating automated teardown!"
        if [ "$DRY_RUN" = true ]; then
            log_warn "[DRY-RUN] Would execute: make destroy TARGET=aws"
        else
            log_info "Executing: tofu destroy in infra/environments/aws..."
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
            make -C "${REPO_ROOT}" destroy TARGET=aws
            log_success "Automated teardown completed successfully."
        fi
    else
        log_success "Cluster age (${AGE_MINUTES}m) is within safety TTL (${TTL_MINUTES}m). No teardown required."
    fi
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
if [ "$TARGET" != "aws" ]; then
    log_info "Target '${TARGET}' specified; cloud guardrail auditing is primarily targeted for AWS."
    exit 0
fi

if [ "$AUDIT_ONLY" = true ]; then
    audit_aws
    exit 0
fi

if [ "$TTL_MINUTES" -gt 0 ]; then
    enforce_ttl_aws
else
    # Default behavior without explicit flags: perform audit
    audit_aws
fi
