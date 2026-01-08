#!/bin/bash
# setup_mpi_cluster_robust.sh
# Only configures the cluster for MPI

USER="hpcuser"
NODES=("controller" "worker1" "worker2")
SLOTS_PER_NODE=2
HOSTFILE="/home/$USER/hosts.txt"

# --- Step 0: Verify SSH connectivity ---
echo "Checking SSH connectivity to all nodes..."
for NODE in "${NODES[@]}"; do
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$USER@$NODE" "echo SSH to $NODE OK" || {
    echo "ERROR: Cannot SSH into $NODE. Ensure passwordless SSH is set up."
    exit 1
  }
done
echo "All nodes reachable via SSH."

# --- Step 1: Install OpenMPI and compilers ---
echo "Installing OpenMPI and compilers on all nodes..."
for NODE in "${NODES[@]}"; do
  ssh "$USER@$NODE" "sudo dnf install -y openmpi openmpi-devel gcc gcc-c++"
done

# --- Step 2: Configure environment variables ---
echo "Configuring OpenMPI environment variables..."
for NODE in "${NODES[@]}"; do
  ssh "$USER@$NODE" "grep -qxF 'export PATH=/usr/lib64/openmpi/bin:\$PATH' ~/.bashrc || echo 'export PATH=/usr/lib64/openmpi/bin:\$PATH' >> ~/.bashrc"
  ssh "$USER@$NODE" "grep -qxF 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH' ~/.bashrc || echo 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH' >> ~/.bashrc"
done

# Reload environment for current session
export PATH=/usr/lib64/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH

# --- Step 3: Create hosts file ---
echo "Creating MPI hosts file at $HOSTFILE..."
>"$HOSTFILE"
for NODE in "${NODES[@]}"; do
  echo "$NODE slots=$SLOTS_PER_NODE" >>"$HOSTFILE"
done
cat "$HOSTFILE"

echo "MPI cluster setup complete. Ready to compile/run MPI programs."
