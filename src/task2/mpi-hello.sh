#!/bin/bash
# mpi-hello.sh
# Compiles and runs MPI hello world program on the cluster

USER="hpcuser"
HOSTFILE="/home/$USER/hosts.txt"
HELLO_MPI="/home/$USER/hello_mpi.c"
HELLO_BIN="/home/$USER/hello_mpi"

# --- Create MPI Hello World program ---
cat <<'EOF' >"$HELLO_MPI"
#include <mpi.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank, size;
    char hostname[256];

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    gethostname(hostname, sizeof(hostname));

    printf("Hello from rank %d of %d on %s\n", rank, size, hostname);

    MPI_Finalize();
    return 0;
}
EOF

# --- Compile ---
mpicc "$HELLO_MPI" -o "$HELLO_BIN"

# --- Calculate total slots ---
TOTAL_PROCESSES=$(awk -F= '{sum+=$2} END {print sum}' "$HOSTFILE")

# --- Run across cluster ---
mpirun -np "$TOTAL_PROCESSES" --hostfile "$HOSTFILE" "$HELLO_BIN"
