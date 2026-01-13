#!/bin/bash
# CITY3112 HPC Coursework - Task 4
# Benchmark Runner Script
# 
# This script runs the distributed hashing application with varying
# numbers of processes to measure scaling efficiency.

PROGRAM="./distributed_hash"
HOSTFILE="hostfile"
CHUNK_SIZE_MB=100  # Size per process in MB
OUTPUT_FILE="benchmark_results.csv"
RUNS_PER_CONFIG=3  # Number of runs per configuration for averaging

# Check if program exists
if [ ! -f "$PROGRAM" ]; then
    echo "Error: $PROGRAM not found. Run 'make' first."
    exit 1
fi

# Create output file with header
echo "run,processes,chunk_mb,total_mb,time_sec,throughput_mbs" > "$OUTPUT_FILE"

echo "=============================================="
echo "  Distributed Hashing Benchmark Suite"
echo "=============================================="
echo "Chunk size per process: ${CHUNK_SIZE_MB} MB"
echo "Runs per configuration: ${RUNS_PER_CONFIG}"
echo "Output file: ${OUTPUT_FILE}"
echo "=============================================="
echo ""

# Test configurations: 1, 2, 4, 6, 8 processes
for np in 1 2 4 6 8; do
    echo "Testing with $np process(es)..."
    
    for run in $(seq 1 $RUNS_PER_CONFIG); do
        echo "  Run $run of $RUNS_PER_CONFIG..."
        
        # Run the benchmark and extract CSV line
        result=$(mpirun --hostfile "$HOSTFILE" -np $np "$PROGRAM" $CHUNK_SIZE_MB 2>/dev/null | grep "^[0-9]")
        
        if [ -n "$result" ]; then
            echo "$run,$result" >> "$OUTPUT_FILE"
        else
            echo "  Warning: No result captured for run $run"
        fi
        
        # Brief pause between runs
        sleep 1
    done
    
    echo ""
done

echo "=============================================="
echo "  Benchmark Complete"
echo "=============================================="
echo "Results saved to: $OUTPUT_FILE"
echo ""

# Quick summary
echo "Summary (average throughput per configuration):"
echo "----------------------------------------------"
awk -F',' 'NR>1 {
    procs[$2] += $6; 
    count[$2]++
} 
END {
    for (p in procs) {
        printf "  %d processes: %.2f MB/s average\n", p, procs[p]/count[p]
    }
}' "$OUTPUT_FILE" | sort -t':' -k1 -n
