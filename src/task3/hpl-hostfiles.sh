#!/bin/bash
# ------------------------------------------------------------
# Script: generate_hostfiles.sh
# Purpose: Generate MPI hostfiles for 1–4 node benchmarks
# ------------------------------------------------------------

NODES=("controller" "worker1" "worker2" "worker3")
SLOTS_PER_NODE=2

echo "=== Generating MPI hostfiles ==="

for ((i = 1; i <= 4; i++)); do
  HOSTFILE="hosts_${i}node.txt"
  echo ">>> Creating $HOSTFILE"

  # Clear existing file
  >"$HOSTFILE"

  # Add required number of nodes
  for ((j = 0; j < i; j++)); do
    echo "${NODES[$j]} slots=$SLOTS_PER_NODE" >>"$HOSTFILE"
  done

  echo ">>> $HOSTFILE created successfully"
done

echo
echo "=== All hostfiles generated ==="
