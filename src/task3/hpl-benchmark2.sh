#!/bin/bash

################################################################################
# HPL Multi-Node Benchmark Test Suite with Progress Monitoring - Enhanced
# Tests multiple configurations with proper granularity demonstration
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Base directory
HPL_DIR=~/hpl-2.3
cd $HPL_DIR || {
  echo "Error: Cannot access $HPL_DIR"
  exit 1
}

# Results file
RESULTS_FILE=~/hpl_benchmark_results_$(date +%Y%m%d_%H%M%S).txt
echo "HPL Benchmark Results - $(date)" >$RESULTS_FILE
echo "==========================================" >>$RESULTS_FILE
echo "" >>$RESULTS_FILE

# Progress tracking
TOTAL_TESTS=0
COMPLETED_TESTS=0
FAILED_TESTS=0

# Function to monitor HPL output with live updates
monitor_hpl() {
  local test_name=$1
  local start_time=$(date +%s)
  local phase="Initializing"

  echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
  echo -e "${CYAN}Monitoring: $test_name${NC}"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"

  # Wait for HPL to start generating output
  local wait_count=0
  while [ $wait_count -lt 10 ]; do
    if [ -f "HPL.out" ] && [ -s "HPL.out" ]; then
      break
    fi
    sleep 1
    wait_count=$((wait_count + 1))
    printf "\r${CYAN}⏳${NC} Waiting for test to start... ${wait_count}s"
  done
  echo ""

  # Monitor phases
  local last_phase=""
  while true; do
    if [ -f "HPL.out" ]; then
      # Check for different phases
      if grep -q "randomly generated" "HPL.out" 2>/dev/null; then
        phase="Matrix Generation"
      fi
      if grep -q "pdgesv() start time" "HPL.out" 2>/dev/null; then
        phase="Computing (Linear System Solve)"
      fi
      if grep -q "pdgesv() end time" "HPL.out" 2>/dev/null; then
        phase="Verification & Cleanup"
      fi
      if grep -q "PASSED\|FAILED" "HPL.out" 2>/dev/null; then
        phase="Complete"
        break
      fi

      # Calculate elapsed time
      local elapsed=$(($(date +%s) - start_time))
      local mins=$((elapsed / 60))
      local secs=$((elapsed % 60))

      # Display status with spinner
      local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
      local spin_idx=$((elapsed % 10))
      local spinner_char=${spinstr:$spin_idx:1}

      # Only update display if phase changed
      if [ "$phase" != "$last_phase" ]; then
        echo ""
        last_phase="$phase"
      fi

      printf "\r${CYAN}${spinner_char}${NC} ${BOLD}Phase:${NC} %-35s ${BOLD}Elapsed:${NC} %02d:%02d" "$phase" "$mins" "$secs"

    fi
    sleep 0.5
  done

  echo "" # New line after progress
}

