#!/bin/bash
# ------------------------------------------------------------
# Script: hpl-checklist.sh
# Purpose: Pre-run sanity checks before HPL benchmarking
# Checks:
#   - OpenBLAS thread oversubscription prevention
#   - OpenBLAS library visibility
#   - OpenMPI compiler wrapper
# Nodes: controller, worker1, worker2, worker3
# ------------------------------------------------------------

NODES=("controller" "worker1" "worker2" "worker3")

echo "============================================================"
echo " HPL PRE-RUN CHECKLIST"
echo "============================================================"

for NODE in "${NODES[@]}"; do
  echo
  echo ">>> Checking node: $NODE"
  echo "------------------------------------------------------------"

  ssh "$NODE" bash <<'EOF'
    echo "[INFO] Hostname: $(hostname)"

    # ----------------------------------------------------------
    # 1. Ensure OPENBLAS_NUM_THREADS is set to 1
    # ----------------------------------------------------------
    if grep -q "OPENBLAS_NUM_THREADS=1" ~/.bashrc; then
      echo "[PASS] OPENBLAS_NUM_THREADS already set in ~/.bashrc"
    else
      echo "[INFO] Setting OPENBLAS_NUM_THREADS=1 in ~/.bashrc"
      echo "export OPENBLAS_NUM_THREADS=1" >> ~/.bashrc
      echo "[PASS] OPENBLAS_NUM_THREADS added to ~/.bashrc"
    fi

    # Apply immediately for current session
    export OPENBLAS_NUM_THREADS=1
    echo "[INFO] OPENBLAS_NUM_THREADS active value: $OPENBLAS_NUM_THREADS"

    # ----------------------------------------------------------
    # 2. Verify OpenBLAS library visibility
    # ----------------------------------------------------------
    if ldconfig -p | grep -q libopenblas; then
      echo "[PASS] OpenBLAS library found by dynamic linker"
      ldconfig -p | grep libopenblas | head -n 2
    else
      echo "[FAIL] OpenBLAS library NOT found by dynamic linker"
    fi

    # ----------------------------------------------------------
    # 3. Verify MPI compiler wrapper
    # ----------------------------------------------------------
    if command -v mpicc &>/dev/null; then
      echo "[PASS] mpicc found"
      echo "[INFO] mpicc configuration:"
      mpicc --showme
    else
      echo "[FAIL] mpicc not found — OpenMPI may not be installed correctly"
    fi

    echo "[INFO] Pre-run checks completed on $(hostname)"
EOF

done

echo
echo "============================================================"
echo " PRE-RUN CHECKLIST COMPLETED ON ALL NODES"
echo "============================================================"
