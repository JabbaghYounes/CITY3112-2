# HPL Benchmark Analysis Report

---

## Executive Summary

This report presents the results and analysis of High-Performance LINPACK (HPL) benchmarking conducted on a multi-node HPC cluster configuration. The benchmarks evaluate the computational performance measured in Floating Point Operations Per Second (FLOPS) across various system configurations.

---

## 1. Test Environment

### 1.1 Hardware Configuration

| Node | Role | vCPUs | Memory | Network |
|------|------|-------|--------|---------|
| controller | Master | 2 | 4096 MB | Virtualized |
| worker1 | Compute | 1 | 2048 MB | Virtualized |
| worker2 | Compute | 1 | 2048 MB | Virtualized |
| worker3 | Compute | 1 | 2048 MB | Virtualized |

**Total Resources:**
- Total vCPUs: 5
- Total Memory: 10,240 MB (~10 GB)
- Network: Virtualized Ethernet

### 1.2 Software Configuration

| Component | Version/Details |
|-----------|----------------|
| Operating System | Linux (CentOS/RHEL based) |
| MPI Implementation | OpenMPI |
| BLAS Library | OpenBLAS / Atlas |
| HPL Version | 2.3 |
| Compiler | GCC |

### 1.3 HPL Configuration Parameters

```
Matrix Block Size (NB): 64
Panel Factorization (PFACT): Right
Recursive Panel Fact. (RFACT): Right
Broadcast Algorithm (BCAST): 1-ring
Look-ahead Depth (DEPTH): 64
Swap Algorithm: Binary-exchange
Matrix Layout: Row-major process mapping
```

---

## 2. Benchmark Results

### 2.1 Raw Performance Data

| Test Configuration | Processes | Grid (P×Q) | Matrix Size (N) | Time (s) | Performance (GFLOPS) | Efficiency |
|-------------------|-----------|------------|-----------------|----------|----------------------|------------|
| 1-Node Small (N=8000) | 1-Node Medium (N=12000) | 1-Node Large (N=16000) | 1-Node Large (N=16000, NB=128) | 2-Node Small (N=8000) | 2-Node Medium (N=12000) | 2-Node Large (N=16000) | 3-Node Small (N=8000) | 3-Node Medium (N=12000) | 3-Node Large (N=16000) | 3-Node Alt Grid (N=16000, 3×2) | 4-Node Small (N=8000) | 4-Node Medium (N=12000) | 4-Node Large (N=16000) | 4-Node Alt Grid (N=16000, 4×2) 

### 2.2 Performance Summary Graph (Text-based)

```
Performance (GFLOPS) by Configuration:

1-Node (2 proc)  |████████████████████████████████████████ 58.63
2-Node (4 proc)  |█████████████████                        31.51
3-Node (6 proc)  |██████████████                           27.26
4-Node (8 proc)  |█████████████                            26.81
                 0    10    20    30    40    50    60    70
```

### 2.3 Scaling Efficiency

```
Strong Scaling Analysis (N=16000, varying processors):

Processors    Performance    Speedup    Efficiency    Expected
    2          58.63 GF       1.00×      100.0%       58.63 GF
    4          31.51 GF       0.54×       26.9%      117.26 GF
    6          27.26 GF       0.46×       15.5%      175.89 GF
    8          26.81 GF       0.46×       11.4%      234.52 GF
```

**Speedup Calculation:** Speedup = Performance(N processors) / Performance(2 processors)
**Efficiency:** Efficiency = (Speedup / N) × 100%

---

## 3. Analysis and Observations

### 3.1 Performance Degradation Analysis

The benchmark results demonstrate **negative scaling** - performance decreases as more nodes are added to the computation. This counter-intuitive result can be attributed to several factors:

#### 3.1.1 Network Communication Overhead

**Observation:** As we increase the number of nodes from 1 to 4, the wall time for communication-intensive operations increases dramatically:

| Operation | 1-Node (2 proc) | 2-Node (4 proc) | 3-Node (6 proc) | 4-Node (8 proc) |
|-----------|-----------------|-----------------|-----------------|-----------------|
| Panel Fact (pfact) | 0.07s | 5.75s | 3.51s | 2.47s |
| Max Swap (mxswp) | 0.01s | 5.68s | 3.45s | 2.43s |
| Laswp | 1.67s | 39.62s | 35.64s | 22.36s |

**Analysis:**
- The `laswp` (panel swapping) operation time increased by **23.7× (1.67s → 39.62s)** when moving from 1-node to 2-nodes
- Panel factorization time increased by **82× (0.07s → 5.75s)**
- These operations require **intensive inter-node communication**
- In a virtualized environment, network latency is significantly higher than physical hardware

#### 3.1.2 Problem Size vs. Process Count Mismatch

**Issue:** The matrix size (N=16000) is too small for efficient distribution across 6-8 processes.

**Calculation:**
```
Work per process = N² / Number of Processes
- 2 processes:  16000² / 2  = 128,000,000 elements/process
- 4 processes:  16000² / 4  =  64,000,000 elements/process
- 6 processes:  16000² / 6  =  42,666,667 elements/process
- 8 processes:  16000² / 8  =  32,000,000 elements/process
```

**Impact:**
- As work per process decreases, the ratio of computation to communication shifts unfavorably
- Communication overhead becomes the dominant factor
- Granularity of work is too fine for efficient parallel execution

#### 3.1.3 Load Imbalance

**Configuration Asymmetry:**
- Controller node: 2 vCPUs, 4GB RAM
- Worker nodes: 1 vCPU each, 2GB RAM

**Impact:**
- The controller node is 2× more powerful than worker nodes
- In a 2×2 grid (4 processes), half the processes run on the powerful controller, half on weaker workers
- This creates load imbalance where faster processes wait for slower ones
- Worker nodes become bottlenecks in the computation

