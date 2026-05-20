`include "uvm_macros.svh"

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
