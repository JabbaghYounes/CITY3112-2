/**
 * CITY3112 HPC Coursework - Task 4
 * Distributed Cryptographic Hashing for Big Data Integrity Verification
 * 
 * This program demonstrates parallel computation using MPI to perform
 * SHA-256 hashing on large datasets distributed across an HPC cluster.
 * 
 * Application Scenario:
 * A data centre needs to verify integrity of backup archives. Single-machine
 * processing is too slow for petabyte-scale data, so work is distributed
 * across multiple nodes.
 * 
 * Design Rationale (based on Task 3 HPL findings):
 * - HPL showed negative scaling due to communication overhead
 * - This application uses embarrassingly parallel design
 * - Minimal inter-node communication (only final hash aggregation)
 * - Each rank processes independent data chunks
 * - Expected outcome: near-linear speedup
 * 
 * Compilation:
 *   mpicc -O3 -o distributed_hash distributed_hash.c -lssl -lcrypto
 * 
 * Execution:
 *   mpirun --hostfile hostfile -np <processes> ./distributed_hash <chunk_size_mb>
 * 
 * Author: [Your Name]
 * Date: [Date]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <mpi.h>
#include <openssl/sha.h>

/* Constants */
#define HASH_LENGTH SHA256_DIGEST_LENGTH  /* 32 bytes for SHA-256 */
#define DEFAULT_CHUNK_SIZE_MB 100         /* Default chunk size per process */
#define BYTES_PER_MB (1024 * 1024)

/**
 * Generate deterministic pseudo-random data for a given rank.
 * Using rank as seed ensures reproducibility for verification.
 * 
 * @param buffer    Output buffer to fill with random data
 * @param size      Number of bytes to generate
 * @param rank      MPI rank (used as random seed)
 */
void generate_data_chunk(unsigned char *buffer, size_t size, int rank) {
    /* Seed random generator with rank for reproducibility */
    srand(rank * 12345 + 67890);
    
    /* Generate pseudo-random bytes */
    for (size_t i = 0; i < size; i++) {
        buffer[i] = (unsigned char)(rand() % 256);
    }
}

/**
 * Compute SHA-256 hash of a data buffer.
 * 
 * @param data      Input data to hash
 * @param size      Size of input data in bytes
 * @param hash_out  Output buffer for 32-byte hash
 */
void compute_sha256(const unsigned char *data, size_t size, unsigned char *hash_out) {
    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, data, size);
    SHA256_Final(hash_out, &sha256);
}

/**
 * Convert hash bytes to hexadecimal string for display.
 * 
 * @param hash      Input hash bytes (32 bytes)
 * @param hex_str   Output string buffer (must be at least 65 bytes)
 */
void hash_to_hex(const unsigned char *hash, char *hex_str) {
    for (int i = 0; i < HASH_LENGTH; i++) {
        sprintf(hex_str + (i * 2), "%02x", hash[i]);
    }
    hex_str[HASH_LENGTH * 2] = '\0';
}

/**
 * Print usage information.
 */
void print_usage(const char *program_name) {
    printf("Usage: mpirun --hostfile hostfile -np <processes> %s [chunk_size_mb]\n", program_name);
    printf("\n");
    printf("Arguments:\n");
    printf("  chunk_size_mb   Size of data chunk per process in MB (default: %d)\n", DEFAULT_CHUNK_SIZE_MB);
    printf("\n");
    printf("Example:\n");
    printf("  mpirun --hostfile hostfile -np 8 %s 100\n", program_name);
    printf("  (Each of 8 processes hashes 100 MB = 800 MB total)\n");
}