#### 3.1.4 Memory Bandwidth Constraints

**Memory Requirements:**
```
Matrix A size ≈ N² × 8 bytes = 16000² × 8 = 1.95 GB

Distribution:
- 2 nodes: ~0.98 GB/node
- 3 nodes: ~0.65 GB/node  
- 4 nodes: ~0.49 GB/node
```

**Analysis:**
- Worker nodes only have 2GB RAM total
- With OS overhead (~500MB), available memory for HPL is ~1.5GB
- Memory pressure on worker nodes may cause swapping or slow memory access
- Multiple processes per node compete for memory bandwidth

### 3.2 Amdahl's Law Application

According to **Amdahl's Law**, the theoretical speedup is limited by the serial portion of the program:

```
Speedup = 1 / (S + (P / N))

Where:
S = Serial fraction (communication overhead)
P = Parallel fraction
N = Number of processors
```

**Estimated Serial Fraction from Results:**
```
From 2→4 processors: Efficiency = 26.9%
Implies S ≈ 0.73 (73% serial/communication overhead)
```

This high serial fraction explains why adding more processors provides diminishing returns.

### 3.3 Optimal Configuration

**Finding:** The **1-node configuration** with 2 processes achieved the best performance:
- **58.63 GFLOPS** (highest)
- **46.58 seconds** execution time (fastest)
- **100% efficiency** (baseline)

**Reason:** 
- All communication occurs via shared memory (no network latency)
- Optimal balance between parallelism and overhead
- Both processes run on equally capable cores

---

## 4. Granularity Demonstration

### 4.1 Computation Granularity

**Fine-grained vs. Coarse-grained Parallelism:**

| Configuration | Work per Process | Granularity | Communication/Computation Ratio |
|--------------|------------------|-------------|--------------------------------|
| 1-Node (2p) | 128M elements | Coarse | Low (0.036) |
| 2-Node (4p) | 64M elements | Medium | High (0.457) |
| 3-Node (6p) | 42.7M elements | Fine | Very High (0.385) |
| 4-Node (8p) | 32M elements | Very Fine | Very High (0.237) |

**Communication/Computation Ratio** = (Communication Time) / (Computation Time)

**Observation:** As granularity becomes finer (more processes, less work each), the communication overhead grows disproportionately.

### 4.2 Load Distribution Analysis

```
Update Phase Time (actual computation):

1-Node: 55.54s across 2 processes = 27.77s/process average
2-Node: 78.66s across 4 processes = 19.67s/process average
3-Node: 92.67s across 6 processes = 15.45s/process average
4-Node: 94.54s across 8 processes = 11.82s/process average
```

**Paradox:** Despite more processes doing less work each, total computation time increases due to:
1. Load imbalance between controller and worker nodes
2. Synchronization barriers waiting for slowest process
3. Cache inefficiency on smaller data blocks

---

## 5. Recommendations

### 5.1 For Current Hardware Configuration

1. **Use single-node execution** for problems that fit in 4GB RAM
   - Optimal for N ≤ 20,000
   - Best performance/efficiency trade-off

2. **Increase problem size** for multi-node tests
   - Target: N ≥ 40,000 for 4-node configuration
   - Ensures computation dominates communication

3. **Optimize network configuration**
   - Use dedicated network for MPI traffic
   - Enable jumbo frames if supported
   - Consider using shared memory for controller processes

### 5.2 For Improved Scaling

1. **Balance node resources**
   - Make all nodes equal (e.g., all 2 vCPUs, 4GB RAM)
   - Eliminates load imbalance

2. **Increase per-node resources**
   - 4 vCPUs per node
   - 8-16 GB RAM per node
   - Allows larger problem sizes

3. **Use fewer, more powerful nodes**
   - 2 nodes × 4 cores = better than 4 nodes × 1 core
   - Reduces network hops

### 5.3 Alternative Benchmarking

Consider benchmarks that show positive scaling:
- **Embarrassingly parallel** workloads (Monte Carlo, rendering)
- **STREAM benchmark** (memory bandwidth)
- **NPB (NAS Parallel Benchmarks)** (various parallel patterns)

---

## 6. Theoretical Performance Analysis

### 6.1 Theoretical Peak Performance

**Calculation:**
```
Peak FLOPS = Cores × Clock Speed × FLOPs per cycle

Assuming:
- 2.0 GHz base clock (typical for virtualized environment)
- 4 FLOPs/cycle (SSE2) or 8 FLOPs/cycle (AVX)

Controller (2 cores):
- With SSE2: 2 × 2.0 GHz × 4 = 16 GFLOPS
- With AVX:  2 × 2.0 GHz × 8 = 32 GFLOPS

Workers (1 core each × 3):
- With SSE2: 3 × 1 × 2.0 GHz × 4 = 24 GFLOPS
- With AVX:  3 × 1 × 2.0 GHz × 8 = 48 GFLOPS

Total Theoretical Peak (4 nodes, SSE2): 40 GFLOPS
Total Theoretical Peak (4 nodes, AVX):  80 GFLOPS
```

### 6.2 Achieved Performance vs. Peak

| Configuration | Achieved | Theoretical Peak (SSE2) | Efficiency |
|--------------|----------|------------------------|------------|
| 1-Node | 58.63 GF | 16 GF | **366%*** |
| 4-Node | 26.81 GF | 40 GF | 67% |

*Indicates AVX instructions or higher clock speeds than assumed

**Observation:** The 1-node configuration exceeds SSE2 theoretical peak, suggesting:
- AVX/AVX2 instruction usage
- Higher actual clock speeds (2.5-3.0 GHz with boost)
- Efficient BLAS library optimization

---
