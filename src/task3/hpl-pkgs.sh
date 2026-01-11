#!/bin/bash
# ------------------------------------------------------------
# Script: hpl-pkgs.sh
# Purpose: Install required HPL and MPI packages on all nodes
# OS: AlmaLinux 9.x (CRB enabled)
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
    echo "[$NODE] Enabling CRB repository..."
    sudo dnf config-manager --set-enabled crb

    echo "[$NODE] Installing required packages..."
    sudo dnf install -y ${PACKAGES[*]}

    echo "[$NODE] Package installation complete."
EOF
done

echo
echo "=== Package installation completed on all nodes ==="