int main(int argc, char *argv[]) {
    int rank, size;
    int chunk_size_mb = DEFAULT_CHUNK_SIZE_MB;
    size_t chunk_size_bytes;
    unsigned char *data_chunk = NULL;
    unsigned char local_hash[HASH_LENGTH];
    unsigned char *all_hashes = NULL;
    double start_time, end_time, local_time, max_time;
    char hostname[MPI_MAX_PROCESSOR_NAME];
    int hostname_len;
    
    /* Initialize MPI */
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Get_processor_name(hostname, &hostname_len);
    
    /* Parse command line arguments (rank 0 only, then broadcast) */
    if (argc > 1) {
        if (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
            if (rank == 0) {
                print_usage(argv[0]);
            }
            MPI_Finalize();
            return 0;
        }
        chunk_size_mb = atoi(argv[1]);
        if (chunk_size_mb <= 0) {
            if (rank == 0) {
                fprintf(stderr, "Error: Invalid chunk size. Must be positive integer.\n");
                print_usage(argv[0]);
            }
            MPI_Finalize();
            return 1;
        }
    }
    
    chunk_size_bytes = (size_t)chunk_size_mb * BYTES_PER_MB;
    
    /* Print job information (rank 0 only) */
    if (rank == 0) {
        printf("=============================================================\n");
        printf("  Distributed SHA-256 Hashing - Big Data Integrity System\n");
        printf("=============================================================\n");
        printf("Configuration:\n");
        printf("  Total MPI processes:    %d\n", size);
        printf("  Chunk size per process: %d MB\n", chunk_size_mb);
        printf("  Total data to process:  %d MB (%.2f GB)\n", 
               chunk_size_mb * size, (chunk_size_mb * size) / 1024.0);
        printf("=============================================================\n");
        printf("\nStarting distributed hash computation...\n\n");
    }
    
    /* Synchronize all processes before timing */
    MPI_Barrier(MPI_COMM_WORLD);
    start_time = MPI_Wtime();
    
    /* Allocate memory for data chunk */
    data_chunk = (unsigned char *)malloc(chunk_size_bytes);
    if (data_chunk == NULL) {
        fprintf(stderr, "Rank %d: Failed to allocate %zu bytes\n", rank, chunk_size_bytes);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }
    
    /* Generate this rank's data chunk (simulates reading from distributed storage) */
    if (rank == 0) {
        printf("Phase 1: Generating data chunks...\n");
    }
    generate_data_chunk(data_chunk, chunk_size_bytes, rank);
    
    /* Compute SHA-256 hash of the chunk */
    if (rank == 0) {
        printf("Phase 2: Computing SHA-256 hashes...\n");
    }
    compute_sha256(data_chunk, chunk_size_bytes, local_hash);
    
    /* Free data chunk (no longer needed) */
    free(data_chunk);
    
    /* Record local completion time */
    local_time = MPI_Wtime() - start_time;
    
    /* Gather all hashes to rank 0 */
    if (rank == 0) {
        all_hashes = (unsigned char *)malloc(size * HASH_LENGTH);
        if (all_hashes == NULL) {
            fprintf(stderr, "Rank 0: Failed to allocate hash collection buffer\n");
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
    }
    
    MPI_Gather(local_hash, HASH_LENGTH, MPI_UNSIGNED_CHAR,
               all_hashes, HASH_LENGTH, MPI_UNSIGNED_CHAR,
               0, MPI_COMM_WORLD);
    
    /* Get maximum time across all processes (true parallel execution time) */
    MPI_Reduce(&local_time, &max_time, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    
    /* Synchronize and record final time */
    MPI_Barrier(MPI_COMM_WORLD);
    end_time = MPI_Wtime();
    
    /* Print results (rank 0 only) */
    if (rank == 0) {
        double total_time = end_time - start_time;
        double total_data_mb = (double)(chunk_size_mb * size);
        double throughput = total_data_mb / total_time;
        
        printf("\n=============================================================\n");
        printf("  Results\n");
        printf("=============================================================\n");
        
        /* Print individual hash results */
        printf("\nHash Results by Rank:\n");
        printf("-------------------------------------------------------------\n");
        for (int i = 0; i < size; i++) {
            char hex_str[HASH_LENGTH * 2 + 1];
            hash_to_hex(all_hashes + (i * HASH_LENGTH), hex_str);
            printf("  Rank %d: %s\n", i, hex_str);
        }
        
        /* Print performance metrics */
        printf("\n=============================================================\n");
        printf("  Performance Metrics\n");
        printf("=============================================================\n");
        printf("  Total data processed:   %.2f MB (%.2f GB)\n", total_data_mb, total_data_mb / 1024.0);
        printf("  Total execution time:   %.4f seconds\n", total_time);
        printf("  Max worker time:        %.4f seconds\n", max_time);
        printf("  Throughput:             %.2f MB/s\n", throughput);
        printf("  Processes used:         %d\n", size);
        printf("=============================================================\n");
        
        /* Output CSV-friendly line for data collection */
        printf("\nCSV Output (processes,chunk_mb,total_mb,time_sec,throughput_mbs):\n");
        printf("%d,%d,%.2f,%.4f,%.2f\n", size, chunk_size_mb, total_data_mb, total_time, throughput);
        
        free(all_hashes);
    }
    
    /* Each rank also prints its completion for verification */
    /* Use barrier and sequential printing to avoid garbled output */
    for (int i = 0; i < size; i++) {
        if (rank == i) {
            char hex_str[HASH_LENGTH * 2 + 1];
            hash_to_hex(local_hash, hex_str);
            printf("[Rank %d on %s] Processed %d MB in %.4f sec - Hash: %.16s...\n",
                   rank, hostname, chunk_size_mb, local_time, hex_str);
        }
        MPI_Barrier(MPI_COMM_WORLD);
    }
    
    MPI_Finalize();
    return 0;
}
