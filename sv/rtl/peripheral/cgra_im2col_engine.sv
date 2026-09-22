// Native ac96 Im2colEngineRTL. PRELOAD_IMAGE word zero occupies the low bits.
`include "cgra_profile_defs.svh"
module cgra_im2col_engine #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int SCRATCH_DEPTH=64,
  parameter logic [SCRATCH_DEPTH*DATA_W-1:0] PRELOAD_IMAGE='0,
  localparam int SCRATCH_ADDR_W=$clog2(SCRATCH_DEPTH)
) (
  input logic clk, reset,
  input logic [HOST_BITS-1:0] recv_cmd_pkt__msg,
  input logic recv_cmd_pkt__val,
  output logic recv_cmd_pkt__rdy,
  output logic [HOST_BITS-1:0] send_pkt__msg,
  output logic send_pkt__val,
  input logic send_pkt__rdy,
  output logic done
);
  `include "cgra_profile.svh"
  localparam logic [1:0] IDLE=0, READ=1, EMIT=2, DONE=3;
  typedef logic [SCRATCH_ADDR_W-1:0] scratch_addr_t;
  logic [1:0] state;
  scratch_addr_t oy,ox,ky,kx,cfg_H,cfg_W,cfg_kH,cfg_kW,cfg_log2_stride,cfg_Hout,cfg_Wout;
  scratch_addr_t in_row,in_col,in_addr,read_addr;
  logic [GLOBAL_ADDR_W-1:0] emit_idx,cfg_dst_sram_base_addr;
  data_t data_reg,read_data;
  host_packet_t command,out_packet;
  // DataMemRTL lazily writes preload data and never resets these states.
  logic [SCRATCH_DEPTH-1:0] init_writes;
  data_t image_mem [0:SCRATCH_DEPTH-1];
  data_t preload_data [0:SCRATCH_DEPTH-1];
  initial begin
    if(SCRATCH_DEPTH<2 || DATA_W<SCRATCH_ADDR_W)
      $fatal(1,"Im2col requires SCRATCH_DEPTH >= 2 and DATA_W >= scratch address width");
  end
  for(genvar i=0;i<SCRATCH_DEPTH;i++) begin:g_preload
    assign preload_data[i]={PRELOAD_IMAGE[DATA_W*i+:DATA_W],3'b100};
  end
  assign command=recv_cmd_pkt__msg;
  assign in_row=scratch_addr_t'((oy<<cfg_log2_stride)+ky);
  assign in_col=scratch_addr_t'((ox<<cfg_log2_stride)+kx);
  assign in_addr=scratch_addr_t'(in_row*cfg_W+in_col);
  assign read_addr=state==READ ? in_addr : scratch_addr_t'(0);
  assign read_data=init_writes[read_addr] ? image_mem[read_addr] : preload_data[read_addr];
  // The original scratchpad's preload write is not gated by read valid or reset.
  always_ff @(posedge clk) begin
    if(!init_writes[read_addr]) image_mem[read_addr]<=preload_data[read_addr];
    if(state==READ) init_writes[read_addr]<=1'b1;
  end
  assign recv_cmd_pkt__rdy=state==IDLE;
  assign send_pkt__val=state==EMIT;
  assign done=state==DONE;
  assign send_pkt__msg=out_packet;
  always_comb begin
    out_packet='0;
    if(state==EMIT) begin
      out_packet.payload.cmd=6'd12;
      out_packet.payload.data=data_reg;
      out_packet.payload.data_addr=cfg_dst_sram_base_addr+emit_idx;
    end
  end
  always_ff @(posedge clk) begin
    if(reset) begin
      state<=IDLE;oy<='0;ox<='0;ky<='0;kx<='0;emit_idx<='0;data_reg<='0;
    end else begin
      case(state)
        IDLE:if(recv_cmd_pkt__val) begin
          // Geometry and destination configuration deliberately survive reset.
          case(command.payload.cmd)
            6'd53:cfg_H<=scratch_addr_t'(command.payload.data.payload);
            6'd54:cfg_W<=scratch_addr_t'(command.payload.data.payload);
            6'd55:cfg_kH<=scratch_addr_t'(command.payload.data.payload);
            6'd56:cfg_kW<=scratch_addr_t'(command.payload.data.payload);
            6'd57:cfg_log2_stride<=scratch_addr_t'(command.payload.data.payload);
            6'd58:cfg_dst_sram_base_addr<=command.payload.data_addr;
            6'd52:begin
              // Cast before shifting preserves narrow unsigned subtraction.
              cfg_Hout<=scratch_addr_t'((scratch_addr_t'(cfg_H-cfg_kH)>>cfg_log2_stride)+scratch_addr_t'(1));
              cfg_Wout<=scratch_addr_t'((scratch_addr_t'(cfg_W-cfg_kW)>>cfg_log2_stride)+scratch_addr_t'(1));
              state<=READ;oy<='0;ox<='0;ky<='0;kx<='0;emit_idx<='0;
            end
            default:;
          endcase
        end
        READ:begin data_reg<=read_data;state<=EMIT;end
        EMIT:if(send_pkt__rdy) begin
          if(scratch_addr_t'(ox+scratch_addr_t'(1))<cfg_Wout) begin ox<=ox+scratch_addr_t'(1);state<=READ;end
          else if(scratch_addr_t'(oy+scratch_addr_t'(1))<cfg_Hout) begin ox<='0;oy<=oy+scratch_addr_t'(1);state<=READ;end
          else if(scratch_addr_t'(kx+scratch_addr_t'(1))<cfg_kW) begin ox<='0;oy<='0;kx<=kx+scratch_addr_t'(1);state<=READ;end
          else if(scratch_addr_t'(ky+scratch_addr_t'(1))<cfg_kH) begin ox<='0;oy<='0;kx<='0;ky<=ky+scratch_addr_t'(1);state<=READ;end
          else state<=DONE;
          emit_idx<=emit_idx+GLOBAL_ADDR_W'(1);
        end
        default:; // DONE holds until reset, including command backpressure.
      endcase
    end
  end
endmodule