# Function to run a test
run_test() {
  local test_name=$1
  local hostfile=$2
  local np=$3
  local N=$4
  local P=$5
  local Q=$6
  local NB=${7:-64} # Block size, default 64

  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  echo ""
  echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}Test $TOTAL_TESTS: $test_name${NC}"
  echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Configuration:${NC}"
  echo -e "  • Hostfile:     ${YELLOW}$(basename $hostfile)${NC}"
  echo -e "  • Processes:    ${YELLOW}$np${NC} (Grid: ${P}×${Q})"
  echo -e "  • Matrix Size:  ${YELLOW}N=$N${NC}"
  echo -e "  • Block Size:   ${YELLOW}NB=$NB${NC}"
  echo -e "  • Memory Est:   ${YELLOW}~$((N * N * 8 / 1024 / 1024 / 1024))GB${NC}"
  local work_per_proc=$((N * N / np))
  echo -e "  • Work/Process: ${YELLOW}$(printf "%.1f" $(echo "scale=1; $work_per_proc/1000000" | bc))M elements${NC}"
  echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
  echo ""

  # Create HPL.dat file
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

  # Record test details
  echo "----------------------------------------" >>$RESULTS_FILE
  echo "Test $TOTAL_TESTS: $test_name" >>$RESULTS_FILE
  echo "Date: $(date)" >>$RESULTS_FILE
  echo "Hostfile: $hostfile" >>$RESULTS_FILE
  echo "Processes: $np (P=$P x Q=$Q)" >>$RESULTS_FILE
  echo "Matrix Size: N=$N" >>$RESULTS_FILE
  echo "Block Size: NB=$NB" >>$RESULTS_FILE
  echo "Work per Process: $work_per_proc elements" >>$RESULTS_FILE
  echo "----------------------------------------" >>$RESULTS_FILE

  # Clear old output
  rm -f HPL.out

  # Run the test in background
  START_TIME=$(date +%s)

  # Monitor in foreground and capture output
  mpirun --hostfile $hostfile -np $np ./bin/Linux_OpenMPI/xhpl 2>&1 | tee /tmp/hpl_run_$$.log &
  local mpi_pid=$!

  # Monitor the test with live updates
  sleep 2 # Give it time to start
  monitor_hpl "$test_name"

  # Wait for MPI to complete
  wait $mpi_pid
  local exit_code=$?

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # Check if test actually completed successfully
  if [ -f "HPL.out" ] && grep -q "PASSED" HPL.out 2>/dev/null; then
    # Extract performance data
    GFLOPS=$(grep "WR" HPL.out | tail -1 | awk '{print $7}')
    TIME=$(grep "WR" HPL.out | tail -1 | awk '{print $6}')
    RESIDUAL=$(grep "||Ax-b||" HPL.out | awk '{print $1}' | tail -1)

    COMPLETED_TESTS=$((COMPLETED_TESTS + 1))

    echo -e "\n${GREEN}${BOLD}✓ Test PASSED successfully!${NC}"
    echo -e "${GREEN}  HPL Time:    ${TIME}s${NC}"
    echo -e "${GREEN}  Total Time:  ${DURATION}s${NC}"
    echo -e "${GREEN}  Performance: ${GFLOPS} GFLOPS${NC}"
    echo -e "${GREEN}  Residual:    ${RESIDUAL}${NC}"

    # Show progress
    echo -e "\n${MAGENTA}Progress: [${COMPLETED_TESTS} passed / ${FAILED_TESTS} failed / $TOTAL_TESTS total]${NC}"

    # Save to results file
    echo "" >>$RESULTS_FILE
    echo "Status: PASSED" >>$RESULTS_FILE
    echo "Duration: ${DURATION} seconds" >>$RESULTS_FILE
    echo "HPL Time: ${TIME} seconds" >>$RESULTS_FILE
    echo "Performance: ${GFLOPS} GFLOPS" >>$RESULTS_FILE
    echo "Residual: ${RESIDUAL}" >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE
    cat HPL.out >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE

    # Save detailed output
    cp HPL.out "HPL_${test_name// /_}.out"

    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))

    echo -e "\n${RED}${BOLD}✗ Test FAILED${NC}"
    echo -e "${RED}  Duration: ${DURATION}s${NC}"

    if [ -f "HPL.out" ]; then
      if grep -q "FAILED" HPL.out 2>/dev/null; then
        echo -e "${RED}  Reason: Residual check failed${NC}"
      else
        echo -e "${RED}  Reason: Test did not complete${NC}"
      fi
    else
      echo -e "${RED}  Reason: No output generated${NC}"
    fi

    echo "" >>$RESULTS_FILE
    echo "Status: FAILED" >>$RESULTS_FILE
    echo "Duration: ${DURATION} seconds" >>$RESULTS_FILE
    if [ -f "/tmp/hpl_run_$$.log" ]; then
      echo "Error Output:" >>$RESULTS_FILE
      cat /tmp/hpl_run_$$.log >>$RESULTS_FILE
    fi
    echo "" >>$RESULTS_FILE

    return 1
  fi

  sleep 2 # Brief pause between tests
}

################################################################################
# Pre-flight checks
################################################################################

clear
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║   HPL BENCHMARK SUITE - ENHANCED       ║${NC}"
echo -e "${BLUE}${BOLD}║   Version 3.0 - Full Granularity       ║${NC}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}${BOLD}Pre-flight Checks:${NC}"
echo ""

