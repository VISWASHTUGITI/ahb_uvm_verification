`include "uvm_macros.svh"

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
