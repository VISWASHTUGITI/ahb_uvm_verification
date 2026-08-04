`include "uvm_macros.svh"

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
