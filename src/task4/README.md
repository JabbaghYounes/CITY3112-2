# CITY3112 HPC Coursework - Task 4
## Distributed Cryptographic Hashing for Big Data Integrity Verification

### Overview

This application demonstrates parallel computation using MPI to perform SHA-256 hashing on large datasets distributed across an HPC cluster. It addresses a real-world big data problem: verifying integrity of large-scale data archives.

### Application Scenario

**Problem**: A data centre needs to verify checksums of backup archives (hundreds of GB to petabytes). Single-machine processing is too slow to meet time constraints.

**Solution**: Distribute the workload across multiple nodes, with each process independently computing hashes for its assigned data chunk.

### Design Rationale (Based on Task 3 Findings)

Task 3 HPL benchmarking revealed negative scaling on our cluster:
- 2 processes: 39.26 GFLOPS (best)
- 8 processes: 18.21 GFLOPS (worst)

**Root causes identified:**
- High communication overhead for tightly coupled workloads
- Network latency between virtualized nodes
- Small problem size relative to communication costs

**Task 4 design response:**
- Selected **embarrassingly parallel** workload (cryptographic hashing)
- Minimal inter-node communication (only final hash aggregation)
- Large work units per process (~100 MB each)
- Expected outcome: **positive scaling** with near-linear speedup

---

### Prerequisites

On **all cluster nodes**, ensure the following are installed:

```bash
# OpenMPI (should be present from Task 2)
sudo dnf install openmpi openmpi-devel

# OpenSSL development libraries (for SHA-256)
sudo dnf install openssl-devel

# Python packages for analysis (controller only)
pip3 install pandas matplotlib --user
```

Ensure MPI environment is loaded:
```bash
module load mpi/openmpi-x86_64
# Or add to ~/.bashrc:
export PATH=/usr/lib64/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH
```

---

### File Structure

```
task4/
├── distributed_hash.c      # Main MPI program
├── Makefile                 # Build configuration
├── hostfile                 # MPI host configuration
├── run_benchmark.sh         # Automated benchmark script
├── analyze_results.py       # Results analysis and plotting
├── sample_benchmark_results.csv  # Example data for testing
└── README.md                # This file
```

---

### Compilation

```bash
# Compile the program
make

# Or manually:
mpicc -O3 -o distributed_hash distributed_hash.c -lssl -lcrypto
```

---

### Execution

#### Quick Test (Local)
```bash
mpirun -np 2 ./distributed_hash 10
```

#### Single Run on Cluster
```bash
# 8 processes, 100 MB per process (800 MB total)
mpirun --hostfile hostfile -np 8 ./distributed_hash 100
```

#### Full Benchmark Suite
```bash
chmod +x run_benchmark.sh
./run_benchmark.sh
```

This runs tests with 1, 2, 4, 6, and 8 processes, saving results to `benchmark_results.csv`.

---

### Analysis

After running benchmarks:

```bash
python3 analyze_results.py benchmark_results.csv
```

This generates:
- `task4_performance.png` - Performance metrics (4 graphs)
- `task4_performance.pdf` - PDF version for report
- `task4_hpl_comparison.png` - Comparison with Task 3 HPL
- `performance_summary.csv` - Numerical summary

---

### Expected Output

```
==============================================================
  Distributed SHA-256 Hashing - Big Data Integrity System
==============================================================
Configuration:
  Total MPI processes:    8
  Chunk size per process: 100 MB
  Total data to process:  800 MB (0.78 GB)
==============================================================

Starting distributed hash computation...

Phase 1: Generating data chunks...
Phase 2: Computing SHA-256 hashes...

==============================================================
  Results
==============================================================

Hash Results by Rank:
-------------------------------------------------------------
  Rank 0: a1b2c3d4e5f6...
  Rank 1: f6e5d4c3b2a1...
  ...

==============================================================
  Performance Metrics
==============================================================
  Total data processed:   800.00 MB (0.78 GB)
  Total execution time:   2.8123 seconds
  Throughput:             284.43 MB/s
  Processes used:         8
==============================================================
```

---

### Societal & Economic Impact

**Data Integrity & Security**
- Cloud providers (AWS S3, Azure Blob) use checksums to verify petabytes of customer data
- Data centres can detect corruption or tampering in backup archives
- Estimated 30-50% of enterprise data requires regular integrity verification

**Blockchain & Cryptocurrency**
- Bitcoin mining is fundamentally distributed hash computation
- The global cryptocurrency mining market exceeds $2 billion annually
- Demonstrates same parallel scaling principles

**Cybersecurity**
- Hash-based deduplication reduces enterprise storage costs by 30-50%
- Digital forensics relies on hash verification for evidence integrity
- Password hashing systems (bcrypt, Argon2) use similar parallelization

**Sustainability**
- Efficient parallel processing reduces energy consumption per unit of work
- Optimized workload distribution minimizes idle compute resources
- Demonstrates sustainable computing through efficient resource utilization

---

### Troubleshooting

**"mpicc not found"**
```bash
module load mpi/openmpi-x86_64
```

**"openssl/sha.h not found"**
```bash
sudo dnf install openssl-devel
```

**SSH connection failures**
```bash
# Verify passwordless SSH
ssh worker1 hostname
```

**Permission denied on benchmark script**
```bash
chmod +x run_benchmark.sh
```

---

### Author
[Your Name]
[Your Student ID]
CITY3112 High Performance Computing
[Date]
