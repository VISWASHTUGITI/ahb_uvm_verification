`include "uvm_macros.svh"

class ahb_base_seq extends uvm_sequence #(ahb_seq_item);
  `uvm_object_utils(ahb_base_seq)
  function new(string name="ahb_base_seq"); super.new(name); endfunction
endclass
