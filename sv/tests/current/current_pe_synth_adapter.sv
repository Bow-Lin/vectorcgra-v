// Unpacked SV ports to the fixed-profile synthesized Verilog netlist.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module current_pe_synth_adapter #(
  `CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS, parameter int VARIANT=0
) (  input  logic [CGRA_ID_W-1:0] cgra_id ,
  input  logic [0:0] clk ,
  input  logic [0:0] reset ,
  input  logic [TILE_ID_W-1:0] tile_id ,
  input logic [DATA_BITS-1:0] from_mem_rdata__msg ,
  output logic [0:0] from_mem_rdata__rdy  ,
  input logic [0:0] from_mem_rdata__val  ,
  input logic [DATA_BITS-1:0] recv_data__msg [0:TILE_PORTS-1] ,
  output logic [0:0] recv_data__rdy [0:TILE_PORTS-1] ,
  input logic [0:0] recv_data__val [0:TILE_PORTS-1] ,
  input logic [HOST_BITS-1:0] recv_from_controller_pkt__msg ,
  output logic [0:0] recv_from_controller_pkt__rdy  ,
  input logic [0:0] recv_from_controller_pkt__val  ,
  output logic [DATA_BITS-1:0] send_data__msg [0:TILE_PORTS-1] ,
  input logic [0:0] send_data__rdy [0:TILE_PORTS-1] ,
  output logic [0:0] send_data__val [0:TILE_PORTS-1] ,
  output logic [HOST_BITS-1:0] send_to_controller_pkt__msg ,
  input logic [0:0] send_to_controller_pkt__rdy  ,
  output logic [0:0] send_to_controller_pkt__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_raddr__msg  ,
  input logic [0:0] to_mem_raddr__rdy  ,
  output logic [0:0] to_mem_raddr__val  ,
  output logic [GLOBAL_ADDR_W-1:0] to_mem_waddr__msg  ,
  input logic [0:0] to_mem_waddr__rdy  ,
  output logic [0:0] to_mem_waddr__val  ,
  output logic [DATA_BITS-1:0] to_mem_wdata__msg ,
  input logic [0:0] to_mem_wdata__rdy  ,
  output logic [0:0] to_mem_wdata__val
);
  logic [TILE_PORTS*DATA_BITS-1:0] recv_msg_flat, send_msg_flat;
  logic [TILE_PORTS-1:0] recv_val_flat, recv_rdy_flat, send_val_flat, send_rdy_flat;
  for(genvar i=0;i<TILE_PORTS;i++) begin : flatten_ports
    assign recv_msg_flat[(TILE_PORTS-1-i)*DATA_BITS+:DATA_BITS]=recv_data__msg[i];
    assign recv_val_flat[TILE_PORTS-1-i]=recv_data__val[i];
    assign recv_data__rdy[i]=recv_rdy_flat[TILE_PORTS-1-i];
    assign send_data__msg[i]=send_msg_flat[(TILE_PORTS-1-i)*DATA_BITS+:DATA_BITS];
    assign send_data__val[i]=send_val_flat[TILE_PORTS-1-i];
    assign send_rdy_flat[TILE_PORTS-1-i]=send_data__rdy[i];
  end
  cgra_pe_netlist dut(
    .cgra_id(cgra_id),
    .clk(clk),
    .reset(reset),
    .tile_id(tile_id),
    .from_mem_rdata__msg(from_mem_rdata__msg),
    .from_mem_rdata__rdy(from_mem_rdata__rdy),
    .from_mem_rdata__val(from_mem_rdata__val),
    .recv_data__msg(recv_msg_flat),
    .recv_data__rdy(recv_rdy_flat),
    .recv_data__val(recv_val_flat),
    .recv_from_controller_pkt__msg(recv_from_controller_pkt__msg),
    .recv_from_controller_pkt__rdy(recv_from_controller_pkt__rdy),
    .recv_from_controller_pkt__val(recv_from_controller_pkt__val),
    .send_data__msg(send_msg_flat),
    .send_data__rdy(send_rdy_flat),
    .send_data__val(send_val_flat),
    .send_to_controller_pkt__msg(send_to_controller_pkt__msg),
    .send_to_controller_pkt__rdy(send_to_controller_pkt__rdy),
    .send_to_controller_pkt__val(send_to_controller_pkt__val),
    .to_mem_raddr__msg(to_mem_raddr__msg),
    .to_mem_raddr__rdy(to_mem_raddr__rdy),
    .to_mem_raddr__val(to_mem_raddr__val),
    .to_mem_waddr__msg(to_mem_waddr__msg),
    .to_mem_waddr__rdy(to_mem_waddr__rdy),
    .to_mem_waddr__val(to_mem_waddr__val),
    .to_mem_wdata__msg(to_mem_wdata__msg),
    .to_mem_wdata__rdy(to_mem_wdata__rdy),
    .to_mem_wdata__val(to_mem_wdata__val)
  );
endmodule
