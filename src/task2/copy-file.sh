#!/bin/bash
# copy-file.sh
# copies executable files from controller to worker nodes to mpi program to run

# Define the files to copy
FILES=("/home/hpcuser/hello_mpi" "/home/hpcuser/hello_mpi.c")

# Copy the files to each worker
echo "Starting file transfer to workers..."
for n in worker1 worker2 worker3; do
  for file in "${FILES[@]}"; do
    scp "$file" hpcuser@$n:/home/hpcuser/
    echo "Successfully transferred $file to $n"
  done
done

# Change permissions on each server
echo "Starting permission update on all servers..."
for n in controller worker1 worker2 worker3; do
  ssh hpcuser@$n "chmod +x /home/hpcuser/hello_mpi"
  echo "Successfully updated permissions on $n for hello_mpi"
done

echo "All tasks completed successfully."
