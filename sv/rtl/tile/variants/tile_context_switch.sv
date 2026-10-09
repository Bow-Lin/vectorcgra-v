// ac96 ContextSwitchRTL. Only the two queues reset; the saved progress,
// status and PHI address intentionally have no reset/clear branch.
`include "cgra_profile_defs.svh"
module tile_context_switch #(`CGRA_PROFILE_PARAMETERS) (
  input logic clk, reset,
  input logic [5:0] recv_cmd,
  input logic recv_cmd_vld,
  input logic [CTRL_ADDR_W-1:0] phi_addr,
  input logic [6:0] recv_opt,
  input logic [DATA_BITS-1:0] progress_in,
  input logic progress_in_val,
  input logic [CTRL_ADDR_W-1:0] ctrl_mem_rd_addr,
  output logic [DATA_BITS-1:0] overwrite_fu_outport__msg,
  output logic overwrite_fu_outport__val,
  input logic overwrite_fu_outport__rdy
);
  `include "cgra_profile.svh"
  data_t progress_reg, progress;
  logic [1:0] status_reg;
  logic [CTRL_ADDR_W-1:0] phi_addr_reg, queued_phi;
  logic [5:0] queued_cmd;
  logic cmd_val, phi_val;
  logic progress_reg_is_null, is_pausing, is_preserving, is_resuming;
  logic is_executing_phi;
  assign progress = progress_in;
  cgra_queue #(.WIDTH(6), .DEPTH(2)) recv_cmd_queue (
    .clk(clk), .reset(reset), .clear(1'b0),
    .recv_msg(recv_cmd), .recv_val(recv_cmd_vld), .recv_rdy(),
    .send_msg(queued_cmd), .send_val(cmd_val), .send_rdy(1'b1), .count()
  );
  cgra_queue #(.WIDTH(CTRL_ADDR_W), .DEPTH(2)) recv_phi_addr_queue (
    .clk(clk), .reset(reset), .clear(1'b0),
    .recv_msg(phi_addr), .recv_val(recv_cmd_vld), .recv_rdy(),
    .send_msg(queued_phi), .send_val(phi_val), .send_rdy(1'b1), .count()
  );
  assign progress_reg_is_null = progress_reg == '0;
  assign is_pausing = status_reg == 2'd3;
  assign is_preserving = status_reg == 2'd1;
  assign is_resuming = status_reg == 2'd2;
  assign is_executing_phi = ((recv_opt == 7'd32) || (recv_opt == 7'd84)) &&
                           phi_addr_reg == ctrl_mem_rd_addr;
  always_comb begin
    overwrite_fu_outport__val = 1'b0;
    overwrite_fu_outport__msg = '0;
    if (is_pausing && is_executing_phi) begin
      overwrite_fu_outport__val = 1'b1;
    end else if (!progress_reg_is_null && is_resuming && is_executing_phi &&
                 progress.predicate && progress_in_val) begin
      overwrite_fu_outport__val = 1'b1;
      overwrite_fu_outport__msg = progress_reg;
    end
  end
  always_ff @(posedge clk) begin
    if (cmd_val && queued_cmd == 6'd1) status_reg <= 2'd3;
    else if (cmd_val && queued_cmd == 6'd22) status_reg <= 2'd1;
    else if (cmd_val && queued_cmd == 6'd15) status_reg <= 2'd2;
    // The first PAUSE capture deliberately ignores input val/predicate.
    if ((progress_reg_is_null && is_pausing && is_executing_phi) ||
        (is_preserving && is_executing_phi && progress.predicate && progress_in_val))
      progress_reg <= progress;
    else if (!progress_reg_is_null && is_resuming && is_executing_phi &&
             progress.predicate && progress_in_val) progress_reg <= '0;
    if (cmd_val && queued_cmd == 6'd16 && phi_val) phi_addr_reg <= queued_phi;
  end
  // overwrite_fu_outport__rdy is intentionally unread, as in ac96.
endmodule
