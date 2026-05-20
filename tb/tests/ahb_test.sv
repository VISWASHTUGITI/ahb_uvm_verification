`include "uvm_macros.svh"

class ahb_base_test extends uvm_test;
  `uvm_component_utils(ahb_base_test)
  ahb_env env;
  function new(string name="ahb_base_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env=ahb_env::type_id::create("env",this);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this); #200; phase.drop_objection(this);
  endtask
endclass

class ahb_single_rw_test extends ahb_base_test;
  `uvm_component_utils(ahb_single_rw_test)
  function new(string name="ahb_single_rw_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_write_read_seq wrrd;
    phase.raise_objection(this);
    wrrd=ahb_write_read_seq::type_id::create("wrrd1");
    wrrd.test_addr=32'h000; wrrd.test_data=32'hDEAD_BEEF;
    wrrd.start(env.agt.seqr); #20;
    wrrd=ahb_write_read_seq::type_id::create("wrrd2");
    wrrd.test_addr=32'h100; wrrd.test_data=32'hCAFE_BABE;
    wrrd.start(env.agt.seqr); #20;
    wrrd=ahb_write_read_seq::type_id::create("wrrd3");
    wrrd.test_addr=32'h004; wrrd.test_data=32'h1234_5678;
    wrrd.start(env.agt.seqr); #50;
    phase.drop_objection(this);
  endtask
endclass

class ahb_burst_test extends ahb_base_test;
  `uvm_component_utils(ahb_burst_test)
  function new(string name="ahb_burst_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_burst_write_seq bwr; ahb_burst_read_seq brd;
    phase.raise_objection(this);
    bwr=ahb_burst_write_seq::type_id::create("bwr1");
    bwr.use_fixed=1; bwr.base_addr=32'h10; bwr.burst_type=3'b011;
    bwr.start(env.agt.seqr); #30;
    brd=ahb_burst_read_seq::type_id::create("brd1");
    brd.use_fixed=1; brd.base_addr=32'h10; brd.burst_type=3'b011;
    brd.start(env.agt.seqr); #50;
    phase.drop_objection(this);
  endtask
endclass

class ahb_random_test extends ahb_base_test;
  `uvm_component_utils(ahb_random_test)
  int unsigned num_txns=30;
  function new(string name="ahb_random_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("num_txns=%0d",num_txns));
  endfunction
  task run_phase(uvm_phase phase);
    ahb_random_seq rseq;
    phase.raise_objection(this);
    rseq=ahb_random_seq::type_id::create("rseq");
    rseq.num_txns=num_txns;
    rseq.start(env.agt.seqr); #100;
    phase.drop_objection(this);
  endtask
endclass

class ahb_back2back_test extends ahb_base_test;
  `uvm_component_utils(ahb_back2back_test)
  function new(string name="ahb_back2back_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_back2back_seq b2b;
    phase.raise_objection(this);
    b2b=ahb_back2back_seq::type_id::create("b2b");
    b2b.num_pairs=5;
    b2b.start(env.agt.seqr); #50;
    phase.drop_objection(this);
  endtask
endclass

class ahb_boundary_test extends ahb_base_test;
  `uvm_component_utils(ahb_boundary_test)
  function new(string name="ahb_boundary_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_boundary_seq bnd;
    phase.raise_objection(this);
    bnd=ahb_boundary_seq::type_id::create("bnd");
    bnd.start(env.agt.seqr); #50;
    phase.drop_objection(this);
  endtask
endclass

class ahb_all_burst_test extends ahb_base_test;
  `uvm_component_utils(ahb_all_burst_test)
  function new(string name="ahb_all_burst_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_all_burst_seq ab;
    phase.raise_objection(this);
    ab=ahb_all_burst_seq::type_id::create("ab");
    ab.start(env.agt.seqr); #50;
    phase.drop_objection(this);
  endtask
endclass

class ahb_full_test extends ahb_base_test;
  `uvm_component_utils(ahb_full_test)
  function new(string name="ahb_full_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    ahb_write_read_seq    wrrd;
    ahb_all_burst_seq     ab;
    ahb_boundary_seq      bnd;
    ahb_data_pattern_seq  dp;
    ahb_back2back_seq     b2b;
    ahb_random_seq        rseq;

    phase.raise_objection(this);
    `uvm_info("TEST","== Full Regression START ==",UVM_NONE)

    // Phase 1: Single R/W at 0x000
    wrrd=ahb_write_read_seq::type_id::create("p1");
    wrrd.test_addr=32'h000; wrrd.test_data=32'hDEAD_BEEF;
    wrrd.start(env.agt.seqr); #10;

    // Phase 2: Bursts at 0x040, 0x080
    ab=ahb_all_burst_seq::type_id::create("p2");
    ab.start(env.agt.seqr); #10;

    // Phase 3: Data patterns at 0x100-0x11C
    dp=ahb_data_pattern_seq::type_id::create("p3");
    dp.start(env.agt.seqr); #10;

    // Phase 4: Back-to-back at 0x280-0x2FC
    b2b=ahb_back2back_seq::type_id::create("p4");
    b2b.num_pairs=5;
    b2b.start(env.agt.seqr); #10;

    // Phase 5: Boundary at 0x300-0x3FC
    bnd=ahb_boundary_seq::type_id::create("p5");
    bnd.start(env.agt.seqr); #10;

    // Phase 6: Random writes+reads at 0x350+ (write own pool, read back)
    rseq=ahb_random_seq::type_id::create("p6");
    rseq.num_txns=10;
    rseq.start(env.agt.seqr); #100;

    `uvm_info("TEST","== Full Regression DONE ==",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
