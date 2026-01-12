#!/bin/bash
# ------------------------------------------------------------
# Script: hpl-distribute.sh
# Purpose: Distribute HPL binaries and configs to worker nodes
# Source: controller node
# ------------------------------------------------------------

set -e

WORKERS=("worker1" "worker2" "worker3")
HPL_DIR="$HOME/hpl-2.3"

echo "=== Starting HPL distribution to worker nodes ==="

# ------------------------------------------------------------
# Verify rsync exists locally
# ------------------------------------------------------------
if ! command -v rsync >/dev/null 2>&1; then
  echo "ERROR: rsync is not installed on the controller node."
  echo "Install it first: sudo dnf install -y rsync"
  exit 1
fi

# ------------------------------------------------------------
# Distribute HPL to each worker
# ------------------------------------------------------------
for NODE in "${WORKERS[@]}"; do
  echo
  echo ">>> Checking rsync on $NODE"

  ssh "$NODE" '
    if ! command -v rsync >/dev/null 2>&1; then
      echo ">>> rsync not found on $(hostname), installing..."
      sudo dnf install -y rsync
      echo ">>> rsync installed on $(hostname)"
    else
      echo ">>> rsync already installed on $(hostname)"
    fi
  '

  echo ">>> Preparing HPL directory on $NODE"
  ssh "$NODE" "mkdir -p $HPL_DIR"

  echo ">>> Copying HPL files to $NODE"
  rsync -av \
    "$HPL_DIR/bin" \
    "$HPL_DIR/Make.Linux_OpenMPI" \
    "$HPL_DIR/HPL.dat" \
    "$NODE:$HPL_DIR/"

  echo ">>> HPL distribution completed for $NODE"
done

echo
echo "=== HPL successfully distributed to all worker nodes ==="
