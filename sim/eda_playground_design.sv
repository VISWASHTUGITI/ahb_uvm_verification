`include "uvm_macros.svh"
// SINGLE-FILE BUILD for EDA Playground (auto-generated)
// DUT: combinational HRDATA. Clocking blocks. Driver drives bus only.
// Select: SystemVerilog + UVM 1.2. Run: +UVM_TESTNAME=ahb_full_test

// ---- dut ----
module ahb_slave_mem #(
  parameter int MEM_DEPTH  = 256,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  input  logic                  HCLK,
  input  logic                  HRESETn,
  input  logic                  HSEL,
  input  logic [ADDR_WIDTH-1:0] HADDR,
  input  logic                  HWRITE,
  input  logic [1:0]            HTRANS,
  input  logic [2:0]            HSIZE,
  input  logic [2:0]            HBURST,
  input  logic [3:0]            HPROT,
  input  logic                  HMASTLOCK,
  input  logic                  HREADY,
  input  logic [DATA_WIDTH-1:0] HWDATA,
  output logic [DATA_WIDTH-1:0] HRDATA,
  output logic                  HREADYOUT,
  output logic [1:0]            HRESP
);

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
  logic wr_en_d, rd_en_d;
  logic [ADDR_WIDTH-1:0] addr_d;
  logic [2:0] hsize_d;

  wire addr_valid = HSEL && HREADY && (HTRANS==2'b10 || HTRANS==2'b11);
  wire [$clog2(MEM_DEPTH)-1:0] waddr = addr_d[$clog2(MEM_DEPTH)+1:2];

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if(!HRESETn) begin
      wr_en_d<=0; rd_en_d<=0; addr_d<='0; hsize_d<='0;
    end else begin
      wr_en_d <= addr_valid &&  HWRITE;
      rd_en_d <= addr_valid && !HWRITE;
      addr_d  <= HADDR;
      hsize_d <= HSIZE;
    end
  end

  logic [3:0] byte_en;
  always_comb begin
    case(hsize_d)
      3'b000: case(addr_d[1:0])
                2'b00:byte_en=4'b0001; 2'b01:byte_en=4'b0010;
                2'b10:byte_en=4'b0100; 2'b11:byte_en=4'b1000;
                default:byte_en=4'b0000;
              endcase
      3'b001: case(addr_d[1])
                1'b0:byte_en=4'b0011; 1'b1:byte_en=4'b1100;
                default:byte_en=4'b0000;
              endcase
      default: byte_en=4'b1111;
    endcase
  end

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if(!HRESETn) begin : rst_mem
      integer i;
      for(i=0;i<MEM_DEPTH;i++) mem[i]<='0;
    end else if(wr_en_d) begin
      if(byte_en[0]) mem[waddr][ 7: 0] <= HWDATA[ 7: 0];
      if(byte_en[1]) mem[waddr][15: 8] <= HWDATA[15: 8];
      if(byte_en[2]) mem[waddr][23:16] <= HWDATA[23:16];
      if(byte_en[3]) mem[waddr][31:24] <= HWDATA[31:24];
    end
  end

  // READ DATA PHASE (combinational, proper AHB pipelining).
  // AHB 2-phase pipeline: the address is sampled during the address phase and
  // the read data is presented combinationally during the data phase (the cycle
  // after the address is sampled). So HRDATA is derived directly from the
  // registered address (addr_d) and read-enable (rd_en_d) -- NO extra registered
  // cycle on the read output. This makes the read data valid at the correct edge
  // so the master can sample it one edge after the address was presented.
  logic [DATA_WIDTH-1:0] rdata_comb;
  always_comb begin
    if (rd_en_d) rdata_comb = mem[waddr];
    else         rdata_comb = '0;
  end
  assign HRDATA = rdata_comb;

  assign HREADYOUT = 1'b1;
  assign HRESP     = 2'b00;

endmodule : ahb_slave_mem

// ---- if ----
interface ahb_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  input logic HCLK,
  input logic HRESETn
);

  logic [ADDR_WIDTH-1:0] HADDR;
  logic [1:0]            HTRANS;
  logic                  HWRITE;
  logic [2:0]            HSIZE;
  logic [2:0]            HBURST;
  logic [3:0]            HPROT;
  logic                  HMASTLOCK;
  logic                  HSEL;
  logic [DATA_WIDTH-1:0] HWDATA;
  logic [DATA_WIDTH-1:0] HRDATA;
  logic                  HREADY;
  logic                  HREADYOUT;
  logic [1:0]            HRESP;

  // ---------------------------------------------------------------------
  // Clocking blocks. These eliminate race conditions around the clock edge
  // by using the SystemVerilog event scheduler's skew controls:
  //
  //   drv_cb (driver): outputs are driven with "output #1" (1 time unit AFTER
  //                    the posedge) and inputs are sampled "input #1step"
  //                    (just BEFORE the edge). So a value the master drives at
  //                    edge N is only *seen* by the DUT at edge N+1, and the
  //                    DUT never races against the freshly-driven value.
  //   mon_cb (monitor): samples all signals "input #1step" (just BEFORE the
  //                     edge), so it always captures the stable pre-edge value
  //                     and never sees same-edge NBA updates.
  //
  // This is the standard UVM way to avoid the "sample at the same posedge you
  // drove" ambiguity.
  // ---------------------------------------------------------------------
  clocking drv_cb @(posedge HCLK);
    default input #1step output #1;
    output HADDR, HTRANS, HWRITE, HSIZE, HBURST, HPROT, HMASTLOCK, HSEL, HWDATA;
    input  HRDATA, HREADY, HREADYOUT, HRESP;
  endclocking

  clocking mon_cb @(posedge HCLK);
    default input #1step;
    input HADDR, HTRANS, HWRITE, HSIZE, HBURST, HPROT, HMASTLOCK, HSEL,
          HWDATA, HRDATA, HREADY, HREADYOUT, HRESP;
  endclocking

  modport DRIVER_MP (
    clocking drv_cb,
    input  HCLK, HRESETn, HRDATA, HREADY, HREADYOUT, HRESP,
    output HADDR, HTRANS, HWRITE, HSIZE, HBURST, HPROT, HMASTLOCK, HWDATA, HSEL
  );

  modport MONITOR_MP (
    clocking mon_cb,
    input HCLK, HRESETn,
    input HADDR, HTRANS, HWRITE, HSIZE, HBURST, HPROT, HMASTLOCK, HSEL,
    input HWDATA, HRDATA, HREADY, HREADYOUT, HRESP
  );

  property p_hready_not_stuck;
    @(posedge HCLK) disable iff (!HRESETn)
    $fell(HREADY) |-> ##[1:16] $rose(HREADY);
  endproperty
  ap_hready: assert property (p_hready_not_stuck)
    else $warning("[SVA] HREADY stuck low");

  property p_word_aligned;
    @(posedge HCLK) disable iff (!HRESETn)
    (HSEL && HSIZE==3'b010 && (HTRANS==2'b10||HTRANS==2'b11))
    |-> (HADDR[1:0]==2'b00);
  endproperty
  ap_word_align: assert property (p_word_aligned)
    else $error("[SVA] WORD not aligned HADDR=0x%08h", HADDR);

  covergroup ahb_protocol_cg @(posedge HCLK);
    option.per_instance = 1;
    cp_htrans: coverpoint HTRANS iff (HSEL && HREADY) {
      bins idle   = {2'b00};
      bins nonseq = {2'b10};
      bins seq_t  = {2'b11};
    }
    cp_hburst: coverpoint HBURST iff (HSEL && HREADY && (HTRANS==2'b10)) {
      bins single = {3'b000};
      bins incr   = {3'b001};
      bins incr4  = {3'b011};
      bins incr8  = {3'b101};
    }
    cp_hsize: coverpoint HSIZE iff (HSEL && HREADY && (HTRANS==2'b10||HTRANS==2'b11)) {
      bins byte_sz = {3'b000};
      bins half_sz = {3'b001};
      bins word_sz = {3'b010};
    }
    cp_hwrite: coverpoint HWRITE iff (HSEL && HREADY && (HTRANS==2'b10||HTRANS==2'b11)) {
      bins read  = {1'b0};
      bins write = {1'b1};
    }
    cx_burst_rw: cross cp_hburst, cp_hwrite;
    cx_size_rw:  cross cp_hsize, cp_hwrite;
  endgroup
  ahb_protocol_cg cov_inst = new();

endinterface : ahb_if

package ahb_uvm_pkg;
  import uvm_pkg::*;

class ahb_seq_item extends uvm_sequence_item;
  rand logic [31:0] addr;
  rand logic [31:0] write_data;
  rand logic        hwrite;
  rand logic [2:0]  hsize;
  rand logic [2:0]  hburst;
  rand logic [1:0]  htrans;
  rand logic [3:0]  hprot;
  rand int unsigned num_beats;
  logic [31:0]      read_data;
  logic [1:0]       hresp;

  // Per-beat payload, filled by the MONITOR (not randomized). This lets the
  // scoreboard verify EVERY beat of a burst at its OWN address, instead of only
  // the last beat like the original code did.
  int unsigned n_captured;        // number of beats actually observed on the bus
  logic [31:0] beat_addr_q[$];    // address of each beat
  logic [31:0] beat_wdata_q[$];   // write data of each beat (writes only)
  logic [31:0] beat_rdata_q[$];   // read data of each beat (reads only)

  // NOTE: the field macros must come AFTER the member declarations. Questa
  // resolves the names in the generated do_copy/do_print/do_compare functions
  // textually, so declaring the members first is required to avoid
  // "Undefined variable" errors.
  `uvm_object_utils_begin(ahb_seq_item)
    `uvm_field_int(addr,       UVM_ALL_ON)
    `uvm_field_int(write_data, UVM_ALL_ON)
    `uvm_field_int(read_data,  UVM_ALL_ON)
    `uvm_field_int(hwrite,     UVM_ALL_ON)
    `uvm_field_int(hsize,      UVM_ALL_ON)
    `uvm_field_int(hburst,     UVM_ALL_ON)
    `uvm_field_int(htrans,     UVM_ALL_ON)
    `uvm_field_int(hprot,      UVM_ALL_ON)
    `uvm_field_int(num_beats,  UVM_ALL_ON)
    `uvm_field_int(n_captured, UVM_ALL_ON)
    `uvm_field_int(hresp,      UVM_ALL_ON)
    `uvm_field_queue_int(beat_addr_q,  UVM_ALL_ON)
    `uvm_field_queue_int(beat_wdata_q, UVM_ALL_ON)
    `uvm_field_queue_int(beat_rdata_q, UVM_ALL_ON)
  `uvm_object_utils_end

  constraint c_addr_range  { addr inside {[32'h0:32'h3FC]}; }
  constraint c_addr_align  {
    (hsize==3'b001) -> (addr[0]  ==1'b0);
    (hsize==3'b010) -> (addr[1:0]==2'b00);
  }
  constraint c_hsize       { hsize inside {3'b000,3'b001,3'b010}; }
  constraint c_hburst      { hburst inside {3'b000,3'b001,3'b011,3'b101}; }
  constraint c_num_beats   {
    (hburst==3'b000) -> num_beats==1;
    (hburst==3'b001) -> num_beats inside {[1:4]};
    (hburst==3'b011) -> num_beats==4;
    (hburst==3'b101) -> num_beats==8;
  }
  constraint c_htrans      { htrans==2'b10; }
  constraint c_hprot       { hprot==4'b0011; }
  constraint c_rw_mix      { hwrite dist {1'b1:=50,1'b0:=50}; }
  constraint c_burst_safe  {
    // keep the whole burst inside the 256-word (0x000-0x3FC) memory
    (hburst==3'b001) -> addr<=32'h3F0;   // INCR: up to 4 beats
    (hburst==3'b011) -> addr<=32'h3F0;   // INCR4: 4 beats
    (hburst==3'b101) -> addr<=32'h3E0;   // INCR8: 8 beats
  }

  function new(string name="ahb_seq_item"); super.new(name); endfunction

  function string convert2string();
    string b;
    case(hburst)
      3'b000:b="SINGLE"; 3'b001:b="INCR"; 3'b011:b="INCR4";
      3'b101:b="INCR8"; default:b=$sformatf("B%03b",hburst);
    endcase
    return $sformatf("[AHB] %s A=0x%08h WD=0x%08h RD=0x%08h %s BEATS=%0d",
      (hwrite?"WR":"RD"), addr, write_data, read_data, b, num_beats);
  endfunction
endclass

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
      bins one   = {1};
      bins two   = {2};
      bins three = {3};
      bins four  = {4};
      bins eight = {8};
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

class ahb_base_seq extends uvm_sequence #(ahb_seq_item);
  `uvm_object_utils(ahb_base_seq)
  function new(string name="ahb_base_seq"); super.new(name); endfunction
