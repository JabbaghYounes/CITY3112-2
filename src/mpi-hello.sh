#!/bin/bash
# run_mpi_hello.sh
# Compiles and runs a Hello World MPI program on the cluster

USER="hpcuser"
HOSTFILE="/home/$USER/hosts.txt"
HELLO_MPI="/home/$USER/hello_mpi.c"

# --- Step 1: Create Hello World MPI program ---
cat <<'EOF' >"$HELLO_MPI"
#include <mpi.h>
#include <stdio.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    printf("Hello from rank %d out of %d processors\n", world_rank, world_size);

    MPI_Finalize();
    return 0;
}
EOF

# --- Step 2: Compile ---
mpicc "$HELLO_MPI" -o /home/$USER/hello_mpi

# --- Step 3: Run across cluster ---
TOTAL_PROCESSES=$(wc -l <"$HOSTFILE") # one process per node for simplicity
mpirun -np "$TOTAL_PROCESSES" --hostfile "$HOSTFILE" /home/$USER/hello_mpi
