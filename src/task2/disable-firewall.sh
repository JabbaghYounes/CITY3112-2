#!/bin/bash
# disable-firewall.sh
# turns of firwalls on all cluster nodes for mpi-hello to work, to be ran on controller node

for n in controller worker1 worker2 worker3; do
  if [[ "$n" == "controller" ]]; then
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
  else
    ssh hpcuser@$n "sudo systemctl stop firewalld && sudo systemctl disable firewalld"
  fi
done
