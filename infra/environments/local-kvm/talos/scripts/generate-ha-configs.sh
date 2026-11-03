#!/usr/bin/env bash
# ==============================================================================
# Talos High Availability Machine Config Generator
# Generates HA control plane configs with Layer-2 VIP and worker storage configs
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCHES_DIR="${TALOS_DIR}/patches"

CLUSTER_NAME="${1:-${TF_VAR_cluster_name:-enterprise-ha}}"
CONTROLPLANE_VIP="${2:-${TF_VAR_controlplane_vip:-192.168.122.200}}"
K8S_ENDPOINT="https://${CONTROLPLANE_VIP}:6443"

if ! command -v talosctl >/dev/null 2>&1; then
    echo "❌ Error: 'talosctl' CLI is required but not installed."
    exit 1
fi

echo "=============================================================================="
echo "          GENERATING TALOS HA MACHINE CONFIGURATIONS                          "
echo "=============================================================================="
echo "  Cluster Name:     ${CLUSTER_NAME}"
echo "  Control Plane VIP:${CONTROLPLANE_VIP}"
echo "  Kubernetes API:   ${K8S_ENDPOINT}"
echo "=============================================================================="

# 1. Generate secrets.yaml if not present
if [ ! -f "${TALOS_DIR}/secrets.yaml" ]; then
    echo "🔑 Generating new cluster PKI and secrets..."
    talosctl gen secrets -o "${TALOS_DIR}/secrets.yaml"
fi

# 2. Render VIP patch from template
VIP_PATCH="${TALOS_DIR}/00-vip.rendered.yaml"
sed "s|\${CONTROLPLANE_VIP}|${CONTROLPLANE_VIP}|g" \
    "${PATCHES_DIR}/00-controlplane-vip.yaml.tpl" > "${VIP_PATCH}"

# 3. Generate Machine Configs using talosctl with patches
echo "⚙️  Generating base machine configs..."
talosctl gen config "${CLUSTER_NAME}" "${K8S_ENDPOINT}" \
    --with-secrets "${TALOS_DIR}/secrets.yaml" \
    --config-patch-control-plane @"${VIP_PATCH}" \
    --config-patch-control-plane @"${PATCHES_DIR}/01-cilium-cni.yaml" \
    --config-patch-worker @"${PATCHES_DIR}/01-cilium-cni.yaml" \
    --config-patch-worker @"${PATCHES_DIR}/02-longhorn-worker-disk.yaml" \
    --output-dir "${TALOS_DIR}" \
    --force

# Cleanup temporary rendered patch
rm -f "${VIP_PATCH}"

echo ""
echo "✅ Talos HA machine configs successfully generated in ${TALOS_DIR}:"
echo "   - controlplane.yaml (configured with VIP: ${CONTROLPLANE_VIP} and Cilium CNI)"
echo "   - worker.yaml       (configured with Longhorn /dev/vdb mount)"
echo "   - talosconfig       (configured client targeting ${K8S_ENDPOINT})"
echo "=============================================================================="
