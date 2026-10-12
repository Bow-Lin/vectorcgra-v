// Stable native arbitration; explicit compatibility with PyOCN stalled rotation.
// Legacy no-grant selection remains input zero, including its invalid message.
module cgra_switch #(
  parameter int WIDTH = 32,
  parameter int INPUTS = 2,
  parameter int SELECT_WIDTH = (INPUTS <= 1) ? 1 : $clog2(INPUTS),
  parameter bit LEGACY_PYTHON = 0
) (
  input logic clk, reset,
  input logic [WIDTH-1:0] recv_msg [0:INPUTS-1],
  input logic recv_val [0:INPUTS-1],
  output logic recv_rdy [0:INPUTS-1],
  output logic [WIDTH-1:0] send_msg,
  output logic send_val,
  input logic send_rdy
);
  initial if(WIDTH<1 || INPUTS<1 || SELECT_WIDTH<(INPUTS<=1 ? 1 : $clog2(INPUTS)))
    $fatal(1,"NOC_SWITCH_PARAMETERS");
  if(LEGACY_PYTHON) begin : legacy
  if (INPUTS == 1) begin : null_switch
    assign send_msg = recv_msg[0];
    assign send_val = recv_val[0];
    assign recv_rdy[0] = send_rdy;
  end else begin : arbitrated
    logic [INPUTS-1:0] requests, grants;
    logic [SELECT_WIDTH-1:0] selected;
    for (genvar i = 0; i < INPUTS; i++) assign requests[i] = recv_val[i];
    cgra_round_robin #(.INPUTS(INPUTS)) arbiter (.clk, .reset, .en(1'b1), .reqs(requests), .grants);
    always_comb begin
      selected = '0;
      for (int i = 0; i < INPUTS; i++)
        if (grants[i]) selected = SELECT_WIDTH'(i);
    end
    // Keep each data slice static when sv2v flattens the unpacked port array.
    // selected is always an encoded grant or zero when there are no grants.
    always_comb begin
      send_msg = recv_msg[0];
      for (int i = 1; i < INPUTS; i++)
        if (selected == SELECT_WIDTH'(i)) send_msg = recv_msg[i];
    end
    assign send_val = grants != 0;
    for (genvar i = 0; i < INPUTS; i++)
      assign recv_rdy[i] = send_rdy & (selected == SELECT_WIDTH'(i));
  end
  end else begin : native_switch
    logic locked;
    logic [SELECT_WIDTH-1:0] selected, held_selection;
    logic [INPUTS-1:0] requests, grants;
    for(genvar i=0;i<INPUTS;i++) begin : ports
      assign requests[i]=!reset && recv_val[i] && (!locked || held_selection==SELECT_WIDTH'(i));
      assign recv_rdy[i]=!reset && send_rdy && grants[i];
    end
    cgra_round_robin #(.INPUTS(INPUTS)) arbiter (
      .clk,.reset,.en(send_val && send_rdy),.reqs(requests),.grants);
    always_comb begin
      selected='0;
      send_msg='0;
      for(int i=0;i<INPUTS;i++) if(grants[i]) begin
        selected=SELECT_WIDTH'(i);
        send_msg=recv_msg[i];
      end
    end
    assign send_val=!reset && (grants!='0);
    // A fixed priority alone does not hold selection when a new request arrives.
    // Producers must retain their valid/message until accepted, as on any val/rdy link.
    always_ff @(posedge clk) begin
      if(reset) begin locked<=0;held_selection<='0;end
      else if(locked) begin
        if(send_val && send_rdy) locked<=0;
      end else if(send_val && !send_rdy) begin
        locked<=1;held_selection<=selected;
      end
    end
  end
endmodule
