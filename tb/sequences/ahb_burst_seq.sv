`include "uvm_macros.svh"

class ahb_write_read_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_write_read_seq)
  logic [31:0] test_addr=32'h0, test_data=32'hCAFE_BABE;
  function new(string name="ahb_write_read_seq"); super.new(name); endfunction
  task body();
    ahb_single_write_seq wr;
    ahb_single_read_seq  rd;
    wr=ahb_single_write_seq::type_id::create("wr");
    wr.use_fixed=1; wr.target_addr=test_addr; wr.target_data=test_data;
    wr.start(m_sequencer);
    #20;
    rd=ahb_single_read_seq::type_id::create("rd");
    rd.use_fixed=1; rd.target_addr=test_addr;
    rd.start(m_sequencer);
    // Read data is captured and checked by the MONITOR + SCOREBOARD (the single
    // source of truth); the driver no longer reads data back. Log an
    // informational message only.
    `uvm_info("SEQ",$sformatf("Issued WR then RD at A=0x%08h; read-back verified by scoreboard",test_addr),UVM_LOW)
  endtask
endclass

// Random sequence: writes addrs to pool, then reads them back
class ahb_random_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_random_seq)
  int unsigned num_txns=20;
  function new(string name="ahb_random_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item item;
    logic [31:0] addr_pool[$];
    int idx;
    repeat(num_txns) begin
      item = ahb_seq_item::type_id::create("rnd");
      start_item(item);
      if (addr_pool.size() < num_txns/2) begin
        if(!item.randomize() with {
              htrans==2'b10; hburst==3'b000; hsize==3'b010;
              hwrite==1'b1; num_beats==1;
              addr>=32'h350;
            }) `uvm_fatal("SEQ","RND WR fail")
        addr_pool.push_back(item.addr);
      end else begin
        idx = $urandom_range(0, addr_pool.size()-1);
        if(!item.randomize() with {
              htrans==2'b10; hburst==3'b000; hsize==3'b010;
              hwrite==1'b0; num_beats==1;
              addr == local::addr_pool[local::idx];
            }) `uvm_fatal("SEQ","RND RD fail")
      end
      finish_item(item);
    end
  endtask
endclass

class ahb_back2back_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_back2back_seq)
  int unsigned num_pairs=5;
  function new(string name="ahb_back2back_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item item;
    logic [31:0] addrs[$];
    int i;
    repeat(num_pairs) begin
      item = ahb_seq_item::type_id::create("b2b_wr");
      start_item(item);
      if(!item.randomize() with {
            htrans==2'b10; hburst==3'b000; hsize==3'b010;
            hwrite==1'b1; num_beats==1;
            addr inside {[32'h280:32'h2FC]};
          }) `uvm_fatal("SEQ","B2B WR fail")
      addrs.push_back(item.addr);
      finish_item(item);
    end
    foreach(addrs[i]) begin
      item = ahb_seq_item::type_id::create("b2b_rd");
      start_item(item);
      if(!item.randomize() with {
            htrans==2'b10; hburst==3'b000; hsize==3'b010;
            hwrite==1'b0; num_beats==1;
            addr==local::addrs[local::i];
          }) `uvm_fatal("SEQ","B2B RD fail")
      finish_item(item);
    end
  endtask
endclass

// Boundary sequence: uses HIGH addresses 0x300-0x3FC
class ahb_boundary_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_boundary_seq)
  function new(string name="ahb_boundary_seq"); super.new(name); endfunction
  task body();
    ahb_write_read_seq wrrd;
    logic [31:0] test_addrs[] = '{
      32'h300, 32'h304, 32'h3F8, 32'h3FC
    };
    logic [31:0] test_datas[] = '{
      32'hAAAA_0001, 32'hBBBB_0002, 32'hCCCC_0003, 32'hDEAD_BEEF
    };
    foreach(test_addrs[i]) begin
      wrrd = ahb_write_read_seq::type_id::create($sformatf("bnd_%0d",i));
      wrrd.test_addr = test_addrs[i];
      wrrd.test_data = test_datas[i];
      wrrd.start(m_sequencer);
      #10;
    end
  endtask
endclass

class ahb_all_burst_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_all_burst_seq)
  function new(string name="ahb_all_burst_seq"); super.new(name); endfunction
  task body();
    ahb_burst_write_seq bwr;
    ahb_burst_read_seq  brd;

    bwr=ahb_burst_write_seq::type_id::create("ab_s_w");
    bwr.use_fixed=1; bwr.base_addr=32'h000; bwr.burst_type=3'b000;
    bwr.start(m_sequencer); #20;

    bwr=ahb_burst_write_seq::type_id::create("ab_i4_w");
    bwr.use_fixed=1; bwr.base_addr=32'h040; bwr.burst_type=3'b011;
    bwr.start(m_sequencer); #20;
    brd=ahb_burst_read_seq::type_id::create("ab_i4_r");
    brd.use_fixed=1; brd.base_addr=32'h040; brd.burst_type=3'b011;
    brd.start(m_sequencer); #20;

    bwr=ahb_burst_write_seq::type_id::create("ab_i8_w");
    bwr.use_fixed=1; bwr.base_addr=32'h080; bwr.burst_type=3'b101;
    bwr.start(m_sequencer); #20;
    brd=ahb_burst_read_seq::type_id::create("ab_i8_r");
    brd.use_fixed=1; brd.base_addr=32'h080; brd.burst_type=3'b101;
    brd.start(m_sequencer); #20;
  endtask
endclass

// Data patterns: use 0x100-0x1FC range
class ahb_data_pattern_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_data_pattern_seq)
  function new(string name="ahb_data_pattern_seq"); super.new(name); endfunction
  task body();
    ahb_write_read_seq wrrd;
    logic [31:0] patterns[] = '{
      32'h0000_0000, 32'hFFFF_FFFF,
      32'hAAAA_AAAA, 32'h5555_5555,
      32'h0F0F_0F0F, 32'hF0F0_F0F0,
      32'h00FF_00FF, 32'hFF00_FF00
    };
    foreach(patterns[i]) begin
      wrrd = ahb_write_read_seq::type_id::create($sformatf("pat_%0d",i));
      wrrd.test_addr = 32'h100 + (i*4);
      wrrd.test_data = patterns[i];
      wrrd.start(m_sequencer);
      #10;
    end
  endtask
endclass
