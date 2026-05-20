`include "uvm_macros.svh"

class ahb_coverage extends uvm_subscriber #(ahb_seq_item);
  `uvm_component_utils(ahb_coverage)

  covergroup txn_cg with function sample(ahb_seq_item t);
    option.per_instance = 1;
    cp_direction: coverpoint t.hwrite {
      bins write = {1'b1}; bins read = {1'b0};
    }
    cp_size: coverpoint t.hsize {
      bins byte_xfer = {3'b000}; bins half_xfer = {3'b001}; bins word_xfer = {3'b010};
    }
    cp_burst: coverpoint t.hburst {
      bins single = {3'b000}; bins incr = {3'b001};
      bins incr4 = {3'b011};  bins incr8 = {3'b101};
    }
    cp_addr_quad: coverpoint t.addr[9:8] {
      bins q0={2'b00}; bins q1={2'b01}; bins q2={2'b10}; bins q3={2'b11};
    }
    cp_wdata_pat: coverpoint t.write_data iff (t.hwrite) {
      bins all_zero = {32'h0};         bins all_ones = {32'hFFFF_FFFF};
      bins alt_AA   = {32'hAAAA_AAAA}; bins alt_55   = {32'h5555_5555};
      bins others   = default;
    }
    cp_beats: coverpoint t.num_beats {
      bins one={1}; bins four={4}; bins eight={8};
    }
    cx_dir_burst: cross cp_direction, cp_burst;
    cx_dir_size:  cross cp_direction, cp_size;
    cx_burst_size: cross cp_burst, cp_size;
    cx_dir_addr:  cross cp_direction, cp_addr_quad;
  endgroup

  covergroup back2back_cg with function sample(bit prev_wr, bit curr_wr);
    option.per_instance = 1;
    cp_sequence: coverpoint {prev_wr, curr_wr} {
      bins wr_then_wr = {2'b11}; bins wr_then_rd = {2'b10};
      bins rd_then_wr = {2'b01}; bins rd_then_rd = {2'b00};
    }
  endgroup

  logic prev_write;
  bit   has_prev;

  function new(string name="ahb_coverage", uvm_component parent=null);
    super.new(name, parent);
    txn_cg = new();
    back2back_cg = new();
    has_prev = 0;
  endfunction

  function void write(ahb_seq_item t);
    txn_cg.sample(t);
    if (has_prev) back2back_cg.sample(prev_write, t.hwrite);
    prev_write = t.hwrite;
    has_prev = 1;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV","",UVM_NONE)
    `uvm_info("COV","======================================",UVM_NONE)
    `uvm_info("COV","    FUNCTIONAL COVERAGE REPORT",UVM_NONE)
    `uvm_info("COV","======================================",UVM_NONE)
    `uvm_info("COV",$sformatf("  Transaction Cov  : %5.1f%%", txn_cg.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Back-to-Back Cov : %5.1f%%", back2back_cg.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Direction        : %5.1f%%", txn_cg.cp_direction.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Size             : %5.1f%%", txn_cg.cp_size.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Burst            : %5.1f%%", txn_cg.cp_burst.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Address Quad     : %5.1f%%", txn_cg.cp_addr_quad.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Dir x Burst      : %5.1f%%", txn_cg.cx_dir_burst.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Dir x Size       : %5.1f%%", txn_cg.cx_dir_size.get_coverage()),UVM_NONE)
    `uvm_info("COV",$sformatf("  Burst x Size     : %5.1f%%", txn_cg.cx_burst_size.get_coverage()),UVM_NONE)
    `uvm_info("COV","======================================",UVM_NONE)
  endfunction
endclass
