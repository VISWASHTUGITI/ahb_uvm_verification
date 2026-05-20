#!/bin/bash
# ==============================================================
# run.sh  —  AHB UVM Verification Simulation Script
# Supports Questa (vlog/vsim) and VCS
# Usage:
#   ./sim/run.sh                          # default: ahb_full_test
#   ./sim/run.sh ahb_single_rw_test
#   ./sim/run.sh ahb_burst_test
#   ./sim/run.sh ahb_random_test
#   ./sim/run.sh ahb_back2back_test
#   ./sim/run.sh ahb_boundary_test
#   ./sim/run.sh ahb_all_burst_test
# ==============================================================

TEST=${1:-ahb_full_test}
TOOL=${TOOL:-questa}      # set TOOL=vcs to switch

echo "============================================"
echo "  AHB UVM Verification"
echo "  Tool : $TOOL"
echo "  Test : $TEST"
echo "============================================"

if [ "$TOOL" = "questa" ]; then
  # ---------- Questa / ModelSim ----------
  vlib work
  vmap work work

  vlog -sv -f ../sim/flist.f \
       +define+UVM_NO_DEPRECATED \
       -suppress 2167 \
       || { echo "[ERROR] Compilation failed"; exit 1; }

  vsim -c work.ahb_tb_top \
       +UVM_TESTNAME=$TEST \
       +UVM_VERBOSITY=UVM_LOW \
       -do "run -all; quit -f" \
       || { echo "[ERROR] Simulation failed"; exit 1; }

elif [ "$TOOL" = "vcs" ]; then
  # ---------- Synopsys VCS ----------
  vcs -sverilog -f ../sim/flist.f \
      +define+UVM_NO_DEPRECATED \
      -ntb_opts uvm \
      -o simv \
      || { echo "[ERROR] Compilation failed"; exit 1; }

  ./simv \
      +UVM_TESTNAME=$TEST \
      +UVM_VERBOSITY=UVM_LOW \
      || { echo "[ERROR] Simulation failed"; exit 1; }

else
  echo "[ERROR] Unknown TOOL=$TOOL. Set TOOL=questa or TOOL=vcs"
  exit 1
fi

echo "============================================"
echo "  Simulation DONE : $TEST"
echo "============================================"
