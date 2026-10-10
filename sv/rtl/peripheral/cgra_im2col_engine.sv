// Im2col image-window engine. PRELOAD_IMAGE word zero occupies the low bits.
// Native mode reuses DataMem, validates geometry and supports repeated launches.
`include "cgra_profile_defs.svh"
module cgra_im2col_engine #(
  `CGRA_PROFILE_PARAMETERS,
  parameter int SCRATCH_DEPTH=64,
  parameter bit LEGACY_PYTHON=0,
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
  function automatic logic [SCRATCH_DEPTH*DATA_BITS-1:0] image_words();
    logic [SCRATCH_DEPTH*DATA_BITS-1:0] words;
    for(integer i=0;i<SCRATCH_DEPTH;i++) words[i*DATA_BITS+:DATA_BITS]={PRELOAD_IMAGE[i*DATA_W+:DATA_W],3'b100};
    return words;
  endfunction
  generate if(LEGACY_PYTHON) begin:legacy
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
  end else begin:native_mode
  localparam int GEOM_W=SCRATCH_ADDR_W+1;
  localparam int COUNT_W=(4*GEOM_W>GLOBAL_ADDR_W+1)?4*GEOM_W:GLOBAL_ADDR_W+1;
  typedef logic [GEOM_W-1:0] geometry_t;
  typedef logic [COUNT_W-1:0] count_t;
  localparam logic [1:0] IDLE=0, READ=1, EMIT=2, DONE=3;
  logic [1:0] state;
  geometry_t h,w,kh,kw,lg,oh,ow,oy,ox,ky,kx,next_oh,next_ow;
  logic [GLOBAL_ADDR_W-1:0] destination,emit_idx;
  data_t data_reg;
  host_packet_t command,out_packet;
  logic command_legal,launch_legal;
  count_t image_size,output_count,destination_end;
  logic [SCRATCH_ADDR_W-1:0] read_addr [0:0],write_addr [0:0];
  logic [DATA_BITS-1:0] read_data [0:0],write_data [0:0];
  logic [0:0] read_valid,read_ready;
  cgra_data_mem #(.DATA_BITS(DATA_BITS),.DEPTH(SCRATCH_DEPTH),.PRELOAD_ENABLE(1),.PRELOAD_WORDS(image_words())) scratchpad (
    .clk,.reset,.recv_raddr__msg(read_addr),.recv_raddr__val(1'(state==READ)),.recv_raddr__rdy(read_ready),
    .send_rdata__msg(read_data),.send_rdata__val(read_valid),.send_rdata__rdy(1'b1),
    .recv_waddr__msg(write_addr),.recv_waddr__val(1'b0),.recv_waddr__rdy(),
    .recv_wdata__msg(write_data),.recv_wdata__val(1'b0),.recv_wdata__rdy()
  );
  assign write_addr[0]='0;
  assign write_data[0]='0;
  assign read_addr[0]=SCRATCH_ADDR_W'(((oy<<lg)+ky)*w+(ox<<lg)+kx);
  assign command=recv_cmd_pkt__msg;
  assign next_oh=((h-kh)>>lg)+GEOM_W'(1);
  assign next_ow=((w-kw)>>lg)+GEOM_W'(1);
  assign image_size=count_t'(h)*count_t'(w);
  assign output_count=count_t'(next_oh)*count_t'(next_ow)*count_t'(kh)*count_t'(kw);
  assign destination_end=count_t'(destination)+output_count;
  assign launch_legal=h!=0 && w!=0 && kh!=0 && kw!=0 && kh<=h && kw<=w &&
    image_size<=SCRATCH_DEPTH && lg<=SCRATCH_ADDR_W && destination_end<=(count_t'(1)<<GLOBAL_ADDR_W);
  always_comb begin
    command_legal=1;
    case(command.payload.cmd)
      6'd52:command_legal=launch_legal;
      6'd53,6'd54,6'd55,6'd56:command_legal=command.payload.data.payload>0 && command.payload.data.payload<=SCRATCH_DEPTH;
      6'd57:command_legal=command.payload.data.payload<=SCRATCH_ADDR_W;
      default:;
    endcase
    out_packet='0;
    if(send_pkt__val) begin
      out_packet.payload.cmd=6'd12;
      out_packet.payload.data=data_reg;
      out_packet.payload.data_addr=destination+emit_idx;
    end
  end
  assign recv_cmd_pkt__rdy=!reset && (state==IDLE || state==DONE) && command_legal;
  assign send_pkt__val=!reset && state==EMIT;
  assign send_pkt__msg=out_packet;
  assign done=!reset && state==DONE;
  always_ff @(posedge clk) begin
    if(reset) begin
      state<=IDLE;h<=0;w<=0;kh<=0;kw<=0;lg<=0;oh<=0;ow<=0;
      oy<=0;ox<=0;ky<=0;kx<=0;destination<=0;emit_idx<=0;data_reg<='0;
    end else begin
      case(state)
        IDLE,DONE:if(recv_cmd_pkt__val && recv_cmd_pkt__rdy) begin
          state<=IDLE;
          case(command.payload.cmd)
            6'd53:h<=geometry_t'(command.payload.data.payload);
            6'd54:w<=geometry_t'(command.payload.data.payload);
            6'd55:kh<=geometry_t'(command.payload.data.payload);
            6'd56:kw<=geometry_t'(command.payload.data.payload);
            6'd57:lg<=geometry_t'(command.payload.data.payload);
            6'd58:destination<=command.payload.data_addr;
            6'd52:begin
              oh<=next_oh;ow<=next_ow;state<=READ;oy<=0;ox<=0;ky<=0;kx<=0;emit_idx<=0;
            end
            default:;
          endcase
        end
        READ:if(read_valid[0]) begin data_reg<=read_data[0];state<=EMIT;end
        EMIT:if(send_pkt__rdy) begin
          if(ox+GEOM_W'(1)<ow) begin ox<=ox+GEOM_W'(1);state<=READ;end
          else if(oy+GEOM_W'(1)<oh) begin ox<=0;oy<=oy+GEOM_W'(1);state<=READ;end
          else if(kx+GEOM_W'(1)<kw) begin ox<=0;oy<=0;kx<=kx+GEOM_W'(1);state<=READ;end
          else if(ky+GEOM_W'(1)<kh) begin ox<=0;oy<=0;kx<=0;ky<=ky+GEOM_W'(1);state<=READ;end
          else state<=DONE;
          emit_idx<=emit_idx+GLOBAL_ADDR_W'(1);
        end
        default:state<=IDLE;
      endcase
    end
  end
  initial if(SCRATCH_DEPTH<2 || DATA_W<GEOM_W)
    $fatal(1,"IM2COL_NATIVE_PARAMETERS: positive geometry must fit the data word");
`ifndef SYNTHESIS
  always @(posedge clk) if(!reset && (state==IDLE || state==DONE) && recv_cmd_pkt__val && !command_legal)
    $fatal(1,"IM2COL_NATIVE_COMMAND: invalid geometry, stride or destination span");
`endif
  end endgenerate
endmodule
