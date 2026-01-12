#!/usr/bin/env python3
import matplotlib.pyplot as plt
import csv

# Read data
configs = []
performance = []

with open('benchmark_results.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        configs.append(row['Test'])
        performance.append(float(row['Performance_GFLOPS']))

# Create bar chart
plt.figure(figsize=(12, 6))
bars = plt.bar(configs, performance, color=['green', 'blue', 'orange', 'red'])
plt.xlabel('Configuration', fontsize=12)
plt.ylabel('Performance (GFLOPS)', fontsize=12)
plt.title('HPL Benchmark Results - Performance by Configuration', fontsize=14, fontweight='bold')
plt.xticks(rotation=45, ha='right')
plt.grid(axis='y', alpha=0.3)

# Add value labels on bars
for bar in bars:
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height,
            f'{height:.2f}',
            ha='center', va='bottom', fontsize=10)

plt.tight_layout()
plt.savefig('performance_comparison.png', dpi=300)
print("✓ Chart saved: performance_comparison.png")

# Create scaling efficiency chart
processes = [2, 4, 6, 8]
baseline = performance[0]
speedup = [p/baseline for p in performance]
ideal_speedup = [1, 2, 3, 4]

plt.figure(figsize=(10, 6))
plt.plot(processes, speedup, 'o-', label='Actual Speedup', linewidth=2, markersize=8)
plt.plot(processes, ideal_speedup, '--', label='Ideal Linear Speedup', linewidth=2)
plt.xlabel('Number of Processes', fontsize=12)
plt.ylabel('Speedup (relative to 2 processes)', fontsize=12)
plt.title('Scaling Efficiency Analysis', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('scaling_efficiency.png', dpi=300)
print("✓ Chart saved: scaling_efficiency.png")
