// Three credit ports: LEFT=0, RIGHT=1, SELF=2. Input/VC flattening
// preserves the Python priority order input_index*VCS + vc_index.
module cgra_ring_router #(
  parameter int WIDTH = 32,
  parameter int NODES = 5,
  parameter int DST_LSB = 0,
  parameter int DST_WIDTH = $clog2(NODES),
  parameter int VC_LSB = 0,
  parameter int VC_WIDTH = 1,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter int POS_WIDTH = $clog2(NODES),
  parameter bit LEGACY_PYTHON=0
) (
  input logic clk, reset,
  input logic [POS_WIDTH-1:0] pos,
  input logic [WIDTH-1:0] recv_msg [0:2],
  input logic recv_en [0:2],
  output logic [VCS-1:0] recv_credit [0:2],
  output logic [WIDTH-1:0] send_msg [0:2],
  output logic send_en [0:2],
  input logic [VCS-1:0] send_credit [0:2]
);
  localparam int ROUTES = 3*VCS;
  logic [WIDTH-1:0] queued_msg [0:ROUTES-1];
  logic queued_val [0:ROUTES-1], queued_rdy [0:ROUTES-1];
  logic [WIDTH-1:0] routed_msg [0:ROUTES-1][0:2];
  logic routed_val [0:ROUTES-1][0:2], routed_rdy [0:ROUTES-1][0:2];
  for (genvar p = 0; p < 3; p++) begin : inputs
    logic [WIDTH-1:0] messages [0:VCS-1];
    logic valid [0:VCS-1], ready [0:VCS-1];
    cgra_credit_input #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(WIDTH), .VCS(VCS), .CREDITS(CREDITS),
                        .VC_LSB(VC_LSB), .VC_WIDTH(VC_WIDTH)) input_unit (
      .clk, .reset, .recv_msg(recv_msg[p]), .recv_en(recv_en[p]), .recv_credit(recv_credit[p]),
      .send_msg(messages), .send_val(valid), .send_rdy(ready)
    );
    for (genvar v = 0; v < VCS; v++) begin : channels
      assign queued_msg[p*VCS+v] = messages[v];
      assign queued_val[p*VCS+v] = valid[v];
      assign ready[v] = queued_rdy[p*VCS+v];
    end
  end
  for (genvar r = 0; r < ROUTES; r++) begin : routes
    cgra_ring_route #(.WIDTH(WIDTH), .NODES(NODES), .DST_LSB(DST_LSB),
                      .DST_WIDTH(DST_WIDTH), .VC_LSB(VC_LSB), .VC_WIDTH(VC_WIDTH)) route_unit (
      .pos, .recv_msg(queued_msg[r]), .recv_val(queued_val[r]), .recv_rdy(queued_rdy[r]),
      .send_msg(routed_msg[r]), .send_val(routed_val[r]), .send_rdy(routed_rdy[r])
    );
  end
  for (genvar o = 0; o < 3; o++) begin : outputs
    logic [WIDTH-1:0] messages [0:ROUTES-1];
    logic valid [0:ROUTES-1], ready [0:ROUTES-1];
    logic [WIDTH-1:0] selected_msg;
    logic selected_val, selected_rdy;
    logic [VCS-1:0] available_credit;
    for (genvar r = 0; r < ROUTES; r++) begin : ports
      assign messages[r] = routed_msg[r][o];
      logic credit_eligible;
      always_comb begin
        credit_eligible=0;
        for(int v=0;v<VCS;v++)
          if(messages[r][VC_LSB+:VC_WIDTH]==VC_WIDTH'(v)) credit_eligible=available_credit[v];
      end
      // Arbitrate only candidates that can consume a registered output credit.
      // Use the routed VC (after any dateline rewrite), not the input VC.
      // Feeding selected_rdy back here would create a combinational loop.
      assign valid[r] = routed_val[r][o] && (LEGACY_PYTHON || credit_eligible);
      assign routed_rdy[r][o] = ready[r];
    end
    cgra_switch #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(WIDTH), .INPUTS(ROUTES)) switch_unit (
      .clk, .reset, .recv_msg(messages), .recv_val(valid), .recv_rdy(ready),
      .send_msg(selected_msg), .send_val(selected_val), .send_rdy(selected_rdy)
    );
    cgra_credit_send #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(WIDTH), .VCS(VCS), .CREDITS(CREDITS),
                       .VC_LSB(VC_LSB), .VC_WIDTH(VC_WIDTH)) output_unit (
      .clk, .reset, .recv_msg(selected_msg), .recv_val(selected_val), .recv_rdy(selected_rdy),
      .send_msg(send_msg[o]), .send_en(send_en[o]), .send_credit(send_credit[o]), .available_credit
    );
  end
endmodule
