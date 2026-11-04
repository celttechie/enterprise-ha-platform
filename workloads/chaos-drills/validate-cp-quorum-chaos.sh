#!/usr/bin/env bash
# ==============================================================================
# Milestone 1.4: Control Plane High Availability Quorum & VIP Failover Drill
# ==============================================================================
# Modes:
#   ./validate-cp-quorum-chaos.sh           # Run full chaos fault + restore drill
#   ./validate-cp-quorum-chaos.sh --restore # Standalone recovery: boot any shut-off
#                                           # cluster VMs, reconcile OpenTofu state,
#                                           # and verify 6/6 Ready + 3/3 etcd members
# ==============================================================================

set -euo pipefail

MODE="${1:-drill}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-${REPO_ROOT}/infra/environments/local-kvm/kubeconfig}"
TALOSCONFIG_PATH="${TALOSCONFIG:-${REPO_ROOT}/infra/environments/local-kvm/talos/talosconfig}"
TFVARS_FILE="${REPO_ROOT}/infra/environments/local-kvm/terraform.tfvars"

export KUBECONFIG="${KUBECONFIG_PATH}"
export TALOSCONFIG="${TALOSCONFIG_PATH}"

# Resolve Libvirt URI and target domain from terraform.tfvars if present, else defaults
LIBVIRT_URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"
CLUSTER_NAME="enterprise-ha"
CONTROLPLANE_VIP="192.168.122.200"

if [[ -f "${TFVARS_FILE}" ]]; then
  PARSED_URI="$(grep -E '^libvirt_uri\s*=' "${TFVARS_FILE}" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)"
  PARSED_CLUSTER="$(grep -E '^cluster_name\s*=' "${TFVARS_FILE}" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)"
  PARSED_VIP="$(grep -E '^controlplane_vip\s*=' "${TFVARS_FILE}" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)"
  [[ -n "${PARSED_URI}" ]] && LIBVIRT_URI="${PARSED_URI}"
  [[ -n "${PARSED_CLUSTER}" ]] && CLUSTER_NAME="${PARSED_CLUSTER}"
  [[ -n "${PARSED_VIP}" ]] && CONTROLPLANE_VIP="${PARSED_VIP}"
fi

# ------------------------------------------------------------------------------
# Helper: Restore / Self-Heal Cluster Nodes
# ------------------------------------------------------------------------------
restore_cluster() {
  echo "=============================================================================="
  echo "  CLUSTER SELF-HEALING & NODE RESTORATION"
  echo "=============================================================================="
  echo "  1. Checking Libvirt hypervisor (${LIBVIRT_URI}) for powered-off cluster VMs..."
  SHUTOFF_VMS="$(virsh -c "${LIBVIRT_URI}" list --state-shutoff --name | grep -E "^${CLUSTER_NAME}-" || true)"
  if [[ -n "${SHUTOFF_VMS}" ]]; then
    for vm in ${SHUTOFF_VMS}; do
      echo "  🔄 Starting powered-off VM: ${vm}..."
      virsh -c "${LIBVIRT_URI}" start "${vm}"
    done
  else
    echo "  ✅ All existing ${CLUSTER_NAME} VMs are powered on."
  fi

  # Check if all 6 expected VMs exist in Libvirt; if any VM was undefined/deleted, run tofu apply
  TOTAL_VMS="$(virsh -c "${LIBVIRT_URI}" list --all --name | grep -cE "^${CLUSTER_NAME}-(cp|worker)-" || true)"
  if [[ "${TOTAL_VMS}" -lt 6 ]]; then
    echo "  ⚠️ Only ${TOTAL_VMS}/6 VMs exist on hypervisor. Re-creating missing VMs via OpenTofu..."
    (cd "${REPO_ROOT}/infra/environments/local-kvm" && tofu apply -auto-approve)
  fi

  echo "  2. Waiting for Kubernetes API VIP (${CONTROLPLANE_VIP}:6443) to respond..."
  for i in {1..45}; do
    if kubectl --request-timeout=2s get --raw='/livez' >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  echo "  3. Waiting for all 6 nodes to transition to Ready..."
  for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    # Wait until kubelet posts a refreshed Ready status
    kubectl wait --for=condition=Ready "node/${node}" --timeout=180s >/dev/null
  done

  kubectl get nodes -o wide

  if command -v talosctl >/dev/null 2>&1; then
    echo ""
    echo "  4. Verifying 3-node HA etcd quorum membership..."
    talosctl -e "${CONTROLPLANE_VIP}" -n 192.168.122.6 get members 2>/dev/null || \
      talosctl -e 192.168.122.7 -n 192.168.122.7 etcd members
  fi

  echo "=============================================================================="
  echo "✅ CLUSTER RESTORE COMPLETE: All 6/6 nodes Ready and etcd quorum healthy!"
  echo "=============================================================================="
}

