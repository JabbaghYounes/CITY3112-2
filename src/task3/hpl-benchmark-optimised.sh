#!/bin/bash

# Optimized benchmark - avoids memory issues
HPL_DIR=~/hpl-2.3
cd $HPL_DIR

RESULTS_FILE=~/hpl_benchmark_results_$(date +%Y%m%d_%H%M%S).txt
echo "HPL Benchmark Results - $(date)" >$RESULTS_FILE

run_test() {
  local name=$1
  local hostfile=$2
  local np=$3
  local N=$4
  local P=$5
  local Q=$6
  local NB=${7:-64}

  echo ""
  echo "=========================================="
  echo "Running: $name"
  echo "N=$N, P=$P, Q=$Q, NB=$NB, NP=$np"
  echo "=========================================="

  cat >HPL.dat <<HPLEOF
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out
6
1
$N
1
$NB
0
1
$P
$Q
16.0
1
2
1
1
1
2
1
2
1
0
1
64
0
0
1
8
HPLEOF

  rm -f HPL.out

  echo "----------------------------------------" >>$RESULTS_FILE
  echo "Test: $name" >>$RESULTS_FILE
  echo "Date: $(date)" >>$RESULTS_FILE
  echo "N=$N, P=$P, Q=$Q, NB=$NB, Processes=$np" >>$RESULTS_FILE
  echo "Memory estimate: $((N * N * 8 / 1024 / 1024 / 1024))GB" >>$RESULTS_FILE
  echo "----------------------------------------" >>$RESULTS_FILE

  timeout 300 mpirun --hostfile $hostfile -np $np ./bin/Linux_OpenMPI/xhpl
  local exit_code=$?

  if [ $exit_code -eq 124 ]; then
    echo "✗ TIMEOUT (>5 minutes)"
    echo "Status: TIMEOUT after 5 minutes" >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE
  elif grep -q "PASSED" HPL.out 2>/dev/null; then
    GFLOPS=$(grep "WR" HPL.out | tail -1 | awk '{print $7}')
    TIME=$(grep "WR" HPL.out | tail -1 | awk '{print $6}')
    echo "✓ PASSED: $GFLOPS GFLOPS in ${TIME}s"
    echo "Status: PASSED" >>$RESULTS_FILE
    echo "Performance: $GFLOPS GFLOPS" >>$RESULTS_FILE
    echo "Time: ${TIME}s" >>$RESULTS_FILE
    cat HPL.out >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE
  else
    echo "✗ FAILED"
    echo "Status: FAILED" >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE
  fi
}

echo "Starting optimized HPL benchmark suite..."
echo "Tests limited to problem sizes that fit in available memory"
echo ""

# Category 1: Single Node - Granularity demonstration
echo "=== CATEGORY 1: Single Node Tests (Memory: 4GB) ==="
run_test "1-Node Small (N=8000)" ~/hosts_1node.txt 2 8000 1 2 64
run_test "1-Node Medium (N=12000)" ~/hosts_1node.txt 2 12000 1 2 64
run_test "1-Node Large (N=16000)" ~/hosts_1node.txt 2 16000 1 2 64
run_test "1-Node Large (N=16000, NB=128)" ~/hosts_1node.txt 2 16000 1 2 128

# Category 2: Two Nodes
echo ""
echo "=== CATEGORY 2: Two Node Tests (Memory: 6GB total) ==="
run_test "2-Node Small (N=8000)" ~/hosts_2node.txt 4 8000 2 2 64
run_test "2-Node Medium (N=12000)" ~/hosts_2node.txt 4 12000 2 2 64
run_test "2-Node Large (N=16000)" ~/hosts_2node.txt 4 16000 2 2 64
# Skip N=20000 - too large, causes memory issues

# Category 3: Three Nodes
echo ""
echo "=== CATEGORY 3: Three Node Tests (Memory: 8GB total) ==="
run_test "3-Node Small (N=8000)" ~/hosts_3node.txt 6 8000 2 3 64
run_test "3-Node Medium (N=12000)" ~/hosts_3node.txt 6 12000 2 3 64
run_test "3-Node Large (N=16000)" ~/hosts_3node.txt 6 16000 2 3 64
run_test "3-Node Alt Grid (N=16000, 3×2)" ~/hosts_3node.txt 6 16000 3 2 64
# Skip N=24000 - causes memory pressure

# Category 4: Four Nodes
echo ""
echo "=== CATEGORY 4: Four Node Tests (Memory: 10GB total) ==="
run_test "4-Node Small (N=8000)" ~/hosts_4node.txt 8 8000 2 4 64
run_test "4-Node Medium (N=12000)" ~/hosts_4node.txt 8 12000 2 4 64
run_test "4-Node Large (N=16000)" ~/hosts_4node.txt 8 16000 2 4 64
run_test "4-Node Alt Grid (N=16000, 4×2)" ~/hosts_4node.txt 8 16000 4 2 64
# Skip N=28000 - too large for available memory

echo ""
echo "=========================================="
echo "Benchmark suite complete!"
echo "Results saved to: $RESULTS_FILE"
echo "=========================================="
echo ""

# Summary
echo "Performance Summary:"
grep "Performance:" $RESULTS_FILE | nl
