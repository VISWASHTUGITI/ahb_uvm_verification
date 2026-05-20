`include "uvm_macros.svh"

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
