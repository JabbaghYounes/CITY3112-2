#!/bin/bash

###############################################################################
# HPL Auto-Tuned Multi-Node Benchmark Script
###############################################################################

HPL_BIN="$HOME/hpl-2.3/bin/Linux_OpenMPI/xhpl"
RESULTS_FILE="$HOME/hpl_benchmark_results_$(date +%Y%m%d_%H%M%S).txt"

echo "HPL Benchmark Results - $(date)" | tee "$RESULTS_FILE"
echo "==========================================" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

run_test() {
  local NAME=$1
  local HOSTFILE=$2
  local NP=$3
  local P=$4
  local Q=$5
  local N=$6

  echo "----------------------------------------" | tee -a "$RESULTS_FILE"
  echo "Test: $NAME" | tee -a "$RESULTS_FILE"
  echo "Hostfile: $HOSTFILE" | tee -a "$RESULTS_FILE"
  echo "Processes: $NP (P=$P x Q=$Q)" | tee -a "$RESULTS_FILE"
  echo "Matrix Size: N=$N" | tee -a "$RESULTS_FILE"
  echo "----------------------------------------" | tee -a "$RESULTS_FILE"

  # Generate HPL.dat
  cat >HPL.dat <<EOF
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out
1
$N
1
64
0
1
$P $Q
1
1
0
1
1
0
1
1
0
64
0
0
0
0
1
1
8
EOF

  mpirun --hostfile "$HOSTFILE" -np "$NP" "$HPL_BIN" | tee -a "$RESULTS_FILE"

  if grep -q "PASSED" "$RESULTS_FILE"; then
    echo "RESULT: PASSED" | tee -a "$RESULTS_FILE"
  else
    echo "RESULT: FAILED" | tee -a "$RESULTS_FILE"
  fi

  echo "" | tee -a "$RESULTS_FILE"
}

# Conservative N values (scale with nodes)
run_test "1 Node" "$HOME/hosts_1node.txt" 2 1 2 40000
run_test "2 Node" "$HOME/hosts_2node.txt" 4 2 2 60000
run_test "3 Node" "$HOME/hosts_3node.txt" 6 2 3 75000
run_test "4 Node" "$HOME/hosts_4node.txt" 8 4 2 90000

echo "==========================================" | tee -a "$RESULTS_FILE"
echo "Benchmark completed." | tee -a "$RESULTS_FILE"
echo "Results saved to $RESULTS_FILE"
