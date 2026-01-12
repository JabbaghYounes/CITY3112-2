#!/bin/bash

################################################################################
# HPL Multi-Node Benchmark Test Suite with Progress Monitoring
# Tests 1, 2, 3, and 4 node configurations
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

# Function to display a spinner with status
show_progress() {
  local pid=$1
  local test_name=$2
  local delay=0.1
  local spinstr='|/-\'
  local start_time=$(date +%s)

  echo -ne "${CYAN}"
  while kill -0 $pid 2>/dev/null; do
    local elapsed=$(($(date +%s) - start_time))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local temp=${spinstr#?}
    printf "\r[%c] Running %s... [%02d:%02d elapsed]" "$spinstr" "$test_name" "$mins" "$secs"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  echo -ne "${NC}\r"
}

# Function to monitor HPL output with live updates
monitor_hpl() {
  local output_file=$1
  local test_name=$2
  local start_time=$(date +%s)

  echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
  echo -e "${CYAN}Monitoring: $test_name${NC}"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"

  # Wait for output file to be created
  local wait_count=0
  while [ ! -f "$output_file" ] && [ $wait_count -lt 30 ]; do
    sleep 1
    wait_count=$((wait_count + 1))
  done

  if [ ! -f "$output_file" ]; then
    echo -e "${YELLOW}⚠ Waiting for test to start...${NC}"
    return
  fi

  local last_line=""
  local phase="Initializing"

  while true; do
    if [ -f "$output_file" ]; then
      # Check for different phases
      if grep -q "randomly generated" "$output_file" 2>/dev/null; then
        phase="Matrix Generation"
      fi
      if grep -q "pdgesv() start time" "$output_file" 2>/dev/null; then
        phase="Computing (Solving Linear System)"
      fi
      if grep -q "pdgesv() end time" "$output_file" 2>/dev/null; then
        phase="Verification"
      fi
      if grep -q "PASSED\|FAILED" "$output_file" 2>/dev/null; then
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

      printf "\r${CYAN}${spinner_char}${NC} ${BOLD}Phase:${NC} %-30s ${BOLD}Elapsed:${NC} %02d:%02d" "$phase" "$mins" "$secs"

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

  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  echo ""
  echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}Test $TOTAL_TESTS: $test_name${NC}"
  echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Configuration:${NC}"
  echo -e "  • Hostfile:     ${YELLOW}$hostfile${NC}"
  echo -e "  • Processes:    ${YELLOW}$np${NC} (Grid: ${P}×${Q})"
  echo -e "  • Matrix Size:  ${YELLOW}N=$N${NC}"
  echo -e "  • Memory Est:   ${YELLOW}~$((N * N * 8 / 1024 / 1024 / 1024))GB${NC}"
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
64
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
  echo "----------------------------------------" >>$RESULTS_FILE

  # Clear old output
  rm -f HPL.out

  # Run the test in background
  START_TIME=$(date +%s)
  mpirun --hostfile $hostfile -np $np ./bin/Linux_OpenMPI/xhpl >/tmp/hpl_run_$$.log 2>&1 &
  local mpi_pid=$!

  # Monitor the test with live updates
  sleep 2 # Give it time to start
  monitor_hpl "HPL.out" "$test_name" &
  local monitor_pid=$!

  # Wait for MPI to complete
  wait $mpi_pid
  local exit_code=$?

  # Stop monitor
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $exit_code -eq 0 ] && [ -f "HPL.out" ] && grep -q "PASSED" HPL.out; then
    # Extract Gflops from HPL.out
    GFLOPS=$(grep "WR" HPL.out | tail -1 | awk '{print $7}')
    TIME=$(grep "WR" HPL.out | tail -1 | awk '{print $6}')

    COMPLETED_TESTS=$((COMPLETED_TESTS + 1))

    echo -e "\n${GREEN}${BOLD}✓ Test completed successfully!${NC}"
    echo -e "${GREEN}  Duration:    ${TIME}s (Total: ${DURATION}s)${NC}"
    echo -e "${GREEN}  Performance: ${GFLOPS} Gflops${NC}"

    # Show progress
    echo -e "\n${MAGENTA}Progress: [$COMPLETED_TESTS/$TOTAL_TESTS tests completed]${NC}"

    echo "" >>$RESULTS_FILE
    echo "Duration: ${DURATION} seconds" >>$RESULTS_FILE
    echo "Performance: ${GFLOPS} Gflops" >>$RESULTS_FILE
    cat HPL.out >>$RESULTS_FILE
    echo "" >>$RESULTS_FILE

    # Save detailed output
    cp HPL.out HPL_${test_name// /_}.out

    return 0
  else
    echo -e "\n${RED}${BOLD}✗ Test failed or did not complete${NC}"
    echo -e "${RED}  Duration: ${DURATION}s${NC}"
    echo "FAILED after ${DURATION} seconds" >>$RESULTS_FILE
    cat /tmp/hpl_run_$$.log >>$RESULTS_FILE
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
echo -e "${BLUE}${BOLD}║   HPL BENCHMARK TEST SUITE v2.0        ║${NC}"
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
echo ""

read -p "Press Enter to start benchmark suite..."
clear

################################################################################
# Run Tests
################################################################################

echo -e "${BLUE}${BOLD}Starting Benchmark Tests...${NC}"
echo ""

# Test 1: Single Node (Controller only)
run_test "1-Node Baseline" ~/hosts_1node.txt 2 16000 1 2

# Test 2: Two Nodes (Conservative size first)
if [ $AVAILABLE_NODES -ge 2 ]; then
  run_test "2-Node Conservative" ~/hosts_2node.txt 4 16000 2 2

  # Test 2b: Two Nodes (Larger size)
  if [ $? -eq 0 ]; then
    run_test "2-Node Full Load" ~/hosts_2node.txt 4 20000 2 2
  fi
else
  echo -e "${YELLOW}Skipping 2-node tests (insufficient nodes)${NC}"
fi

# Test 3: Three Nodes
if [ $AVAILABLE_NODES -ge 3 ]; then
  run_test "3-Node Conservative" ~/hosts_3node.txt 6 16000 2 3

  if [ $? -eq 0 ]; then
    run_test "3-Node Full Load" ~/hosts_3node.txt 6 24000 2 3
  fi
else
  echo -e "${YELLOW}Skipping 3-node tests (insufficient nodes)${NC}"
fi

# Test 4: Four Nodes
if [ $AVAILABLE_NODES -ge 4 ]; then
  run_test "4-Node Conservative" ~/hosts_4node.txt 8 16000 2 4

  if [ $? -eq 0 ]; then
    run_test "4-Node Full Load" ~/hosts_4node.txt 8 28000 2 4
  fi
else
  echo -e "${YELLOW}Skipping 4-node tests (insufficient nodes)${NC}"
fi

################################################################################
# Summary
################################################################################

echo ""
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║      BENCHMARK SUITE COMPLETE          ║${NC}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}${BOLD}Results Summary:${NC}"
echo -e "  • Tests Completed: ${GREEN}$COMPLETED_TESTS${NC} / ${TOTAL_TESTS}"
echo -e "  • Results File:    ${CYAN}$RESULTS_FILE${NC}"
echo ""

# Performance summary table
echo -e "${YELLOW}${BOLD}Performance Results:${NC}"
echo -e "${BLUE}────────────────────────────────────────${NC}"

grep -B 3 "Performance:" $RESULTS_FILE | grep -E "(^Test|Performance:)" |
  while read -r line; do
    if [[ $line == Test* ]]; then
      echo -ne "${CYAN}$line${NC}"
    elif [[ $line == Performance:* ]]; then
      gflops=$(echo $line | awk '{print $2, $3}')
      echo -e " → ${GREEN}$gflops${NC}"
    fi
  done

echo -e "${BLUE}────────────────────────────────────────${NC}"
echo ""

# Show saved files
if ls HPL_*Node*.out >/dev/null 2>&1; then
  echo -e "${YELLOW}Individual test outputs:${NC}"
  ls -lh HPL_*Node*.out | awk '{printf "  • %s (%s)\n", $9, $5}'
fi

echo ""
echo -e "${GREEN}${BOLD}✓ All tests complete!${NC}"
echo -e "${CYAN}View full results: ${BOLD}cat $RESULTS_FILE${NC}"
echo ""

# Cleanup
rm -f /tmp/hpl_run_*.log
