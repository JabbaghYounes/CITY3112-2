#!/bin/bash
# ------------------------------------------------------------
# Script: install_hpl_packages.sh
# Purpose: Install required HPL and MPI packages on all nodes
# User: hpcuser
# Nodes: controller, worker1, worker2, worker3
# ------------------------------------------------------------

NODES=("controller" "worker1" "worker2" "worker3")

PACKAGES=(
  gcc
  gcc-c++
  make
  openmpi
  openmpi-devel
  openblas
  openblas-devel
  wget
  tar
)

echo "=== Starting cluster-wide package installation ==="

for NODE in "${NODES[@]}"; do
  echo
  echo ">>> Connecting to $NODE"
  ssh "$NODE" bash <<EOF
    echo "[$NODE] Installing required packages..."
    sudo dnf install -y ${PACKAGES[*]}
    echo "[$NODE] Package installation complete."
EOF
done

echo
echo "=== Package installation completed on all nodes ==="
