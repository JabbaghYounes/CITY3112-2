#!/usr/bin/env python3
"""
CITY3112 HPC Coursework - Task 4
Performance Analysis and Visualization Script

This script analyzes benchmark results and generates:
1. Throughput vs Process Count graph
2. Speedup analysis
3. Scaling efficiency metrics

Requirements:
    pip install pandas matplotlib

Usage:
    python3 analyze_results.py benchmark_results.csv
"""

import sys
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def load_and_process_data(filename):
    """Load benchmark results and compute averages."""
    df = pd.read_csv(filename)
    
    # Group by process count and calculate mean values
    summary = df.groupby('processes').agg({
        'total_mb': 'mean',
        'time_sec': 'mean',
        'throughput_mbs': 'mean'
    }).reset_index()
    
    # Calculate speedup (relative to single process)
    baseline_throughput = summary[summary['processes'] == 1]['throughput_mbs'].values[0]
    summary['speedup'] = summary['throughput_mbs'] / baseline_throughput
    
    # Calculate ideal speedup (linear)
    summary['ideal_speedup'] = summary['processes']
    
    # Calculate scaling efficiency
    summary['efficiency'] = (summary['speedup'] / summary['processes']) * 100
    
    return df, summary

def generate_plots(summary, output_prefix='task4'):
    """Generate performance visualization plots."""
    
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle('Task 4: Distributed Hashing Performance Analysis', fontsize=14, fontweight='bold')
    
    # Plot 1: Throughput vs Processes
    ax1 = axes[0, 0]
    ax1.plot(summary['processes'], summary['throughput_mbs'], 'bo-', linewidth=2, markersize=8, label='Actual')
    ax1.set_xlabel('Number of Processes')
    ax1.set_ylabel('Throughput (MB/s)')
    ax1.set_title('Throughput Scaling')
    ax1.grid(True, alpha=0.3)
    ax1.set_xticks(summary['processes'])
    ax1.legend()
    
    # Plot 2: Speedup Analysis
    ax2 = axes[0, 1]
    ax2.plot(summary['processes'], summary['speedup'], 'go-', linewidth=2, markersize=8, label='Actual Speedup')
    ax2.plot(summary['processes'], summary['ideal_speedup'], 'r--', linewidth=2, label='Ideal (Linear)')
    ax2.set_xlabel('Number of Processes')
    ax2.set_ylabel('Speedup')
    ax2.set_title('Speedup vs Ideal Linear Scaling')
    ax2.grid(True, alpha=0.3)
    ax2.set_xticks(summary['processes'])
    ax2.legend()
    
    # Plot 3: Scaling Efficiency
    ax3 = axes[1, 0]
    bars = ax3.bar(summary['processes'], summary['efficiency'], color='steelblue', edgecolor='black')
    ax3.axhline(y=100, color='red', linestyle='--', label='Ideal (100%)')
    ax3.set_xlabel('Number of Processes')
    ax3.set_ylabel('Efficiency (%)')
    ax3.set_title('Parallel Efficiency')
    ax3.set_xticks(summary['processes'])
    ax3.set_ylim(0, 120)
    ax3.legend()
    ax3.grid(True, alpha=0.3, axis='y')
    
    # Add value labels on bars
    for bar, eff in zip(bars, summary['efficiency']):
        ax3.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2, 
                f'{eff:.1f}%', ha='center', va='bottom', fontsize=9)
    
    # Plot 4: Execution Time
    ax4 = axes[1, 1]
    ax4.plot(summary['processes'], summary['time_sec'], 'mo-', linewidth=2, markersize=8)
    ax4.set_xlabel('Number of Processes')
    ax4.set_ylabel('Execution Time (seconds)')
    ax4.set_title('Execution Time vs Process Count')
    ax4.grid(True, alpha=0.3)
    ax4.set_xticks(summary['processes'])
    
    plt.tight_layout()
    plt.savefig(f'{output_prefix}_performance.png', dpi=150, bbox_inches='tight')
    plt.savefig(f'{output_prefix}_performance.pdf', bbox_inches='tight')
    print(f"Saved: {output_prefix}_performance.png")
    print(f"Saved: {output_prefix}_performance.pdf")
    
    return fig

