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
