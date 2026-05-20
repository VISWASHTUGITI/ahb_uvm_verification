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
    vif.HSEL   <= 1'b1;     vif.HADDR  <= beat_addr;
    vif.HWRITE <= req.hwrite; vif.HSIZE  <= req.hsize;
    vif.HBURST <= req.hburst; vif.HPROT  <= req.hprot;
    vif.HMASTLOCK <= 1'b0;   vif.HTRANS <= 2'b10;

    for (int beat = 0; beat < req.num_beats; beat++) begin
      beat_addr = beat_addr + addr_inc;
      @(posedge vif.HCLK);
      if (req.hwrite)
        vif.HWDATA <= req.write_data + (beat * 32'h100);
      if (beat < req.num_beats - 1) begin
        vif.HSEL   <= 1'b1;     vif.HADDR  <= beat_addr;
        vif.HWRITE <= req.hwrite; vif.HSIZE  <= req.hsize;
        vif.HBURST <= req.hburst; vif.HTRANS <= 2'b11;
      end else begin
        vif.HTRANS <= 2'b00; vif.HSEL <= 1'b0;
        vif.HADDR  <= 32'h0; vif.HWRITE <= 1'b0;
      end
    end

    if (!req.hwrite) begin
      @(posedge vif.HCLK);
      @(posedge vif.HCLK);
      req.read_data = vif.HRDATA;
      req.hresp     = vif.HRESP;
    end else begin
      @(posedge vif.HCLK);
    end
  endtask

  task set_idle();
    vif.HTRANS<=2'b00; vif.HSEL<=1'b0; vif.HADDR<=32'h0;
    vif.HWRITE<=1'b0; vif.HWDATA<=32'h0; vif.HSIZE<=3'b010;
    vif.HBURST<=3'b000; vif.HPROT<=4'b0011; vif.HMASTLOCK<=1'b0;
  endtask
endclass
