// Configurable single PE. VARIANT: 0=base, 1=context switch, 2=streaming.
`include "cgra_profile_defs.svh"
`include "cgra_fu_catalog.svh"
module cgra_pe #(
  `CGRA_PROFILE_PARAMETERS,
  `CGRA_FU_PARAMETERS,
  parameter int VARIANT = 0
) (
  input  logic [CGRA_ID_W-1:0] cgra_id ,
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
  initial begin
    if (VARIANT < 0 || VARIANT > 2) $fatal(1,"cgra_pe VARIANT must be 0, 1 or 2");
    if (CTRL_DEPTH < 2 || REG_DEPTH < 2 || NUM_CTRL < 1 || NUM_CTRL > CTRL_DEPTH)
      $fatal(1,"cgra_pe requires storage depths >=2 and 1 <= NUM_CTRL <= CTRL_DEPTH");
    if (TILE_PORTS != 4 && TILE_PORTS != 8) $fatal(1,"cgra_pe requires 4 or 8 ports");
    if (VARIANT == 2 && TILE_PORTS != 8) $fatal(1,"streaming PE requires 8 ports");
  end
  if (VARIANT == 0) begin : base
    tile_programmable #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) core (.*);
  end else if (VARIANT == 1) begin : context_switch
    tile_context #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) core (.*);
  end else begin : streaming
    tile_streaming #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) core (.*);
  end
endmodule