# Check if hostfiles exist
echo -e "${CYAN}Checking hostfiles...${NC}"
for hostfile in ~/hosts_1node.txt ~/hosts_2node.txt ~/hosts_3node.txt ~/hosts_4node.txt; do
  if [ -f "$hostfile" ]; then
    echo -e "  ${GREEN}✓${NC} $(basename $hostfile)"
  else
    echo -e "  ${RED}✗${NC} $(basename $hostfile) ${RED}NOT FOUND${NC}"
  fi
done

echo ""
echo -e "${CYAN}Checking node connectivity...${NC}"

# Check controller
echo -e "  ${GREEN}✓${NC} controller (local)"

# Check worker nodes
AVAILABLE_NODES=1
for node in worker1 worker2 worker3; do
  if timeout 5 ssh -o ConnectTimeout=5 -o BatchMode=yes $node "echo 2>&1" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $node"
    AVAILABLE_NODES=$((AVAILABLE_NODES + 1))
  else
    echo -e "  ${YELLOW}⚠${NC} $node ${YELLOW}(not reachable)${NC}"
  fi
done

echo ""
echo -e "${CYAN}System Summary:${NC}"
echo -e "  • Available Nodes: ${GREEN}$AVAILABLE_NODES${NC}"
echo -e "  • Max Processes:   ${GREEN}$((AVAILABLE_NODES * 2))${NC}"
echo -e "  • Results File:    ${CYAN}$RESULTS_FILE${NC}"
echo ""

read -p "Press Enter to start comprehensive benchmark suite..."
clear

################################################################################
# Run Comprehensive Test Suite
################################################################################

echo -e "${BLUE}${BOLD}Starting Comprehensive Benchmark Tests...${NC}"
echo -e "${CYAN}This suite demonstrates granularity with multiple problem sizes and configurations${NC}"
echo ""

# Category 1: Single Node Tests (Baseline & Granularity)
echo -e "${MAGENTA}${BOLD}═══ CATEGORY 1: Single Node Tests ═══${NC}"

# Test 1.1: Small problem (baseline)
run_test "1-Node Small (N=8000)" ~/hosts_1node.txt 2 8000 1 2 64

# Test 1.2: Medium problem
run_test "1-Node Medium (N=12000)" ~/hosts_1node.txt 2 12000 1 2 64

# Test 1.3: Large problem
run_test "1-Node Large (N=16000)" ~/hosts_1node.txt 2 16000 1 2 64

# Test 1.4: Same size, different block size (demonstrates parameter granularity)
run_test "1-Node (N=16000, NB=128)" ~/hosts_1node.txt 2 16000 1 2 128

echo ""

# Category 2: Two Node Tests (if available)
if [ $AVAILABLE_NODES -ge 2 ]; then
  echo -e "${MAGENTA}${BOLD}═══ CATEGORY 2: Two Node Tests ═══${NC}"

  # Test 2.1: Small problem on 2 nodes
  run_test "2-Node Small (N=8000)" ~/hosts_2node.txt 4 8000 2 2 64

  # Test 2.2: Medium problem
  run_test "2-Node Medium (N=12000)" ~/hosts_2node.txt 4 12000 2 2 64

  # Test 2.3: Large problem
  run_test "2-Node Large (N=16000)" ~/hosts_2node.txt 4 16000 2 2 64

  # Test 2.4: Extra large (if resources allow)
  run_test "2-Node XLarge (N=20000)" ~/hosts_2node.txt 4 20000 2 2 64

  echo ""
else
  echo -e "${YELLOW}Skipping 2-node tests (worker1 not available)${NC}"
  echo ""
fi

# Category 3: Three Node Tests (if available)
if [ $AVAILABLE_NODES -ge 3 ]; then
  echo -e "${MAGENTA}${BOLD}═══ CATEGORY 3: Three Node Tests ═══${NC}"

  # Test 3.1: Medium problem
  run_test "3-Node Medium (N=12000)" ~/hosts_3node.txt 6 12000 2 3 64

  # Test 3.2: Large problem
  run_test "3-Node Large (N=16000)" ~/hosts_3node.txt 6 16000 2 3 64

  # Test 3.3: Extra large
  run_test "3-Node XLarge (N=24000)" ~/hosts_3node.txt 6 24000 2 3 64

  # Test 3.4: Different grid configuration (3x2 instead of 2x3)
  run_test "3-Node Alt Grid (N=16000, 3×2)" ~/hosts_3node.txt 6 16000 3 2 64

  echo ""
