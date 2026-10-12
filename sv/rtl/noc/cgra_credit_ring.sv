// Parameterized control ring with native stable arbitration and VC0 injection.
// Explicit legacy mode preserves ac96 PyOCN adapters. The supported profile
// has two VCs/two credits; ac96 does not consistently propagate other values.
module cgra_credit_ring #(
  parameter int WIDTH = 191,
  parameter int NODES = 5,
  parameter int DST_LSB = 185,
  parameter int DST_WIDTH = $clog2(NODES),
  parameter int VC_LSB = 170,
  parameter int VC_WIDTH = 1,
  parameter int VCS = 2,
  parameter int CREDITS = 2,
  parameter bit LEGACY_PYTHON=0
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg [0:NODES-1],
  input logic recv_val [0:NODES-1],
  output logic recv_rdy [0:NODES-1],
  output logic [WIDTH-1:0] send_msg [0:NODES-1],
  output logic send_val [0:NODES-1],
  input logic send_rdy [0:NODES-1]
);
  localparam int POS_WIDTH = $clog2(NODES);
  // Dateline routing requires every new route to start in physical VC0. Save
  // the public incoming VC tag outside the packet so the external ABI is intact.
  localparam int LINK_WIDTH=WIDTH+(LEGACY_PYTHON ? 0 : 1);
  logic [LINK_WIDTH-1:0] router_recv_msg [0:NODES-1][0:2];
  logic router_recv_en [0:NODES-1][0:2];
  logic [VCS-1:0] router_recv_credit [0:NODES-1][0:2];
  logic [LINK_WIDTH-1:0] router_send_msg [0:NODES-1][0:2];
  logic router_send_en [0:NODES-1][0:2];
  logic [VCS-1:0] router_send_credit [0:NODES-1][0:2];
  initial begin
    // Plain elaboration-time guards remain active in simulators even when
    // optional SystemVerilog assertion execution is disabled.
    if (VCS != 2 || CREDITS != 2)
      $fatal(1, "ac96 ring profile requires VCS=2 and CREDITS=2");
    if (NODES < 2) $fatal(1, "Ring requires at least two nodes");
  end
  for (genvar n = 0; n < NODES; n++) begin : nodes
    localparam int NEXT = (n+1) % NODES;
    logic [LINK_WIDTH-1:0] inject_msg,eject_msg;
    logic inject_val,legal_vc;
    assign legal_vc=(recv_msg[n][VC_LSB+:VC_WIDTH]==VC_WIDTH'(0)) ||
                   (recv_msg[n][VC_LSB+:VC_WIDTH]==VC_WIDTH'(1));
    assign inject_val=recv_val[n] && (LEGACY_PYTHON || legal_vc);
    if(LEGACY_PYTHON) begin : legacy_packet
      assign inject_msg=recv_msg[n];
      assign send_msg[n]=eject_msg;
    end else begin : native_packet
      always_comb begin
        inject_msg='0;
        inject_msg[WIDTH-1:0]=recv_msg[n];
        inject_msg[LINK_WIDTH-1]=(recv_msg[n][VC_LSB+:VC_WIDTH]==VC_WIDTH'(1));
        inject_msg[VC_LSB+:VC_WIDTH]='0;
        send_msg[n]=eject_msg[WIDTH-1:0];
        if(eject_msg[LINK_WIDTH-1]) send_msg[n][VC_LSB+:VC_WIDTH]=VC_WIDTH'(1);
      end
    end
    cgra_ring_router #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(LINK_WIDTH), .NODES(NODES), .DST_LSB(DST_LSB), .DST_WIDTH(DST_WIDTH),
                       .VC_LSB(VC_LSB), .VC_WIDTH(VC_WIDTH), .VCS(VCS), .CREDITS(CREDITS)) router (
      .clk, .reset, .pos(POS_WIDTH'(n)),
      .recv_msg(router_recv_msg[n]), .recv_en(router_recv_en[n]), .recv_credit(router_recv_credit[n]),
      .send_msg(router_send_msg[n]), .send_en(router_send_en[n]), .send_credit(router_send_credit[n])
    );
    assign router_recv_msg[NEXT][0] = router_send_msg[n][1];
    assign router_recv_en[NEXT][0] = router_send_en[n][1];
    assign router_send_credit[n][1] = router_recv_credit[NEXT][0];
    assign router_recv_msg[n][1] = router_send_msg[NEXT][0];
    assign router_recv_en[n][1] = router_send_en[NEXT][0];
    assign router_send_credit[NEXT][0] = router_recv_credit[n][1];
    cgra_credit_send #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(LINK_WIDTH), .VCS(VCS), .CREDITS(CREDITS),
                       .VC_LSB(VC_LSB), .VC_WIDTH(VC_WIDTH)) inject (
      .clk, .reset, .recv_msg(inject_msg), .recv_val(inject_val), .recv_rdy(recv_rdy[n]),
      .send_msg(router_recv_msg[n][2]), .send_en(router_recv_en[n][2]), .send_credit(router_recv_credit[n][2]), .available_credit()
    );
    cgra_credit_recv #(.LEGACY_PYTHON(LEGACY_PYTHON),.WIDTH(LINK_WIDTH), .VCS(VCS), .CREDITS(CREDITS),
                       .VC_LSB(VC_LSB), .VC_WIDTH(VC_WIDTH)) eject (
      .clk, .reset, .recv_msg(router_send_msg[n][2]), .recv_en(router_send_en[n][2]),
      .recv_credit(router_send_credit[n][2]), .send_msg(eject_msg), .send_val(send_val[n]), .send_rdy(send_rdy[n])
    );
  end
endmodule
