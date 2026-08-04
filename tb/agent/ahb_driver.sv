`include "uvm_macros.svh"

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