def generate_comparison_with_hpl(summary, output_prefix='task4'):
    """
    Generate a comparison showing Task 4 vs Task 3 HPL scaling characteristics.
    Uses example HPL data - replace with actual Task 3 values.
    """
    
    # Example HPL data from Task 3 (replace with your actual values)
    hpl_data = {
        'processes': [2, 4, 6, 8],
        'gflops': [39.26, 20.03, 20.22, 18.21]
    }
    hpl_df = pd.DataFrame(hpl_data)
    
    # Normalize both to percentage of peak (for comparison)
    hpl_df['normalized'] = (hpl_df['gflops'] / hpl_df['gflops'].max()) * 100
    summary['normalized'] = (summary['throughput_mbs'] / summary['throughput_mbs'].max()) * 100
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    ax.plot(summary['processes'], summary['normalized'], 'go-', 
            linewidth=2, markersize=10, label='Task 4: Distributed Hashing')
    ax.plot(hpl_df['processes'], hpl_df['normalized'], 'rs--', 
            linewidth=2, markersize=10, label='Task 3: HPL Benchmark')
    
    ax.set_xlabel('Number of Processes', fontsize=12)
    ax.set_ylabel('Normalized Performance (%)', fontsize=12)
    ax.set_title('Scaling Comparison: Embarrassingly Parallel (Task 4) vs Tightly Coupled (Task 3)', 
                 fontsize=12, fontweight='bold')
    ax.grid(True, alpha=0.3)
    ax.set_xticks([2, 4, 6, 8])
    ax.set_ylim(0, 110)
    ax.legend(fontsize=11)
    
    # Add annotation
    ax.annotate('Negative scaling\n(communication overhead)', 
                xy=(6, hpl_df[hpl_df['processes']==6]['normalized'].values[0]),
                xytext=(7, 70),
                arrowprops=dict(arrowstyle='->', color='red'),
                fontsize=10, color='red')
    
    ax.annotate('Positive scaling\n(embarrassingly parallel)', 
                xy=(6, summary[summary['processes']==6]['normalized'].values[0] if 6 in summary['processes'].values else 80),
                xytext=(4.5, 90),
                arrowprops=dict(arrowstyle='->', color='green'),
                fontsize=10, color='green')
    
    plt.tight_layout()
    plt.savefig(f'{output_prefix}_hpl_comparison.png', dpi=150, bbox_inches='tight')
    print(f"Saved: {output_prefix}_hpl_comparison.png")
    
    return fig

def print_summary_table(summary):
    """Print a formatted summary table."""
    print("\n" + "="*70)
    print("  PERFORMANCE SUMMARY")
    print("="*70)
    print(f"{'Processes':>10} {'Total MB':>12} {'Time (s)':>12} {'MB/s':>12} {'Speedup':>10} {'Efficiency':>12}")
    print("-"*70)
    
    for _, row in summary.iterrows():
        print(f"{int(row['processes']):>10} {row['total_mb']:>12.1f} {row['time_sec']:>12.4f} "
              f"{row['throughput_mbs']:>12.2f} {row['speedup']:>10.2f}x {row['efficiency']:>11.1f}%")
    
    print("="*70)
    
    # Key findings
    max_throughput = summary['throughput_mbs'].max()
    max_procs = summary[summary['throughput_mbs'] == max_throughput]['processes'].values[0]
    avg_efficiency = summary['efficiency'].mean()
    
    print(f"\nKey Findings:")
    print(f"  - Peak throughput: {max_throughput:.2f} MB/s at {int(max_procs)} processes")
    print(f"  - Average parallel efficiency: {avg_efficiency:.1f}%")
    
    if summary[summary['processes'] == summary['processes'].max()]['efficiency'].values[0] > 70:
        print(f"  - POSITIVE SCALING demonstrated (efficiency > 70% at max processes)")
    else:
        print(f"  - Some scaling overhead observed at higher process counts")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_results.py <results_csv>")
        print("Example: python3 analyze_results.py benchmark_results.csv")
        sys.exit(1)
    
    filename = sys.argv[1]
    
    print(f"Loading data from: {filename}")
    
    try:
        raw_df, summary = load_and_process_data(filename)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error loading data: {e}")
        sys.exit(1)
    
    # Print summary table
    print_summary_table(summary)
    
    # Generate plots
    print("\nGenerating performance plots...")
    generate_plots(summary)
    
    # Generate HPL comparison
    print("\nGenerating HPL comparison plot...")
    generate_comparison_with_hpl(summary)
    
    # Save summary to CSV
    summary.to_csv('performance_summary.csv', index=False)
    print("\nSaved: performance_summary.csv")
    
    print("\nAnalysis complete!")

if __name__ == "__main__":
    main()
