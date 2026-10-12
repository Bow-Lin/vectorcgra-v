`timescale 1ns/1ps
module tb_data_mem_invalid #(parameter integer BAD_CASE=0);
  cgra_data_mem #(.DEPTH((BAD_CASE==0)?1:3),.LEGACY_PYTHON(BAD_CASE==0),
    .ADDR_W((BAD_CASE==0)?1:4)) dut ();
  initial begin #2;$fatal(1,"DATA_MEM_INVALID_NOT_REJECTED");end
endmodule
