#!/bin/bash
# setup_mpi_cluster_robust.sh
# MPI cluster setup with built-in pre-flight checks

USER="hpcuser"
NODES=("controller" "worker1" "worker2" "worker3")
IPS=("192.168.122.10" "192.168.122.11" "192.168.122.12" "192.168.122.13")
SLOTS_PER_NODE=2
HOSTFILE="/home/$USER/hosts.txt"

echo "=== MPI CLUSTER PRE-FLIGHT CHECKS ==="

# --- 1. SSH connectivity ---
echo "[1/6] Checking passwordless SSH..."
for NODE in "${NODES[@]}"; do
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$USER@$NODE" "echo OK" >/dev/null 2>&1 || {
    echo "ERROR: Cannot SSH into $NODE as $USER"
    exit 1
  }
done
echo "✓ SSH connectivity OK"

# --- 2. Hostname correctness ---
echo "[2/6] Checking hostnames..."
for NODE in "${NODES[@]}"; do
  ACTUAL=$(ssh "$USER@$NODE" "hostname")
  if [[ "$ACTUAL" != "$NODE" ]]; then
    echo "ERROR: Hostname mismatch on $NODE (got $ACTUAL)"
    exit 1
  fi
done
echo "✓ Hostnames correct"

# --- 3. Static IP correctness ---
echo "[3/6] Checking IP addresses..."
for i in "${!NODES[@]}"; do
  NODE="${NODES[$i]}"
  EXPECTED_IP="${IPS[$i]}"
  ACTUAL_IP=$(ssh "$USER@$NODE" "ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep 192.168.122")
  if [[ "$ACTUAL_IP" != "$EXPECTED_IP" ]]; then
    echo "ERROR: $NODE has IP $ACTUAL_IP (expected $EXPECTED_IP)"
    exit 1
  fi
done
echo "✓ IP addresses correct"

# --- 4. Hostname resolution (/etc/hosts) ---
echo "[4/6] Checking hostname resolution..."
for NODE in "${NODES[@]}"; do
  for TARGET in "${NODES[@]}"; do
    ssh "$USER@$NODE" "getent hosts $TARGET" >/dev/null || {
      echo "ERROR: $NODE cannot resolve hostname $TARGET"
      exit 1
    }
  done
done
echo "✓ Hostname resolution OK"

# --- 5. Network reachability ---
echo "[5/6] Checking network reachability..."
for NODE in "${NODES[@]}"; do
  for TARGET in "${NODES[@]}"; do
    ssh "$USER@$NODE" "ping -c 1 -W 1 $TARGET" >/dev/null || {
      echo "ERROR: $NODE cannot ping $TARGET"
      exit 1
    }
  done
done
echo "✓ Network connectivity OK"

# --- 6. Sudo access ---
echo "[6/6] Checking sudo access..."
for NODE in "${NODES[@]}"; do
  ssh "$USER@$NODE" "sudo -n true" >/dev/null 2>&1 || {
    echo "ERROR: $USER does not have passwordless sudo on $NODE"
    exit 1
  }
done
echo "✓ Sudo access OK"

echo "=== ALL PRE-CHECKS PASSED ==="
echo

# --- MPI installation ---
echo "Installing OpenMPI and compilers..."
for NODE in "${NODES[@]}"; do
  ssh "$USER@$NODE" "sudo dnf install -y openmpi openmpi-devel gcc gcc-c++"
done

# --- Environment configuration ---
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

# --- Hosts file creation ---
echo "Creating MPI hostfile at $HOSTFILE..."
>"$HOSTFILE"
for NODE in "${NODES[@]}"; do
  echo "$NODE slots=$SLOTS_PER_NODE" >>"$HOSTFILE"
done

echo "Final MPI hostfile:"
cat "$HOSTFILE"

echo
echo "=== MPI CLUSTER SETUP COMPLETE (4 NODES) ==="