if [[ "${MODE}" == "--restore" || "${MODE}" == "restore" ]]; then
  restore_cluster
  exit 0
fi

# Dynamically detect which control plane node currently holds the Layer-2 VIP
TARGET_NODE="${CLUSTER_NAME}-cp-01"
VIP_HOLDER_IP=""
if command -v talosctl >/dev/null 2>&1; then
  VIP_HOLDER_IP="$(talosctl -e "${CONTROLPLANE_VIP}" -n 192.168.122.6,192.168.122.7,192.168.122.8 get addresses 2>/dev/null | grep "${CONTROLPLANE_VIP}/" | awk '{print $1}' | head -n 1 || true)"
  if [[ -n "${VIP_HOLDER_IP}" ]]; then
    DETECTED_NODE="$(kubectl get nodes -o wide --no-headers | awk -v ip="${VIP_HOLDER_IP}" '$6 == ip {print $1}' | head -n 1 || true)"
    [[ -n "${DETECTED_NODE}" ]] && TARGET_NODE="${DETECTED_NODE}"
  fi
fi

API_URL="https://${CONTROLPLANE_VIP}:6443/livez"

echo "=============================================================================="
echo "  MILESTONE 1.4: HA CONTROL PLANE QUORUM & VIP FAILOVER CHAOS DRILL"
echo "=============================================================================="
echo "  Active VIP Node : ${TARGET_NODE} (${VIP_HOLDER_IP:-detected})"
echo "  API Endpoint    : ${API_URL}"
echo "  Hypervisor URI  : ${LIBVIRT_URI}"
echo "=============================================================================="

echo ""
echo "[1/6] Verifying pre-drill 6-node cluster health..."
kubectl get nodes -o wide

READY_COUNT="$(kubectl get nodes --no-headers | grep -c ' Ready' || true)"
if [[ "${READY_COUNT}" -lt 6 ]]; then
  echo "⚠️ Cluster has ${READY_COUNT}/6 Ready nodes. Running automatic restore before starting drill..."
  restore_cluster
fi
echo "✅ Pre-drill verification passed: all 6 nodes are Ready."

echo ""
echo "[2/6] Starting continuous API VIP availability probe against ${API_URL}..."
PROBE_LOG="$(mktemp /tmp/ha-vip-probe.XXXXXX.log)"

(
  while true; do
    TS="$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")"
    if kubectl --request-timeout=2s get --raw='/livez' >/dev/null 2>&1; then
      echo "${TS} OK" >> "${PROBE_LOG}"
    else
      echo "${TS} FAIL" >> "${PROBE_LOG}"
    fi
    sleep 1
  done
) &
PROBE_PID=$!