else
  echo -e "${YELLOW}Skipping 3-node tests (worker2 not available)${NC}"
  echo ""
fi

# Category 4: Four Node Tests (if available)
if [ $AVAILABLE_NODES -ge 4 ]; then
  echo -e "${MAGENTA}${BOLD}═══ CATEGORY 4: Four Node Tests ═══${NC}"

  # Test 4.1: Medium problem
  run_test "4-Node Medium (N=12000)" ~/hosts_4node.txt 8 12000 2 4 64

  # Test 4.2: Large problem
  run_test "4-Node Large (N=16000)" ~/hosts_4node.txt 8 16000 2 4 64

  # Test 4.3: Extra large
  run_test "4-Node XLarge (N=24000)" ~/hosts_4node.txt 8 24000 2 4 64

  # Test 4.4: Double extra large (stress test)
  run_test "4-Node XXLarge (N=28000)" ~/hosts_4node.txt 8 28000 2 4 64

  # Test 4.5: Different grid (4×2 instead of 2×4)
  run_test "4-Node Alt Grid (N=16000, 4×2)" ~/hosts_4node.txt 8 16000 4 2 64

  echo ""
else
  echo -e "${YELLOW}Skipping 4-node tests (worker3 not available)${NC}"
  echo ""
fi

################################################################################
# Summary
################################################################################

echo ""
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║    BENCHMARK SUITE COMPLETE            ║${NC}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}${BOLD}Final Statistics:${NC}"
echo -e "  • Total Tests:      ${CYAN}$TOTAL_TESTS${NC}"
echo -e "  • Passed:           ${GREEN}$COMPLETED_TESTS${NC}"
echo -e "  • Failed:           ${RED}$FAILED_TESTS${NC}"
echo -e "  • Success Rate:     ${YELLOW}$((COMPLETED_TESTS * 100 / TOTAL_TESTS))%${NC}"
echo ""
echo -e "${CYAN}Results saved to:${NC} ${BOLD}$RESULTS_FILE${NC}"
echo ""

# Performance summary table
if [ $COMPLETED_TESTS -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}Performance Summary (GFLOPS):${NC}"
  echo -e "${BLUE}────────────────────────────────────────────────────${NC}"

  grep -A 6 "^Test" $RESULTS_FILE | grep -E "(^Test|Performance:)" |
    while read -r line; do
      if [[ $line == Test* ]]; then
        test_name=$(echo "$line" | cut -d: -f2- | xargs)
        printf "%-40s" "$test_name"
      elif [[ $line == Performance:* ]]; then
        gflops=$(echo "$line" | awk '{print $2}')
        printf " → ${GREEN}%8s${NC}\n" "$gflops"
      fi
    done

  echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
fi

echo ""

# Show saved files
if ls HPL_*Node*.out >/dev/null 2>&1; then
  echo -e "${YELLOW}Individual test outputs saved:${NC}"
  ls -1 HPL_*Node*.out | head -10 | while read file; do
    size=$(ls -lh "$file" | awk '{print $5}')
    echo -e "  • ${CYAN}$file${NC} ($size)"
  done

  total_files=$(ls -1 HPL_*Node*.out | wc -l)
  if [ $total_files -gt 10 ]; then
    echo -e "  ... and $((total_files - 10)) more files"
  fi
fi

echo ""
echo -e "${GREEN}${BOLD}✓ Comprehensive benchmark suite complete!${NC}"
echo ""
echo -e "${CYAN}${BOLD}Next Steps:${NC}"
echo -e "  1. Run analysis: ${YELLOW}~/analyze_hpl.sh $RESULTS_FILE${NC}"
echo -e "  2. View results: ${YELLOW}cat $RESULTS_FILE | less${NC}"
echo -e "  3. Generate report for submission"
echo ""

# Cleanup
rm -f /tmp/hpl_run_*.log
