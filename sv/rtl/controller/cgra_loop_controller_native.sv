module cgra_loop_controller_native #(
  parameter int DATA_W = 32,
  parameter int CTRL_BITS = 107,
  parameter int NUM_CCUS = 8,
  parameter int MAX_TARGETS = 4,
  parameter int DATA_ADDR_W = 3,
  parameter int CTRL_ADDR_W = 3,
  localparam int DATA_BITS = DATA_W + 3,
  localparam int PAYLOAD_BITS = 6 + DATA_BITS + DATA_ADDR_W + CTRL_BITS + CTRL_ADDR_W,
  localparam int CCU_ID_W = NUM_CCUS > 1 ? $clog2(NUM_CCUS) : 1,
  localparam int TARGET_IDX_W = MAX_TARGETS > 1 ? $clog2(MAX_TARGETS) : 1
) (
  input logic clk, reset,
  input logic [PAYLOAD_BITS-1:0] recv_config__msg,
  input logic recv_config__val,
  output logic recv_config__rdy,
  input logic [PAYLOAD_BITS-1:0] recv_from_tile__msg,
  input logic recv_from_tile__val,
  output logic recv_from_tile__rdy,
  input logic [PAYLOAD_BITS-1:0] recv_from_remote__msg,
  input logic recv_from_remote__val,
  output logic recv_from_remote__rdy,
  output logic [PAYLOAD_BITS-1:0] send_to_tile__msg,
  output logic send_to_tile__val,
  input logic send_to_tile__rdy,
  output logic [PAYLOAD_BITS-1:0] send_to_remote__msg,
  output logic send_to_remote__val,
  input logic send_to_remote__rdy,
  output logic all_loops_complete
);
  localparam logic [5:0] UPDATE_SHADOW=26, RESET_LEAF=27, LEAF_COMPLETE=31,
    CONFIG_LOWER=32, CONFIG_UPPER=33, CONFIG_STEP=34, CONFIG_CHILD_COUNT=35,
    CONFIG_TARGET=36, CONFIG_PARENT=37, LAUNCH=38, CHILD_COMPLETE=40;
  localparam logic [1:0] IDLE=0,RUNNING=1,DISPATCHING=2,COMPLETE=3;
  localparam int CREDIT_W=$clog2(NUM_CCUS+32);
  typedef struct packed {
    logic [DATA_W-1:0] payload;
    logic predicate,bypass,delay;
  } data_t;
  typedef struct packed {
    logic [5:0] cmd;
    data_t data;
    logic [DATA_ADDR_W-1:0] data_addr;
    logic [CTRL_BITS-1:0] ctrl;
    logic [CTRL_ADDR_W-1:0] ctrl_addr;
  } payload_t;
  payload_t config_msg,tile_msg,remote_msg,dispatch_msg;
  assign config_msg=recv_config__msg;
  assign tile_msg=recv_from_tile__msg;
  assign remote_msg=recv_from_remote__msg;
  logic [DATA_W-1:0] lower_bound[NUM_CCUS],upper_bound[NUM_CCUS],step[NUM_CCUS];
  data_t current_value[NUM_CCUS],next_value[NUM_CCUS];
  logic [1:0] state[NUM_CCUS],next_state[NUM_CCUS];
  logic [3:0] child_count[NUM_CCUS],num_targets[NUM_CCUS];
  logic [CREDIT_W-1:0] credits[NUM_CCUS],next_credits[NUM_CCUS];
  logic [TARGET_IDX_W-1:0] dispatch_idx[NUM_CCUS],next_index[NUM_CCUS];
  logic configured[NUM_CCUS],is_root[NUM_CCUS];
  logic [CCU_ID_W-1:0] parent_id[NUM_CCUS];
  logic [CTRL_ADDR_W-1:0] target_addr[NUM_CCUS][MAX_TARGETS];
  logic target_remote[NUM_CCUS][MAX_TARGETS],target_shadow[NUM_CCUS][MAX_TARGETS];
  logic launched,locked,root_present;
  logic [CCU_ID_W-1:0] held_ccu;
  logic has_dispatch,sent;
  integer active;
  logic [NUM_CCUS-1:0] tile_hit,remote_hit,restart_roots,restart_children,dispatch_restart;
  logic [NUM_CCUS-1:0] notify_parent,next_notify_parent;
  logic [CREDIT_W-1:0] parent_events[NUM_CCUS];
  logic [DATA_W:0] incremented[NUM_CCUS];

  initial begin
    if (NUM_CCUS<1 || NUM_CCUS>2**CTRL_ADDR_W || MAX_TARGETS<1 || MAX_TARGETS>15)
      $fatal(1,"LOOP_PARAMETERS: CCU addressability / 4-bit target count");
    if (DATA_W<4 || DATA_W<=CCU_ID_W || DATA_W<CTRL_ADDR_W || CTRL_BITS<1 || DATA_ADDR_W<1 || CTRL_ADDR_W<1)
      $fatal(1,"LOOP_PARAMETERS: payload field widths");
  end

  always_comb begin
    root_present=0;
    for (integer i=0;i<NUM_CCUS;i++) root_present |= configured[i] && is_root[i];
    all_loops_complete=launched && root_present && !reset && !(|notify_parent);
    for (integer i=0;i<NUM_CCUS;i++)
      if (configured[i] && state[i]!=COMPLETE) all_loops_complete=0;
    // Configuration is an idle/completed operation, never a live mutation.
    recv_config__rdy=!reset && (!launched || all_loops_complete);
    recv_from_tile__rdy=0;recv_from_remote__rdy=0;
    send_to_tile__val=0;send_to_remote__val=0;
    send_to_tile__msg='0;send_to_remote__msg='0;dispatch_msg='0;
    has_dispatch=0;active=0;sent=0;tile_hit='0;remote_hit='0;dispatch_restart='0;
    if (!reset && launched) begin
      if (locked) begin has_dispatch=1;active=int'(held_ccu);end
      else for (integer i=0;i<NUM_CCUS;i++)
        if (state[i]==DISPATCHING && !has_dispatch) begin has_dispatch=1;active=i;end
      if (has_dispatch) begin
        dispatch_msg.ctrl_addr=target_addr[active][dispatch_idx[active]];
        dispatch_msg.cmd=target_shadow[active][dispatch_idx[active]]?UPDATE_SHADOW:RESET_LEAF;
        if (target_shadow[active][dispatch_idx[active]]) dispatch_msg.data=current_value[active];
        if (target_remote[active][dispatch_idx[active]]) begin
          send_to_remote__val=1;send_to_remote__msg=dispatch_msg;sent=send_to_remote__rdy;
        end else begin
          send_to_tile__val=1;send_to_tile__msg=dispatch_msg;sent=send_to_tile__rdy;
        end
        if (sent && 4'(dispatch_idx[active])+4'd1>=num_targets[active]) dispatch_restart[active]=1;
      end
      // A completion offered while its subtree restarts remains at its source.
      for (integer level=0;level<NUM_CCUS;level++)
        for (integer i=0;i<NUM_CCUS;i++)
          if (configured[i] && !is_root[i] && dispatch_restart[parent_id[i]]) dispatch_restart[i]=1;
      if (recv_from_tile__val) begin
        if (tile_msg.cmd==LEAF_COMPLETE) begin
          for (integer i=0;i<NUM_CCUS;i++)
            if (configured[i] && state[i]==RUNNING && credits[i]<CREDIT_W'(child_count[i]) && !dispatch_restart[i])
              for (integer t=0;t<MAX_TARGETS;t++)
                if (t<num_targets[i] && !target_remote[i][t] && !target_shadow[i][t] && target_addr[i][t]==tile_msg.ctrl_addr)
                  tile_hit[i]=1;
          recv_from_tile__rdy=|tile_hit;
        end else recv_from_tile__rdy=1;
      end
      if (recv_from_remote__val) begin
        if (remote_msg.cmd==CHILD_COMPLETE) begin
          // Native payload contract: ctrl_addr identifies the receiving CCU.
          for (integer i=0;i<NUM_CCUS;i++)
            if (remote_msg.ctrl_addr==CTRL_ADDR_W'(i) && configured[i] && state[i]==RUNNING &&
                credits[i]<CREDIT_W'(child_count[i]) && !dispatch_restart[i]) remote_hit[i]=1;
          recv_from_remote__rdy=|remote_hit;
        end else recv_from_remote__rdy=1;
      end
    end
  end

  always_comb begin
    restart_roots='0;restart_children='0;next_notify_parent='0;
    for (integer i=0;i<NUM_CCUS;i++) begin
      next_state[i]=state[i];next_value[i]=current_value[i];next_index[i]=dispatch_idx[i];
      // Static destinations avoid a chain of variable-index array writes.
      parent_events[i]=0;
      for (integer child=0;child<NUM_CCUS;child++)
        parent_events[i]=parent_events[i]+CREDIT_W'(notify_parent[child] && parent_id[child]==CCU_ID_W'(i));
      next_credits[i]=credits[i]+CREDIT_W'(tile_hit[i])+CREDIT_W'(remote_hit[i])+parent_events[i];
      incremented[i]={1'b0,current_value[i].payload}+{1'b0,step[i]};
    end
    if (has_dispatch && sent) begin
      if (4'(dispatch_idx[active])+4'd1>=num_targets[active]) begin
        next_index[active]=0;next_state[active]=RUNNING;restart_roots[active]=1;
      end else next_index[active]=dispatch_idx[active]+TARGET_IDX_W'(1);
    end
    // A CCU advances at most once per clock. Registered one-hop notifications
    // sum sibling completions without a combinational path through the forest.
    for (integer i=0;i<NUM_CCUS;i++) begin
        if (launched && configured[i] && state[i]==RUNNING &&
            child_count[i]!=0 && next_credits[i]>=CREDIT_W'(child_count[i])) begin
          next_credits[i]=next_credits[i]-CREDIT_W'(child_count[i]);
          next_value[i]={incremented[i][DATA_W-1:0],3'b100};
          if (incremented[i]>={1'b0,upper_bound[i]}) begin
            next_state[i]=COMPLETE;
            next_notify_parent[i]=!is_root[i];
          end else if (num_targets[i]!=0) begin
            next_state[i]=DISPATCHING;next_index[i]=0;
          end else begin
            // A parent with no outgoing targets still restarts its children.
            next_state[i]=RUNNING;restart_roots[i]=1;
          end
        end
    end
    // Restart the complete configured subtree, not unconfigured default-parent
    // entries. This also permits nesting deeper than one parent notification.
    for (integer level=0;level<NUM_CCUS;level++)
      for (integer i=0;i<NUM_CCUS;i++)
        if (configured[i] && !is_root[i] && (restart_roots[parent_id[i]] || restart_children[parent_id[i]])) restart_children[i]=1;
    for (integer i=0;i<NUM_CCUS;i++) if (restart_children[i]) begin
      next_state[i]=RUNNING;next_value[i]={lower_bound[i],3'b100};next_credits[i]=0;next_index[i]=0;
      next_notify_parent[i]=0;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      launched<=0;locked<=0;held_ccu<=0;notify_parent<=0;
      for (integer i=0;i<NUM_CCUS;i++) begin
        lower_bound[i]<=0;upper_bound[i]<=0;step[i]<=0;current_value[i]<='0;
        state[i]<=IDLE;child_count[i]<=0;credits[i]<=0;num_targets[i]<=0;dispatch_idx[i]<=0;
        configured[i]<=0;is_root[i]<=0;parent_id[i]<=0;
        for (integer t=0;t<MAX_TARGETS;t++) begin target_addr[i][t]<=0;target_remote[i][t]<=0;target_shadow[i][t]<=0;end
      end
    end else begin
      notify_parent<=next_notify_parent;
      for (integer i=0;i<NUM_CCUS;i++) begin
        state[i]<=next_state[i];current_value[i]<=next_value[i];credits[i]<=next_credits[i];dispatch_idx[i]<=next_index[i];
      end
      if (has_dispatch) begin
        if (sent) locked<=0;
        else begin locked<=1;held_ccu<=CCU_ID_W'(active);end
      end
      if (recv_config__val && recv_config__rdy) begin
        if (config_msg.cmd>=CONFIG_LOWER && config_msg.cmd<=CONFIG_PARENT && int'(config_msg.ctrl_addr)<NUM_CCUS) begin
          // Any accepted reconfiguration starts a new configuration phase.
          launched<=0;
          configured[config_msg.ctrl_addr]<=1;
          case(config_msg.cmd)
            CONFIG_LOWER:begin lower_bound[config_msg.ctrl_addr]<=config_msg.data.payload;current_value[config_msg.ctrl_addr]<=config_msg.data;end
            CONFIG_UPPER:upper_bound[config_msg.ctrl_addr]<=config_msg.data.payload;
            CONFIG_STEP:step[config_msg.ctrl_addr]<=config_msg.data.payload;
            CONFIG_CHILD_COUNT:child_count[config_msg.ctrl_addr]<=config_msg.data.payload[3:0];
            CONFIG_TARGET:if (num_targets[config_msg.ctrl_addr]<4'(MAX_TARGETS)) begin
              target_addr[config_msg.ctrl_addr][TARGET_IDX_W'(num_targets[config_msg.ctrl_addr])]<=config_msg.data.payload[CTRL_ADDR_W-1:0];
              target_remote[config_msg.ctrl_addr][TARGET_IDX_W'(num_targets[config_msg.ctrl_addr])]<=config_msg.data.predicate;
              target_shadow[config_msg.ctrl_addr][TARGET_IDX_W'(num_targets[config_msg.ctrl_addr])]<=config_msg.data_addr[DATA_ADDR_W-1];
              num_targets[config_msg.ctrl_addr]<=num_targets[config_msg.ctrl_addr]+4'd1;
            end
            CONFIG_PARENT:begin parent_id[config_msg.ctrl_addr]<=config_msg.data.payload[CCU_ID_W-1:0];is_root[config_msg.ctrl_addr]<=config_msg.data.payload[CCU_ID_W];end
            default:begin end
          endcase
        end
        if (config_msg.cmd==LAUNCH) begin
          launched<=1;locked<=0;notify_parent<=0;
          for (integer i=0;i<NUM_CCUS;i++) begin
            state[i]<=configured[i]?RUNNING:IDLE;current_value[i]<={lower_bound[i],3'b100};credits[i]<=0;dispatch_idx[i]<=0;
          end
        end
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk) if (!reset) begin : contract_checks
    integer ci,node;
    bit reached_root,any_root;
    if (recv_config__val && recv_config__rdy) begin
      ci=int'(config_msg.ctrl_addr);
      if (config_msg.cmd>=CONFIG_LOWER && config_msg.cmd<=CONFIG_PARENT) begin
        if (ci>=NUM_CCUS) $fatal(1,"LOOP_CONFIG_CCU");
        if (config_msg.cmd==CONFIG_TARGET && num_targets[ci]>=4'(MAX_TARGETS)) $fatal(1,"LOOP_CONFIG_TARGET_CAPACITY");
        if (config_msg.cmd==CONFIG_PARENT && int'(config_msg.data.payload[CCU_ID_W-1:0])>=NUM_CCUS) $fatal(1,"LOOP_CONFIG_PARENT");
      end
      if (config_msg.cmd==LAUNCH) begin
        any_root=0;
        for (integer i=0;i<NUM_CCUS;i++) if (configured[i]) begin
          if (step[i]==0 || lower_bound[i]>=upper_bound[i] || child_count[i]==0) $fatal(1,"LOOP_CONFIG_RANGE");
          any_root |= is_root[i];node=i;reached_root=0;
          for (integer level=0;level<NUM_CCUS;level++) begin
            if (!configured[node]) $fatal(1,"LOOP_CONFIG_PARENT_UNCONFIGURED");
            if (is_root[node]) reached_root=1;
            else node=int'(parent_id[node]);
          end
          if (!reached_root) $fatal(1,"LOOP_CONFIG_PARENT_CYCLE");
        end
        if (!any_root) $fatal(1,"LOOP_CONFIG_NO_ROOT");
      end
    end
    // Event counts have no identity/epoch tags. Extra terminal credits indicate
    // an invalid duplicate or a threshold inconsistent with the configured tree.
    if (launched) for (integer i=0;i<NUM_CCUS;i++)
      if (configured[i] && next_state[i]==COMPLETE && next_credits[i]!=0) $fatal(1,"LOOP_EXTRA_TERMINAL_COMPLETION");
  end
`endif
endmodule