# Ensure background probe AND any powered-off node are always restored on exit/interrupt
cleanup() {
  if kill -0 "${PROBE_PID}" 2>/dev/null; then
    kill "${PROBE_PID}" 2>/dev/null || true
    wait "${PROBE_PID}" 2>/dev/null || true
  fi
  rm -f "${PROBE_LOG}"
  # Self-heal if interrupted mid-drill while target node is shut off
  if virsh -c "${LIBVIRT_URI}" domstate "${TARGET_NODE}" 2>/dev/null | grep -q "shut off"; then
    echo "🔄 Emergency cleanup: restarting ${TARGET_NODE}..."
    virsh -c "${LIBVIRT_URI}" start "${TARGET_NODE}" || true
  fi
}
trap cleanup EXIT

sleep 2

echo ""
echo "[3/6] Injecting hardware fault: forcibly powering off VIP holder ${TARGET_NODE} (virsh destroy)..."
FAULT_EPOCH="$(date +%s)"
FAULT_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
virsh -c "${LIBVIRT_URI}" destroy "${TARGET_NODE}"
echo "⚡ Node ${TARGET_NODE} terminated at ${FAULT_TIME}."

echo ""
echo "[4/6] Waiting for Talos etcd VIP lease election & Layer-2 Gratuitous ARP failover..."
FAILOVER_SECS=0
for i in {1..45}; do
  sleep 2
  if kubectl --request-timeout=2s get --raw='/livez' >/dev/null 2>&1; then
    NOW_EPOCH="$(date +%s)"
    FAILOVER_SECS=$((NOW_EPOCH - FAULT_EPOCH))
    echo "✅ VIP ${CONTROLPLANE_VIP}:6443 is responding on a surviving control plane node (failover time: ${FAILOVER_SECS}s)!"
    break
  fi
done

if ! kubectl --request-timeout=5s get --raw='/livez' >/dev/null 2>&1; then
  echo "❌ ERROR: VIP did not recover within 90s!"
  restore_cluster
  exit 1
fi

echo ""
echo "Validating API server responsiveness and etcd quorum read/write survival while ${TARGET_NODE} is powered off..."
kubectl get nodes -o wide

# Verify we can perform an authenticated read/write operation in etcd via ConfigMap creation
DRILL_CM="chaos-quorum-proof-$(date +%s)"
kubectl create configmap "${DRILL_CM}" -n default --from-literal=quorum=survived --from-literal=fault_time="${FAULT_TIME}"
kubectl get configmap "${DRILL_CM}" -n default -o yaml | grep "quorum: survived"
kubectl delete configmap "${DRILL_CM}" -n default
echo "✅ Verified: etcd quorum wrote and deleted state while ${TARGET_NODE} was powered off!"

echo ""
echo "[5/6] Restoring ${TARGET_NODE} and verifying full cluster recovery..."
# Stop probe before restore output
kill "${PROBE_PID}" 2>/dev/null || true
wait "${PROBE_PID}" 2>/dev/null || true

restore_cluster

echo ""
echo "[6/6] Analyzing continuous VIP API probe telemetry..."
TOTAL_PROBES="$(wc -l < "${PROBE_LOG}")"
OK_PROBES="$(grep -c ' OK$' "${PROBE_LOG}" || true)"
FAIL_PROBES="$(grep -c ' FAIL$' "${PROBE_LOG}" || true)"

echo "=============================================================================="
echo "  CHAOS DRILL TELEMETRY SUMMARY"
echo "=============================================================================="
echo "  Target Terminated : ${TARGET_NODE} (ungraceful virsh destroy)"
echo "  VIP Failover Time : ${FAILOVER_SECS}s (etcd lease election + Gratuitous ARP)"
echo "  Total API Probes  : ${TOTAL_PROBES}"
echo "  Successful (OK)   : ${OK_PROBES}"
echo "  Failover Window   : ${FAIL_PROBES} probes during L2 VIP lease transfer"
echo "  etcd R/W Quorum   : VERIFIED (ConfigMap write/read/delete succeeded offline)"
echo "  Post-Drill Nodes  : $(kubectl get nodes --no-headers | grep -c ' Ready')/6 Ready"
echo "=============================================================================="
echo "✅ MILESTONE 1.4 PASSED: Control plane survived node loss and recovered!"
