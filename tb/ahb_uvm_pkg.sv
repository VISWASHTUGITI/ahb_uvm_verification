`include "uvm_macros.svh"

package ahb_uvm_pkg;
  import uvm_pkg::*;

  // Sequence Item
  `include "ahb_seq_item.sv"

  // Coverage
  `include "ahb_coverage.sv"

  // Sequences
  `include "ahb_base_seq.sv"
  `include "ahb_write_seq.sv"
  `include "ahb_read_seq.sv"
  `include "ahb_burst_seq.sv"

  // Agent components
  `include "ahb_driver.sv"
  `include "ahb_monitor.sv"
  `include "ahb_sequencer.sv"
  `include "ahb_agent.sv"

  // Environment components
  `include "ahb_scoreboard.sv"
  `include "ahb_env.sv"

  // Tests
  `include "ahb_test.sv"

endpackage : ahb_uvm_pkg
