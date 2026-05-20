// ============================================================
// flist.f  —  AHB UVM Verification File List
// Compile order: RTL → Interface → TB Package → Top
// Usage:
//   Questa : vlog -f flist.f
//   VCS    : vcs -f flist.f
// ============================================================

// ---- UVM Library (adjust path to your installation) --------
-incdir $UVM_HOME/src
$UVM_HOME/src/uvm_pkg.sv

// ---- RTL ---------------------------------------------------
rtl/ahb_slave.sv

// ---- Interface ---------------------------------------------
interface/ahb_if.sv

// ---- TB Package (includes all TB files via `include) -------
+incdir+tb/seq_item
+incdir+tb/coverage
+incdir+tb/sequences
+incdir+tb/agent
+incdir+tb/env
+incdir+tb/tests
tb/ahb_uvm_pkg.sv

// ---- Top ---------------------------------------------------
tb/top/top.sv