endclass

class ahb_single_write_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_single_write_seq)
  logic [31:0] target_addr=32'h0, target_data=32'hDEAD_BEEF;
  bit use_fixed=0;
  function new(string name="ahb_single_write_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item item = ahb_seq_item::type_id::create("swr");
    start_item(item);
    if (!item.randomize() with {
          htrans==2'b10; hburst==3'b000; hsize==3'b010;
          hwrite==1'b1; num_beats==1;
          if(local::use_fixed) {
            addr==local::target_addr;
            write_data==local::target_data;
          }
        }) `uvm_fatal("SEQ","WR rand fail")
    finish_item(item);
  endtask
endclass

class ahb_burst_write_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_burst_write_seq)
  logic [31:0] base_addr=32'h10;
  logic [2:0] burst_type=3'b011;
  bit use_fixed=0;
  function new(string name="ahb_burst_write_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item item = ahb_seq_item::type_id::create("bwr");
    start_item(item);
    if (!item.randomize() with {
          htrans==2'b10; hburst==local::burst_type; hsize==3'b010; hwrite==1'b1;
          if(local::use_fixed) addr==local::base_addr;
        }) `uvm_fatal("SEQ","BWR rand fail")
    finish_item(item);
  endtask
endclass

class ahb_single_read_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_single_read_seq)
  logic [31:0] target_addr=32'h0;
  bit use_fixed=0;
  function new(string name="ahb_single_read_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item item = ahb_seq_item::type_id::create("srd");
    start_item(item);
    if (!item.randomize() with {
          htrans==2'b10; hburst==3'b000; hsize==3'b010;
          hwrite==1'b0; num_beats==1;
          if(local::use_fixed) { addr==local::target_addr; }
        }) `uvm_fatal("SEQ","RD rand fail")
    finish_item(item);
    // Read data is verified by the monitor + scoreboard; the driver does not
    // capture read data back.
  endtask
endclass

class ahb_burst_read_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_burst_read_seq)
  logic [31:0] base_addr=32'h10;
  logic [2:0] burst_type=3'b011;
  bit use_fixed=0;
  function new(string name="ahb_burst_read_seq"); super.new(name); endfunction
  task body();
    ahb_seq_item item = ahb_seq_item::type_id::create("brd");
    start_item(item);
    if (!item.randomize() with {
          htrans==2'b10; hburst==local::burst_type; hsize==3'b010; hwrite==1'b0;
          if(local::use_fixed) addr==local::base_addr;
        }) `uvm_fatal("SEQ","BRD rand fail")
    finish_item(item);
  endtask
endclass

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

class ahb_driver extends uvm_driver #(ahb_seq_item);
  `uvm_component_utils(ahb_driver)
  virtual ahb_if.DRIVER_MP vif;

  function new(string name="ahb_driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual ahb_if.DRIVER_MP)::get(this,"","vif",vif))
      `uvm_fatal("DRV","No vif")
  endfunction

  task run_phase(uvm_phase phase);
    ahb_seq_item req;
    set_idle();
    @(posedge vif.HCLK iff vif.HRESETn===1'b1);
    `uvm_info("DRV","Reset released",UVM_LOW)
    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_transfer(ahb_seq_item req);
    int addr_inc;
    logic [31:0] beat_addr;

    case(req.hsize)
      3'b000: addr_inc=1; 3'b001: addr_inc=2; default: addr_inc=4;
    endcase
    beat_addr = req.addr;

    @(posedge vif.HCLK);
    vif.drv_cb.HSEL   <= 1'b1;     vif.drv_cb.HADDR  <= beat_addr;
    vif.drv_cb.HWRITE <= req.hwrite; vif.drv_cb.HSIZE  <= req.hsize;
    vif.drv_cb.HBURST <= req.hburst; vif.drv_cb.HPROT  <= req.hprot;
    vif.drv_cb.HMASTLOCK <= 1'b0;  vif.drv_cb.HTRANS <= 2'b10;

    for (int beat = 0; beat < req.num_beats; beat++) begin
      beat_addr = beat_addr + addr_inc;
      @(posedge vif.HCLK);
      if (req.hwrite)
        vif.drv_cb.HWDATA <= req.write_data + (beat * 32'h100);
      if (beat < req.num_beats - 1) begin
        vif.drv_cb.HSEL   <= 1'b1;  vif.drv_cb.HADDR  <= beat_addr;
        vif.drv_cb.HWRITE <= req.hwrite; vif.drv_cb.HSIZE  <= req.hsize;
        vif.drv_cb.HBURST <= req.hburst; vif.drv_cb.HTRANS <= 2'b11;
      end else begin
        vif.drv_cb.HTRANS <= 2'b00; vif.drv_cb.HSEL <= 1'b0;
        vif.drv_cb.HADDR  <= 32'h0; vif.drv_cb.HWRITE <= 1'b0;
      end
    end

    // Note: the driver does NOT sample read data. Read data is captured by the
    // MONITOR (on the clocking block edge) and checked by the SCOREBOARD, which
    // is the single source of truth. The driver only drives the bus, so no
    // fragile @(posedge) cycle-counting for read data is needed here.
  endtask

  task set_idle();
    vif.drv_cb.HTRANS<=2'b00; vif.drv_cb.HSEL<=1'b0; vif.drv_cb.HADDR<=32'h0;
    vif.drv_cb.HWRITE<=1'b0; vif.drv_cb.HWDATA<=32'h0; vif.drv_cb.HSIZE<=3'b010;
    vif.drv_cb.HBURST<=3'b000; vif.drv_cb.HPROT<=4'b0011; vif.drv_cb.HMASTLOCK<=1'b0;
  endtask
endclass

class ahb_monitor extends uvm_monitor;
  `uvm_component_utils(ahb_monitor)
  uvm_analysis_port #(ahb_seq_item) ap;
  virtual ahb_if.MONITOR_MP vif;

  function new(string name="ahb_monitor", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if(!uvm_config_db#(virtual ahb_if.MONITOR_MP)::get(this,"","vif",vif))
      `uvm_fatal("MON","No vif")
  endfunction

  task run_phase(uvm_phase phase);
    ahb_seq_item trans;
    @(posedge vif.HCLK iff vif.HRESETn===1'b1);
    `uvm_info("MON","Monitor active",UVM_LOW)
    forever begin
      collect_transaction(trans);
      ap.write(trans);
    end
  endtask

  task collect_transaction(output ahb_seq_item trans);
    logic        cap_write;
    logic [31:0] cur_addr;
    int          beat;

    trans = ahb_seq_item::type_id::create("mon_tx");

    // Wait for the address phase of the first beat (NONSEQ) of a new transfer.
    // All sampling goes through the mon_cb clocking block (input #1step), so
    // we read the stable pre-edge value and there is no race with the driver
    // or the DUT updating the same signals at the posedge.
    forever begin
      @(posedge vif.HCLK);
      if(vif.mon_cb.HSEL===1'b1 && vif.mon_cb.HTRANS===2'b10 && vif.mon_cb.HREADY===1'b1) break;
    end

    trans.addr   = vif.mon_cb.HADDR;   // address of beat 0
    trans.hwrite = vif.mon_cb.HWRITE;
    trans.hsize  = vif.mon_cb.HSIZE;
    trans.hburst = vif.mon_cb.HBURST;
    trans.hprot  = vif.mon_cb.HPROT;
    trans.htrans = 2'b10;
    cap_write    = vif.mon_cb.HWRITE;

    beat     = 0;
    cur_addr = trans.addr;

    // Advance one cycle into beat 0's data phase, then dispatch on direction.
    // The DUT presents both write data (HWDATA) and read data (HRDATA,
    // combinational) during the data phase, so one edge per beat is sufficient
    // in either direction; the pipelined next-beat address is carried on HADDR
    // with HTRANS==SEQ.
    @(posedge vif.HCLK);

    if (cap_write) begin
      while (1) begin
        trans.beat_wdata_q.push_back(vif.mon_cb.HWDATA); // beat i write data
        trans.beat_addr_q.push_back(cur_addr);           // beat i address
        trans.hresp = vif.mon_cb.HRESP;
        beat++; trans.n_captured = beat;
        if (vif.mon_cb.HTRANS !== 2'b11) break;          // SEQ gone => burst ended
        cur_addr = vif.mon_cb.HADDR;                     // next beat's address
        @(posedge vif.HCLK);
      end
      if (beat > 0) trans.write_data = trans.beat_wdata_q[0];
    end else begin
      // READ. The clocking block (mon_cb, input #1step) removes the race around
      // the edge, and the DUT now drives HRDATA combinationally in the data
      // phase (proper AHB pipelining). So at the edge one past the address
      // phase, HRDATA already holds beat i's data, while HADDR has pipelined
      // ahead to beat i+1's address. We sample the data and, when the next beat
      // exists (HTRANS==SEQ), grab its address for the next iteration -- keeping
      // each data value aligned with its own address.
      while (1) begin
        trans.beat_rdata_q.push_back(vif.mon_cb.HRDATA);   // beat i read data
        trans.beat_addr_q.push_back(cur_addr);             // beat i address
        trans.hresp = vif.mon_cb.HRESP;
        beat++; trans.n_captured = beat;
        if (vif.mon_cb.HTRANS !== 2'b11) break;            // SEQ gone => burst ended
        cur_addr = vif.mon_cb.HADDR;                       // next beat's address
        @(posedge vif.HCLK);                               // advance to next data edge
      end
      if (beat > 0) trans.read_data = trans.beat_rdata_q[beat-1];
    end

    trans.num_beats = beat;
  endtask
endclass

// AHB Sequencer - uses standard UVM sequencer parameterized with ahb_seq_item
typedef uvm_sequencer #(ahb_seq_item) ahb_sequencer;

class ahb_agent extends uvm_agent;
  `uvm_component_utils(ahb_agent)
  ahb_driver drv; ahb_monitor mon;
  uvm_sequencer #(ahb_seq_item) seqr;
  uvm_analysis_port #(ahb_seq_item) ap;

  function new(string name="ahb_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon=ahb_monitor::type_id::create("mon",this);
    if(get_is_active()==UVM_ACTIVE) begin
      drv=ahb_driver::type_id::create("drv",this);
      seqr=uvm_sequencer#(ahb_seq_item)::type_id::create("seqr",this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    ap=mon.ap;
    if(get_is_active()==UVM_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass

class ahb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ahb_scoreboard)
  uvm_analysis_imp #(ahb_seq_item, ahb_scoreboard) analysis_export;
  logic [31:0] ref_mem [logic [31:0]];
  int unsigned total_wr, total_rd, total_pass, total_fail, total_err;

  function new(string name="ahb_scoreboard", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(ahb_seq_item t);
    int i;
    logic [31:0] wa;
    if(t.hresp!=2'b00) begin
      total_err++;
      `uvm_error("SB",$sformatf("BUS ERR A=0x%08h",t.addr))
      return;
    end
    if(t.hwrite) begin
      // Store EVERY beat's write data at its OWN address.
      for(i=0; i<t.n_captured; i++) begin
        wa = {t.beat_addr_q[i][31:2], 2'b00};
        ref_mem[wa] = t.beat_wdata_q[i];
        total_wr++;
      end
    end else begin
      // Compare EVERY beat's read data against its OWN address.
      for(i=0; i<t.n_captured; i++) begin
        wa = {t.beat_addr_q[i][31:2], 2'b00};
        total_rd++;
        if(!ref_mem.exists(wa)) begin
          `uvm_warning("SB",$sformatf("RD uninit [0x%08h]",wa))
          continue;
        end
        if(t.beat_rdata_q[i]===ref_mem[wa]) begin
          total_pass++;
          `uvm_info("SB",$sformatf("PASS [0x%08h] exp=0x%08h",wa,ref_mem[wa]),UVM_MEDIUM)
        end else begin
          total_fail++;
          `uvm_error("SB",$sformatf("FAIL [0x%08h] exp=0x%08h got=0x%08h",
            wa,ref_mem[wa],t.beat_rdata_q[i]))
        end
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    `uvm_info("SB","",UVM_NONE)
    `uvm_info("SB","======================================",UVM_NONE)
    `uvm_info("SB","      SCOREBOARD FINAL SUMMARY",UVM_NONE)
    `uvm_info("SB","======================================",UVM_NONE)
    `uvm_info("SB",$sformatf("  Writes : %0d",total_wr),  UVM_NONE)
    `uvm_info("SB",$sformatf("  Reads  : %0d",total_rd),  UVM_NONE)
    `uvm_info("SB",$sformatf("  PASS   : %0d",total_pass),UVM_NONE)
    `uvm_info("SB",$sformatf("  FAIL   : %0d",total_fail),UVM_NONE)
    `uvm_info("SB",$sformatf("  Errors : %0d",total_err), UVM_NONE)
    `uvm_info("SB","======================================",UVM_NONE)
    if(total_fail==0 && total_err==0)
      `uvm_info("SB","     *** TEST PASSED ***",UVM_NONE)
    else
      `uvm_error("SB",$sformatf("*** TEST FAILED *** %0d fails, %0d errors",
        total_fail, total_err))
    `uvm_info("SB","======================================",UVM_NONE)
  endfunction
endclass

class ahb_env extends uvm_env;
  `uvm_component_utils(ahb_env)
  ahb_agent      agt;
  ahb_scoreboard sb;
  ahb_coverage   cov;

  function new(string name="ahb_env", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = ahb_agent::type_id::create("agt",this);
    sb  = ahb_scoreboard::type_id::create("sb",this);
    cov = ahb_coverage::type_id::create("cov",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agt.ap.connect(sb.analysis_export);
    agt.ap.connect(cov.analysis_export);
  endfunction
endclass

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

endpackage : ahb_uvm_pkg

// ---- top ----
module ahb_tb_top;
  import uvm_pkg::*;
  import ahb_uvm_pkg::*;

  logic HCLK, HRESETn;
  initial HCLK=0;
  always #5 HCLK=~HCLK;

  initial begin
    HRESETn=0;
    repeat(6) @(posedge HCLK);
    #1; HRESETn=1;
    $display("[TOP] %0t: HRESETn deasserted",$realtime);
  end

  ahb_if #(.ADDR_WIDTH(32),.DATA_WIDTH(32)) dut_if (.HCLK(HCLK),.HRESETn(HRESETn));

  ahb_slave_mem #(.MEM_DEPTH(256),.ADDR_WIDTH(32),.DATA_WIDTH(32)) dut (
    .HCLK(HCLK),.HRESETn(HRESETn),
    .HSEL(dut_if.HSEL),.HADDR(dut_if.HADDR),.HWRITE(dut_if.HWRITE),
    .HTRANS(dut_if.HTRANS),.HSIZE(dut_if.HSIZE),.HBURST(dut_if.HBURST),
    .HPROT(dut_if.HPROT),.HMASTLOCK(dut_if.HMASTLOCK),.HREADY(dut_if.HREADY),
    .HWDATA(dut_if.HWDATA),.HRDATA(dut_if.HRDATA),
    .HREADYOUT(dut_if.HREADYOUT),.HRESP(dut_if.HRESP)
  );

  assign dut_if.HREADY = dut_if.HREADYOUT;

  initial begin
    uvm_config_db#(virtual ahb_if.DRIVER_MP)::set(
      null,"uvm_test_top.env.agt.drv","vif",dut_if);
    uvm_config_db#(virtual ahb_if.MONITOR_MP)::set(
      null,"uvm_test_top.env.agt.mon","vif",dut_if);
  end

  initial begin $dumpfile("dump.vcd"); $dumpvars(0); end
  initial begin #200_000; $display("[TOP] TIMEOUT"); $finish; end
  initial run_test();

endmodule : ahb_tb_top
