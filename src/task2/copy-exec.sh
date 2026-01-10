#!/bin/bash
# copy-exec.sh
# duplicates hello world exectuable files to worker nodes for mpi program to run

# Copy the file to each worker
echo "Starting file transfer to workers..."
for n in worker1 worker2 worker3; do
  scp /home/hpcuser/hello_mpi hpcuser@$n:/home/hpcuser/
  echo "Successfully transferred file to $n"
done

# Change permissions on each server
echo "Starting permission update on all servers..."
for n in controller worker1 worker2 worker3; do
  ssh hpcuser@$n "chmod +x /home/hpcuser/hello_mpi"
  echo "Successfully updated permissions on $n"
done

echo "All tasks completed successfully."
