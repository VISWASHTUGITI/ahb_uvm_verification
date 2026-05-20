`include "uvm_macros.svh"

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
    logic [2:0]  cap_size, cap_burst;
    logic [31:0] cap_addr;
    logic [3:0]  cap_prot;
    int          nbeats;

    trans = ahb_seq_item::type_id::create("mon_tx");

    forever begin
      @(posedge vif.HCLK);
      if(vif.HSEL===1'b1 && vif.HTRANS===2'b10 && vif.HREADY===1'b1) break;
    end

    cap_addr=vif.HADDR; cap_write=vif.HWRITE;
    cap_size=vif.HSIZE; cap_burst=vif.HBURST; cap_prot=vif.HPROT;

    trans.addr=cap_addr; trans.hwrite=cap_write;
    trans.hsize=cap_size; trans.hburst=cap_burst;
    trans.hprot=cap_prot; trans.htrans=2'b10;

    case(cap_burst)
      3'b000:nbeats=1; 3'b001:nbeats=1; 3'b011:nbeats=4;
      3'b101:nbeats=8; default:nbeats=1;
    endcase
    trans.num_beats = nbeats;

    for (int beat = 0; beat < nbeats; beat++) begin
      @(posedge vif.HCLK);
      if (cap_write) begin
        @(posedge vif.HCLK);
        trans.write_data = vif.HWDATA;
        trans.hresp = vif.HRESP;
      end else begin
        @(posedge vif.HCLK);
        @(posedge vif.HCLK);
        trans.read_data = vif.HRDATA;
        trans.hresp = vif.HRESP;
      end
    end
  endtask
endclass
