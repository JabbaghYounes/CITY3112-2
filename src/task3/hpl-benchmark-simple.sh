#!/bin/bash

# Simple reliable benchmark script
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

  echo "Test: $name" >>$RESULTS_FILE
  echo "N=$N, P=$P, Q=$Q, NB=$NB, Processes=$np" >>$RESULTS_FILE

  mpirun --hostfile $hostfile -np $np ./bin/Linux_OpenMPI/xhpl

  if grep -q "PASSED" HPL.out 2>/dev/null; then
    GFLOPS=$(grep "WR" HPL.out | tail -1 | awk '{print $7}')
    echo "✓ PASSED: $GFLOPS GFLOPS"
    echo "Performance: $GFLOPS GFLOPS" >>$RESULTS_FILE
    cat HPL.out >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE
  else
    echo "✗ FAILED"
    echo "FAILED" >>$RESULTS_FILE
  fi
}

# Run tests
run_test "1-Node N=8000" ~/hosts_1node.txt 2 8000 1 2 64
run_test "1-Node N=12000" ~/hosts_1node.txt 2 12000 1 2 64
run_test "1-Node N=16000" ~/hosts_1node.txt 2 16000 1 2 64
run_test "1-Node N=16000 NB=128" ~/hosts_1node.txt 2 16000 1 2 128

run_test "2-Node N=12000" ~/hosts_2node.txt 4 12000 2 2 64
run_test "2-Node N=16000" ~/hosts_2node.txt 4 16000 2 2 64
run_test "2-Node N=20000" ~/hosts_2node.txt 4 20000 2 2 64

run_test "3-Node N=16000" ~/hosts_3node.txt 6 16000 2 3 64
run_test "3-Node N=24000" ~/hosts_3node.txt 6 24000 2 3 64

run_test "4-Node N=16000" ~/hosts_4node.txt 8 16000 2 4 64
run_test "4-Node N=28000" ~/hosts_4node.txt 8 28000 2 4 64

echo ""
echo "All tests complete!"
echo "Results: $RESULTS_FILE"
