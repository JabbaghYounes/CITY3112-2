#!/bin/bash
nodes=("worker-node1-ip" "worker-node2-ip")

for node in "${nodes[@]}"; do
  echo "Running task on $node"
  ssh user@$node "echo 'Test job executed on: $(hostname)'", "hostname && echo node is reachable"
done
