// Native DmaEngineRTL targeting Python cd7aad878915.
// Native commands use 32-bit SPM words and whole-word byte counts.
// LEGACY_PYTHON preserves the source's truncation, underflow and reset handshakes.
module cgra_dma_engine #(
  parameter int SPM_DATA_W=32, DRAM_DATA_W=128, DRAM_ADDR_W=64,
  parameter int SPM_ADDR_W=32, BYTES_W=32, TAG_W=8,
  parameter bit BASELINE_TRANSLATED_SLICES=0, LEGACY_PYTHON=0,
  localparam int CMD_BITS=3+DRAM_ADDR_W+SPM_ADDR_W+BYTES_W+TAG_W,
  localparam int DRAM_MASK_W=DRAM_DATA_W/8, SPM_MASK_W=SPM_DATA_W/8,
  localparam int DRAM_WRITE_BITS=DRAM_ADDR_W+DRAM_DATA_W+DRAM_MASK_W,
  localparam int SPM_WRITE_BITS=SPM_ADDR_W+SPM_DATA_W+SPM_MASK_W
) (
  input logic clk, reset,
  input logic [CMD_BITS-1:0] dma_cmd__msg,
  input logic dma_cmd__val,
  output logic dma_cmd__rdy,
  output logic [TAG_W-1:0] dma_done__msg,
  output logic dma_done__val,
  input logic dma_done__rdy,
  output logic [DRAM_ADDR_W-1:0] send_to_dram_rd_req__msg,
  output logic send_to_dram_rd_req__val,
  input logic send_to_dram_rd_req__rdy,
  input logic [DRAM_DATA_W-1:0] recv_from_dram_rd_resp__msg,
  input logic recv_from_dram_rd_resp__val,
  output logic recv_from_dram_rd_resp__rdy,
  output logic [DRAM_WRITE_BITS-1:0] send_to_dram_wr_req__msg,
  output logic send_to_dram_wr_req__val,
  input logic send_to_dram_wr_req__rdy,
  input logic recv_from_dram_wr_resp__msg,
  input logic recv_from_dram_wr_resp__val,
  output logic recv_from_dram_wr_resp__rdy,
  output logic [SPM_WRITE_BITS-1:0] send_to_spm_wr_req__msg,
  output logic send_to_spm_wr_req__val,
  input logic send_to_spm_wr_req__rdy,
  output logic [SPM_ADDR_W-1:0] send_to_spm_rd_req__msg,
  output logic send_to_spm_rd_req__val,
  input logic send_to_spm_rd_req__rdy,
  input logic [SPM_DATA_W-1:0] recv_from_spm_rd_resp__msg,
  input logic recv_from_spm_rd_resp__val,
  output logic recv_from_spm_rd_resp__rdy
);
  typedef struct packed {
    logic [2:0] opcode;
    logic [DRAM_ADDR_W-1:0] dram_addr;
    logic [SPM_ADDR_W-1:0] spm_addr;
    logic [BYTES_W-1:0] nbytes;
    logic [TAG_W-1:0] dma_tag;
  } command_t;
  command_t command;
  assign command=dma_cmd__msg;
  logic enabled,legal_command;
  assign enabled=LEGACY_PYTHON || !reset;
  assign legal_command=LEGACY_PYTHON || (command.opcode<2 && command.nbytes%4==0);
  localparam logic [3:0] IDLE=0, MVIN_REQ=1, MVIN_RESP=2, MVIN_WRITE=3,
    MVOUT_READ=4, MVOUT_RESP=5, MVOUT_WRITE=6, MVOUT_WAIT=7, DONE=8;
  logic [3:0] state;
  logic [2:0] opcode_reg;
  logic [DRAM_ADDR_W-1:0] dram_addr_reg;
  logic [SPM_ADDR_W-1:0] spm_addr_reg;
  logic [BYTES_W-1:0] words_left_reg;
  logic [TAG_W-1:0] tag_reg;
  logic [DRAM_DATA_W-1:0] beat_reg;
  localparam int WORDS_PER_BEAT=DRAM_DATA_W/SPM_DATA_W;
  localparam int WORD_IDX_W=WORDS_PER_BEAT>1 ? $clog2(WORDS_PER_BEAT) : 1;
  logic [WORD_IDX_W-1:0] word_idx_reg;
  logic [DRAM_MASK_W-1:0] wr_mask_reg;
  initial begin
    if(SPM_DATA_W<8 || SPM_DATA_W%8 || DRAM_DATA_W<SPM_DATA_W || DRAM_DATA_W%SPM_DATA_W)
      $fatal(1,"DMA requires byte-sized SPM words and an integral number per DRAM beat");
    if(!LEGACY_PYTHON && SPM_DATA_W!=32)
      $fatal(1,"DMA_NATIVE_WORD_WIDTH: only 32-bit SPM words are supported");
    if(BASELINE_TRANSLATED_SLICES && (SPM_DATA_W!=32 || DRAM_DATA_W!=128))
      $fatal(1,"Historical translated-slice mode requires SPM32/DRAM128");
    if(DRAM_ADDR_W<1 || SPM_ADDR_W<1 || BYTES_W<1 || TAG_W<1)
      $fatal(1,"DMA address, count and tag widths must be positive");
  end
  assign dma_cmd__rdy=enabled && state==IDLE && legal_command;
  assign dma_done__val=enabled && state==DONE;
  assign dma_done__msg=tag_reg;
  assign send_to_dram_rd_req__val=enabled && state==MVIN_REQ;
  assign send_to_dram_rd_req__msg=dram_addr_reg;
  assign recv_from_dram_rd_resp__rdy=enabled && state==MVIN_RESP;
  assign send_to_dram_wr_req__val=enabled && state==MVOUT_WRITE;
  assign send_to_dram_wr_req__msg={dram_addr_reg,beat_reg,wr_mask_reg};
  assign recv_from_dram_wr_resp__rdy=enabled && state==MVOUT_WAIT;
  assign send_to_spm_wr_req__val=enabled && state==MVIN_WRITE;
  // Frozen PyMTL HDL narrows the lane-2/3 slice lower bounds to six bits:
  // 6'(32)*6'd2 -> 0 and 6'(32)*6'd3 -> 32. Explicit historical mode only.
  wire [WORD_IDX_W-1:0] read_word_idx=BASELINE_TRANSLATED_SLICES ? WORD_IDX_W'(word_idx_reg[0]) : word_idx_reg;
  assign send_to_spm_wr_req__msg={spm_addr_reg,beat_reg[SPM_DATA_W*read_word_idx+:SPM_DATA_W],{SPM_MASK_W{1'b1}}};
  assign send_to_spm_rd_req__val=enabled && state==MVOUT_READ;
  assign send_to_spm_rd_req__msg=spm_addr_reg;
  assign recv_from_spm_rd_resp__rdy=enabled && state==MVOUT_RESP;
`ifndef SYNTHESIS
  always @(posedge clk) if(!LEGACY_PYTHON && !reset && state==IDLE && dma_cmd__val && !legal_command)
    $fatal(1,"DMA_NATIVE_COMMAND: opcode must be MVIN/MVOUT and nbytes must be a multiple of four");
`endif
  always_ff @(posedge clk) begin
    if(reset) begin
      state<=IDLE; opcode_reg<='0; dram_addr_reg<='0; spm_addr_reg<='0;
      words_left_reg<='0; tag_reg<='0; beat_reg<='0; word_idx_reg<='0; wr_mask_reg<='0;
    end else begin
      case(state)
        IDLE: if(dma_cmd__val && dma_cmd__rdy) begin
          opcode_reg<=command.opcode; dram_addr_reg<=command.dram_addr;
          spm_addr_reg<=command.spm_addr; words_left_reg<=command.nbytes>>2;
          tag_reg<=command.dma_tag; beat_reg<='0; word_idx_reg<='0; wr_mask_reg<='0;
          if(command.nbytes==0) state<=DONE;
          else if(command.opcode==0) state<=MVIN_REQ;
          else state<=MVOUT_READ; // All other opcodes follow MVOUT in ac96.
        end
        MVIN_REQ: if(send_to_dram_rd_req__val && send_to_dram_rd_req__rdy) begin
          dram_addr_reg<=dram_addr_reg+DRAM_ADDR_W'(DRAM_MASK_W); state<=MVIN_RESP;
        end
        MVIN_RESP: if(recv_from_dram_rd_resp__val && recv_from_dram_rd_resp__rdy) begin
          beat_reg<=recv_from_dram_rd_resp__msg; word_idx_reg<=0; state<=MVIN_WRITE;
        end
        MVIN_WRITE: if(send_to_spm_wr_req__val && send_to_spm_wr_req__rdy) begin
          spm_addr_reg<=spm_addr_reg+SPM_ADDR_W'(1);
          words_left_reg<=words_left_reg-BYTES_W'(1);
          if(words_left_reg==1) state<=DONE;
          else if(word_idx_reg==WORDS_PER_BEAT-1) begin word_idx_reg<=0; state<=MVIN_REQ; end
          else word_idx_reg<=word_idx_reg+WORD_IDX_W'(1);
        end
        MVOUT_READ: if(send_to_spm_rd_req__val && send_to_spm_rd_req__rdy) state<=MVOUT_RESP;
        MVOUT_RESP: if(recv_from_spm_rd_resp__val && recv_from_spm_rd_resp__rdy) begin
          // Assign the complete next beat; only the selected word changes.
          if(BASELINE_TRANSLATED_SLICES && word_idx_reg==1)
            // Original HDL lane-1 concatenation is 192 bits, then truncates
            // to 128. The unused third word temporarily repeats word zero.
            beat_reg<={beat_reg[63:0],recv_from_spm_rd_resp__msg,beat_reg[31:0]};
          else
            beat_reg <= beat_reg | (DRAM_DATA_W'(recv_from_spm_rd_resp__msg) << (SPM_DATA_W*word_idx_reg));
          spm_addr_reg<=spm_addr_reg+SPM_ADDR_W'(1);
          words_left_reg<=words_left_reg-BYTES_W'(1);
          if(words_left_reg==1) begin
            wr_mask_reg <= {DRAM_MASK_W{1'b1}} >> (DRAM_MASK_W-(int'(word_idx_reg)+1)*SPM_MASK_W);
            state<=MVOUT_WRITE;
          end else if(word_idx_reg==WORDS_PER_BEAT-1) begin wr_mask_reg<='1; state<=MVOUT_WRITE; end
          else begin word_idx_reg<=word_idx_reg+WORD_IDX_W'(1);state<=MVOUT_READ;end
        end
        MVOUT_WRITE: if(send_to_dram_wr_req__val && send_to_dram_wr_req__rdy) state<=MVOUT_WAIT;
        MVOUT_WAIT: if(recv_from_dram_wr_resp__val && recv_from_dram_wr_resp__rdy) begin
          dram_addr_reg<=dram_addr_reg+DRAM_ADDR_W'(DRAM_MASK_W);beat_reg<='0;word_idx_reg<=0;wr_mask_reg<='0;
          state<=words_left_reg==0 ? DONE : MVOUT_READ;
        end
        DONE: if(dma_done__val && dma_done__rdy) state<=IDLE;
        default: ; // Original FSM also holds an unrecognized state.
      endcase
    end
  end
endmodule
