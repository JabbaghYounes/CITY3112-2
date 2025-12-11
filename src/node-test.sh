#!/bin/bash
nodes=("slave1-ip" "slave2-ip")

for node in "${nodes[@]}"; do
  echo "Running task on $node"
  ssh user@$node "echo 'Test job executed on: $(hostname)'"
done
