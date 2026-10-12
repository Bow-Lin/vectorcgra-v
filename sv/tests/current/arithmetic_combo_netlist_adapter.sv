// Adapter only: sv2v flattens ascending unpacked arrays with port 0 at the high end.
`include "cgra_opcodes.svh"
`include "cgra_profile_defs.svh"
// Unpacked public FU ports connected to a checked, flattened current netlist.
module `ARITHMETIC_COMBO_MODULE #(
  `CGRA_PROFILE_PARAMETERS
) (
  input  logic [0:0] clear ,
  input  logic [0:0] clk ,
  input  logic [CTRL_ADDR_W-1:0] ctrl_addr_inport ,
  input  logic [0:0] reset ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg  ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
  input logic [DATA_BITS-1:0] recv_const__msg  ,
  output logic [0:0] recv_const__rdy  ,
  input logic [0:0] recv_const__val  ,
  input logic [PAYLOAD_BITS-1:0] recv_from_ctrl_mem__msg  ,
  output logic [0:0] recv_from_ctrl_mem__rdy  ,
  input logic [0:0] recv_from_ctrl_mem__val  ,
  input logic [DATA_BITS-1:0] recv_in__msg [0:3] ,
  output logic [0:0] recv_in__rdy [0:3] ,
  input logic [0:0] recv_in__val [0:3] ,
  input logic [CTRL_BITS-1:0] recv_opt__msg  ,
  output logic [0:0] recv_opt__rdy  ,
  input logic [0:0] recv_opt__val  ,
  output logic [DATA_BITS-1:0] send_out__msg [0:1] ,
  input logic [0:0] send_out__rdy [0:1] ,
  output logic [0:0] send_out__val [0:1] ,
  output logic [PAYLOAD_BITS-1:0] send_to_ctrl_mem__msg  ,
  input logic [0:0] send_to_ctrl_mem__rdy  ,
  output logic [0:0] send_to_ctrl_mem__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg  ,
  input logic [0:0] to_mem_raddr__rdy  ,
  output logic [0:0] to_mem_raddr__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg  ,
  input logic [0:0] to_mem_waddr__rdy  ,
  output logic [0:0] to_mem_waddr__val  ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg  ,
  input logic [0:0] to_mem_wdata__rdy  ,
  output logic [0:0] to_mem_wdata__val  
);
  wire [4*DATA_BITS-1:0] flat_inputs;
  wire [3:0] flat_valid,flat_ready;
  wire [2*DATA_BITS-1:0] flat_outputs;
  wire [1:0] flat_out_valid,flat_out_ready;
  for (genvar i=0;i<4;i++) begin : flat_in
    assign flat_inputs[(3-i)*DATA_BITS +: DATA_BITS]=recv_in__msg[i];
    assign flat_valid[3-i]=recv_in__val[i];
    assign recv_in__rdy[i]=flat_ready[3-i];
  end
  for (genvar i=0;i<2;i++) begin : flat_out
    assign send_out__msg[i]=flat_outputs[(1-i)*DATA_BITS +: DATA_BITS];
    assign send_out__val[i]=flat_out_valid[1-i];
    assign flat_out_ready[1-i]=send_out__rdy[i];
  end
  arithmetic_combo_netlist dut (.recv_in__msg(flat_inputs),.recv_in__val(flat_valid),.recv_in__rdy(flat_ready),
    .send_out__msg(flat_outputs),.send_out__val(flat_out_valid),.send_out__rdy(flat_out_ready),.*);
endmodule
