// Standalone LoopControllerRTL payload API, pinned at cd7aad878915.
// Event ordering and matching deliberately follow Python (see CURRENT_MIGRATION).
// LEGACY_DISPATCH_WRAP reproduces its full-capacity target-index wrap defect.
// The native default compares the widened successor before narrowing the index.
module cgra_loop_controller #(
  parameter int DATA_W = 32,
  parameter int CTRL_BITS = 107,
  parameter int NUM_CCUS = 8,
  parameter int MAX_TARGETS = 4,
  parameter int DATA_ADDR_W = 3,
  parameter int CTRL_ADDR_W = 3,
  parameter bit LEGACY_DISPATCH_WRAP = 0,
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
  localparam logic [1:0] IDLE=0, RUNNING=1, DISPATCHING=2, COMPLETE=3;
  typedef struct packed {
    logic [DATA_W-1:0] payload;
    logic predicate, bypass, delay;
  } data_t;
  typedef struct packed {
    logic [5:0] cmd;
    data_t data;
    logic [DATA_ADDR_W-1:0] data_addr;
    logic [CTRL_BITS-1:0] ctrl;
    logic [CTRL_ADDR_W-1:0] ctrl_addr;
  } payload_t;
  payload_t config_msg, tile_msg, remote_msg, dispatch_msg;
  assign config_msg = recv_config__msg;
  assign tile_msg = recv_from_tile__msg;
  assign remote_msg = recv_from_remote__msg;

  data_t lower_bound[NUM_CCUS], upper_bound[NUM_CCUS], step[NUM_CCUS];
  data_t current_value[NUM_CCUS];
  logic [1:0] state[NUM_CCUS];
  logic [3:0] child_count[NUM_CCUS], received_count[NUM_CCUS];
  logic [3:0] num_targets[NUM_CCUS], config_target_idx[NUM_CCUS];
  logic [CTRL_ADDR_W-1:0] target_ctrl_addr[NUM_CCUS][MAX_TARGETS];
  logic target_remote[NUM_CCUS][MAX_TARGETS], target_shadow[NUM_CCUS][MAX_TARGETS];
  // Python stores tile/cgra IDs but never reads them, and exposes payloads only.
  // Omit those unobservable registers; do not invent a routing-header contract.
  logic is_root[NUM_CCUS];
  logic [CCU_ID_W-1:0] parent_id[NUM_CCUS];
  logic [TARGET_IDX_W-1:0] dispatch_idx[NUM_CCUS];
  logic has_dispatch, tile_event, remote_event, sent;
  integer active;
  logic [3:0] next_target;

  initial begin
    if (NUM_CCUS < 1 || NUM_CCUS > 2**CTRL_ADDR_W || MAX_TARGETS < 1 || MAX_TARGETS > 15)
      $fatal(1, "LOOP_PARAMETERS: CCU addressability / 4-bit target count");
    if (DATA_W < 4 || DATA_W <= CCU_ID_W || DATA_W < CTRL_ADDR_W ||
        CTRL_BITS < 1 || DATA_ADDR_W < 1 || CTRL_ADDR_W < 1)
      $fatal(1, "LOOP_PARAMETERS: payload field widths");
  end

  always_comb begin
    recv_config__rdy = recv_config__val;
    recv_from_tile__rdy = 0;
    recv_from_remote__rdy = 0;
    send_to_tile__val = 0;
    send_to_remote__val = 0;
    send_to_tile__msg = '0;
    send_to_remote__msg = '0;
    dispatch_msg = '0;
    all_loops_complete = 1;
    has_dispatch = 0;
    active = 0;
    tile_event = 0;
    remote_event = 0;
    sent = 0;
    next_target = 0;
    for (int i=0; i<NUM_CCUS; i++) begin
      if (is_root[i] && state[i] != COMPLETE && state[i] != IDLE)
        all_loops_complete = 0;
      if (state[i] == DISPATCHING && !has_dispatch) begin
        has_dispatch = 1;
        active = i;
      end
    end
    if (has_dispatch) begin
      dispatch_msg.ctrl_addr = target_ctrl_addr[active][dispatch_idx[active]];
      dispatch_msg.cmd = target_shadow[active][dispatch_idx[active]] ? UPDATE_SHADOW : RESET_LEAF;
      if (target_shadow[active][dispatch_idx[active]]) dispatch_msg.data = current_value[active];
      if (target_remote[active][dispatch_idx[active]]) begin
        send_to_remote__val = 1;
        send_to_remote__msg = dispatch_msg;
        sent = send_to_remote__rdy;
      end else begin
        send_to_tile__val = 1;
        send_to_tile__msg = dispatch_msg;
        sent = send_to_tile__rdy;
      end
      if (LEGACY_DISPATCH_WRAP)
        next_target = 4'(TARGET_IDX_W'(dispatch_idx[active] + TARGET_IDX_W'(1)));
      else
        next_target = 4'(dispatch_idx[active]) + 4'd1;
    end
    if (recv_from_tile__val) begin
      if (tile_msg.cmd == LEAF_COMPLETE) begin
        for (int i=0; i<NUM_CCUS; i++)
          for (int t=0; t<MAX_TARGETS; t++)
            if (state[i] == RUNNING && t < num_targets[i] &&
                !target_remote[i][t] && !target_shadow[i][t] &&
                target_ctrl_addr[i][t] == tile_msg.ctrl_addr) tile_event = 1;
        recv_from_tile__rdy = tile_event;
      end else recv_from_tile__rdy = 1;
    end
    if (recv_from_remote__val) begin
      if (remote_msg.cmd == CHILD_COMPLETE) begin
        for (int i=0; i<NUM_CCUS; i++)
          if (state[i] == RUNNING) remote_event = 1;
        recv_from_remote__rdy = remote_event;
      end else recv_from_remote__rdy = 1;
    end
  end

  // Nonblocking assignment priority is significant: config, dispatch, local
  // event (ascending CCU/target), then remote event. All RHS use pre-edge state.
  // This preserves Python's collisions, broadcast matching and one-level parent
  // notification. They are not a general DAG scheduler; see the documented API.
  always_ff @(posedge clk) begin : update_ccus
    logic [3:0] count_next, parent_count_next;
    logic [DATA_W-1:0] value_next, parent_value_next;
    integer ci, ti, parent;
    if (reset) begin
      for (int i=0; i<NUM_CCUS; i++) begin
        lower_bound[i] <= '0;
        upper_bound[i] <= '0;
        step[i] <= '0;
        current_value[i] <= '0;
        state[i] <= IDLE;
        is_root[i] <= 0;
        parent_id[i] <= '0;
        child_count[i] <= 0;
        received_count[i] <= 0;
        num_targets[i] <= 0;
        config_target_idx[i] <= 0;
        dispatch_idx[i] <= 0;
        for (int t=0; t<MAX_TARGETS; t++) begin
          target_ctrl_addr[i][t] <= 0;
          target_remote[i][t] <= 0;
          target_shadow[i][t] <= 0;
        end
      end
    end else begin
      if (recv_config__val) begin
        ci = int'(config_msg.ctrl_addr);
        case (config_msg.cmd)
          CONFIG_LOWER: begin
            lower_bound[ci] <= config_msg.data;
            current_value[ci] <= config_msg.data;
          end
          CONFIG_UPPER: upper_bound[ci] <= config_msg.data;
          CONFIG_STEP: step[ci] <= config_msg.data;
          CONFIG_CHILD_COUNT: child_count[ci] <= config_msg.data.payload[3:0];
          CONFIG_TARGET: begin
            ti = int'(config_target_idx[ci]);
            target_ctrl_addr[ci][ti] <= config_msg.data.payload[CTRL_ADDR_W-1:0];
            target_remote[ci][ti] <= config_msg.data.predicate;
            target_shadow[ci][ti] <= config_msg.data_addr[DATA_ADDR_W-1];
            config_target_idx[ci] <= config_target_idx[ci] + 4'd1;
            num_targets[ci] <= config_target_idx[ci] + 4'd1;
          end
          CONFIG_PARENT: begin
            parent_id[ci] <= config_msg.data.payload[CCU_ID_W-1:0];
            is_root[ci] <= config_msg.data.payload[CCU_ID_W];
          end
          LAUNCH: for (int i=0; i<NUM_CCUS; i++) begin
            if (num_targets[i] != 0 || is_root[i]) begin
              state[i] <= RUNNING;
              current_value[i] <= lower_bound[i];
              received_count[i] <= 0;
              dispatch_idx[i] <= 0;
            end
          end
          default: ; // Python accepts and ignores other configuration commands.
        endcase
      end
      if (has_dispatch && sent) begin
        if (next_target >= num_targets[active]) begin
          dispatch_idx[active] <= 0;
          state[active] <= RUNNING;
          received_count[active] <= 0;
          for (int c=0; c<NUM_CCUS; c++) begin
            if (!is_root[c] && parent_id[c] == CCU_ID_W'(active)) begin
              state[c] <= RUNNING;
              current_value[c] <= lower_bound[c];
              received_count[c] <= 0;
              dispatch_idx[c] <= 0;
            end
          end
        end else dispatch_idx[active] <= TARGET_IDX_W'(next_target);
      end
      if (tile_event) begin
        for (int i=0; i<NUM_CCUS; i++) begin
          for (int t=0; t<MAX_TARGETS; t++) begin
            if (state[i] == RUNNING && t < num_targets[i] &&
                !target_remote[i][t] && !target_shadow[i][t] &&
                target_ctrl_addr[i][t] == tile_msg.ctrl_addr) begin
              count_next = received_count[i] + 4'd1;
              received_count[i] <= count_next;
              if (count_next >= child_count[i]) begin
                value_next = current_value[i].payload + step[i].payload;
                current_value[i] <= {value_next, 3'b100};
                if (value_next >= upper_bound[i].payload) begin
                  state[i] <= COMPLETE;
                  if (!is_root[i]) begin
                    parent = int'(parent_id[i]);
                    parent_count_next = received_count[parent] + 4'd1;
                    received_count[parent] <= parent_count_next;
                    if (parent_count_next >= child_count[parent]) begin
                      parent_value_next = current_value[parent].payload + step[parent].payload;
                      current_value[parent] <= {parent_value_next, 3'b100};
                      if (parent_value_next >= upper_bound[parent].payload) state[parent] <= COMPLETE;
                      else begin
                        state[parent] <= DISPATCHING;
                        dispatch_idx[parent] <= 0;
                      end
                    end
                  end
                end else begin
                  state[i] <= DISPATCHING;
                  dispatch_idx[i] <= 0;
                end
              end
            end
          end
        end
      end
      if (remote_event) begin
        for (int i=0; i<NUM_CCUS; i++) begin
          if (state[i] == RUNNING) begin
            count_next = received_count[i] + 4'd1;
            received_count[i] <= count_next;
            if (count_next >= child_count[i]) begin
              value_next = current_value[i].payload + step[i].payload;
              current_value[i] <= {value_next, 3'b100};
              if (value_next >= upper_bound[i].payload) state[i] <= COMPLETE;
              else begin
                state[i] <= DISPATCHING;
                dispatch_idx[i] <= 0;
              end
            end
          end
        end
      end
    end
  end

  // Invalid configuration has no defined Python behavior (IndexError). Fail
  // simulation explicitly instead of silently accessing a nonexistent register.
`ifndef SYNTHESIS
  always @(posedge clk) if (!reset && recv_config__val) begin
    if (config_msg.cmd >= CONFIG_LOWER && config_msg.cmd <= CONFIG_PARENT) begin
      if (int'(config_msg.ctrl_addr) >= NUM_CCUS) $fatal(1, "LOOP_CONFIG_CCU");
      if (config_msg.cmd == CONFIG_TARGET && int'(config_target_idx[config_msg.ctrl_addr]) >= MAX_TARGETS)
        $fatal(1, "LOOP_CONFIG_TARGET_CAPACITY");
      if (config_msg.cmd == CONFIG_PARENT && int'(config_msg.data.payload[CCU_ID_W-1:0]) >= NUM_CCUS)
        $fatal(1, "LOOP_CONFIG_PARENT");
    end
  end
`endif
endmodule
