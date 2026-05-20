`include "uvm_macros.svh"

class ahb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ahb_scoreboard)
  uvm_analysis_imp #(ahb_seq_item, ahb_scoreboard) analysis_export;
  logic [31:0] ref_mem [logic [31:0]];
  int unsigned total_wr, total_rd, total_pass, total_fail, total_err;

  function new(string name="ahb_scoreboard", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(ahb_seq_item t);
    logic [31:0] wa;
    if(t.hresp!=2'b00) begin
      total_err++;
      `uvm_error("SB",$sformatf("BUS ERR A=0x%08h",t.addr))
      return;
    end
    wa = {t.addr[31:2], 2'b00};
    if(t.hwrite) begin
      ref_mem[wa] = t.write_data;
      total_wr++;
    end else begin
      total_rd++;
      if(!ref_mem.exists(wa)) begin
        `uvm_warning("SB",$sformatf("RD uninit [0x%08h]",wa))
        return;
      end
      if(t.read_data===ref_mem[wa]) begin
        total_pass++;
        `uvm_info("SB",$sformatf("PASS [0x%08h] exp=0x%08h",wa,ref_mem[wa]),UVM_MEDIUM)
      end else begin
        total_fail++;
        `uvm_error("SB",$sformatf("FAIL [0x%08h] exp=0x%08h got=0x%08h",
          wa,ref_mem[wa],t.read_data))
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    `uvm_info("SB","",UVM_NONE)
    `uvm_info("SB","======================================",UVM_NONE)
    `uvm_info("SB","      SCOREBOARD FINAL SUMMARY",UVM_NONE)
    `uvm_info("SB","======================================",UVM_NONE)
    `uvm_info("SB",$sformatf("  Writes : %0d",total_wr),  UVM_NONE)
    `uvm_info("SB",$sformatf("  Reads  : %0d",total_rd),  UVM_NONE)
    `uvm_info("SB",$sformatf("  PASS   : %0d",total_pass),UVM_NONE)
    `uvm_info("SB",$sformatf("  FAIL   : %0d",total_fail),UVM_NONE)
    `uvm_info("SB",$sformatf("  Errors : %0d",total_err), UVM_NONE)
    `uvm_info("SB","======================================",UVM_NONE)
    if(total_fail==0 && total_err==0)
      `uvm_info("SB","     *** TEST PASSED ***",UVM_NONE)
    else
      `uvm_error("SB",$sformatf("*** TEST FAILED *** %0d fails, %0d errors",
        total_fail, total_err))
    `uvm_info("SB","======================================",UVM_NONE)
  endfunction
endclass
