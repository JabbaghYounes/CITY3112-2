#!/bin/bash
# setup_mpi_cluster_robust.sh
# Configures MPI environment on a 4-node HPC cluster

USER="hpcuser"
NODES=("controller" "worker1" "worker2" "worker3")
SLOTS_PER_NODE=2
HOSTFILE="/home/$USER/hosts.txt"

echo "Checking SSH connectivity to all nodes..."
for NODE in "${NODES[@]}"; do
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$USER@$NODE" "echo SSH to $NODE OK" || {
    echo "ERROR: Cannot SSH into $NODE. Fix SSH before continuing."
    exit 1
  }
done
echo "All nodes reachable via SSH."

echo "Installing OpenMPI and compilers on all nodes..."
for NODE in "${NODES[@]}"; do
  ssh "$USER@$NODE" "sudo dnf install -y openmpi openmpi-devel gcc gcc-c++"
done

echo "Configuring OpenMPI environment variables..."
for NODE in "${NODES[@]}"; do
  ssh "$USER@$NODE" \
    "grep -qxF 'export PATH=/usr/lib64/openmpi/bin:\$PATH' ~/.bashrc || \
       echo 'export PATH=/usr/lib64/openmpi/bin:\$PATH' >> ~/.bashrc"

  ssh "$USER@$NODE" \
    "grep -qxF 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH' ~/.bashrc || \
       echo 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH' >> ~/.bashrc"
done

export PATH=/usr/lib64/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH

echo "Creating MPI hosts file at $HOSTFILE..."
>"$HOSTFILE"
for NODE in "${NODES[@]}"; do
  echo "$NODE slots=$SLOTS_PER_NODE" >>"$HOSTFILE"
done

echo "Final hosts file:"
cat "$HOSTFILE"

echo "MPI cluster setup complete (4 nodes)."
