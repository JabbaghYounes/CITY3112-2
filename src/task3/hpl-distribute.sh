#!/bin/bash
# ------------------------------------------------------------
# Script: distribute_hpl.sh
# Purpose: Distribute HPL binaries and configs to worker nodes
# Source: controller node
# ------------------------------------------------------------

WORKERS=("worker1" "worker2" "worker3")
HPL_DIR="$HOME/hpl"

echo "=== Starting HPL distribution to worker nodes ==="

for NODE in "${WORKERS[@]}"; do
  echo
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
