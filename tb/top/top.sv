`include "uvm_macros.svh"

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
