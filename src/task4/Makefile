# CITY3112 HPC Coursework - Task 4
# Makefile for Distributed SHA-256 Hashing Application

CC = mpicc
CFLAGS = -O3 -Wall
LDFLAGS = -lssl -lcrypto

TARGET = distributed_hash
SOURCE = distributed_hash.c

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE) $(LDFLAGS)

clean:
	rm -f $(TARGET)

# Quick test with 2 processes locally
test: $(TARGET)
	mpirun -np 2 ./$(TARGET) 10

# Run scaling tests (for data collection)
benchmark: $(TARGET)
	@echo "Running scaling benchmark..."
	@echo "processes,chunk_mb,total_mb,time_sec,throughput_mbs" > results.csv
	@for np in 1 2 4 6 8; do \
		echo "Testing with $$np processes..."; \
		mpirun --hostfile hostfile -np $$np ./$(TARGET) 100 2>/dev/null | grep "^[0-9]" >> results.csv; \
	done
	@echo "Results saved to results.csv"
