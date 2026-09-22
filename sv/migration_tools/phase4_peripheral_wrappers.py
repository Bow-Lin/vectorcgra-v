"""Migration-only writer for generic peripheral wrapper port/parameter scaffolding."""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/'sv/rtl/cgra/cgra_system.sv').read_text()
params=source.split('module cgra_system #(\n',1)[1].split('\n) (',1)[0]
ports=source.split('\n) (\n',1)[1].split('\n);',1)[0]
external=ports.split('  output logic [138:0] dma_cmd__msg,')[0].rstrip().rstrip(',')
names=[]
for line in external.splitlines():
  tail=re.sub(r'^\s*(?:input|output) logic\s*(?:\[[^]]+\])?\s*','',line).rstrip(',')
  names.extend(re.sub(r'\s*\[.*','',x.strip()) for x in tail.split(','))
topology=['TILE_VARIANT','IS_MULTI','TILE_FU_COUNTS','TILE_FU_KINDS','CUSTOM_TOPOLOGY','LINK_COUNT','LINK_ENABLED',
  'LINK_SRC_TILE','LINK_SRC_PORT','LINK_DST_TILE','LINK_DST_PORT','READ_PORT_TILE','WRITE_PORT_TILE','BOUNDARY_IN_ENABLE','BOUNDARY_OUT_ENABLE']
for kind in ['dma','im2col']:
  name='cgra_integrated_'+kind
  extra=(',\n  parameter bit BASELINE_TRANSLATED_SLICES=1' if kind=='dma' else ',\n  parameter int SCRATCH_DEPTH=64,\n  parameter logic[SCRATCH_DEPTH*DATA_W-1:0] PRELOAD_IMAGE=\'0')
  exposed=external
  if kind=='dma':
    exposed+=r''',
  output logic[63:0] send_to_dram_rd_req__msg,
  output logic send_to_dram_rd_req__val,
  input logic send_to_dram_rd_req__rdy,
  input logic[127:0] recv_from_dram_rd_resp__msg,
  input logic recv_from_dram_rd_resp__val,
  output logic recv_from_dram_rd_resp__rdy,
  output logic[207:0] send_to_dram_wr_req__msg,
  output logic send_to_dram_wr_req__val,
  input logic send_to_dram_wr_req__rdy,
  input logic recv_from_dram_wr_resp__msg,
  input logic recv_from_dram_wr_resp__val,
  output logic recv_from_dram_wr_resp__rdy'''
  text='// Native parameterized composition; baseline engines are separate reusable RTL.\n'
  text+='`include "cgra_profile_defs.svh"\n`include "cgra_fu_catalog.svh"\n'
  text+=f'module {name} #(\n{params}{extra}\n) (\n{exposed}\n);\n'
  text+='  `include "cgra_profile.svh"\n'
  if kind=='dma':
    text+='  initial if(!HAS_DMA || HAS_IM2COL || DATA_W!=32) $fatal(1,"cgra_integrated_dma requires HAS_DMA=1, HAS_IM2COL=0 and DATA_W=32");\n'
    text+=r'''  logic [138:0] command_msg;logic command_val,command_rdy;
  logic [7:0] done_msg;logic done_val,done_rdy;
  logic [31:0] rd_msg,rdata_msg;logic rd_val,rd_rdy,rdata_val,rdata_rdy;
  logic [67:0] wr_msg;logic wr_val,wr_rdy;
  cgra_dma_engine #(.BASELINE_TRANSLATED_SLICES(BASELINE_TRANSLATED_SLICES)) dma (
    .clk,.reset,.dma_cmd__msg(command_msg),.dma_cmd__val(command_val),.dma_cmd__rdy(command_rdy),
    .dma_done__msg(done_msg),.dma_done__val(done_val),.dma_done__rdy(done_rdy),
    .send_to_dram_rd_req__msg,.send_to_dram_rd_req__val,.send_to_dram_rd_req__rdy,
    .recv_from_dram_rd_resp__msg,.recv_from_dram_rd_resp__val,.recv_from_dram_rd_resp__rdy,
    .send_to_dram_wr_req__msg,.send_to_dram_wr_req__val,.send_to_dram_wr_req__rdy,
    .recv_from_dram_wr_resp__msg,.recv_from_dram_wr_resp__val,.recv_from_dram_wr_resp__rdy,
    .send_to_spm_rd_req__msg(rd_msg),.send_to_spm_rd_req__val(rd_val),.send_to_spm_rd_req__rdy(rd_rdy),
    .send_to_spm_wr_req__msg(wr_msg),.send_to_spm_wr_req__val(wr_val),.send_to_spm_wr_req__rdy(wr_rdy),
    .recv_from_spm_rd_resp__msg(rdata_msg),.recv_from_spm_rd_resp__val(rdata_val),.recv_from_spm_rd_resp__rdy(rdata_rdy)
  );
'''
    bindings={
      'dma_cmd__msg':'command_msg','dma_cmd__val':'command_val','dma_cmd__rdy':'command_rdy',
      'dma_done__msg':'done_msg','dma_done__val':'done_val','dma_done__rdy':'done_rdy',
      'recv_from_dma_spm_rd_req__msg':'rd_msg','recv_from_dma_spm_rd_req__val':'rd_val','recv_from_dma_spm_rd_req__rdy':'rd_rdy',
      'recv_from_dma_spm_wr_req__msg':'wr_msg','recv_from_dma_spm_wr_req__val':'wr_val','recv_from_dma_spm_wr_req__rdy':'wr_rdy',
      'send_to_dma_spm_rd_resp__msg':'rdata_msg','send_to_dma_spm_rd_resp__val':'rdata_val','send_to_dma_spm_rd_resp__rdy':'rdata_rdy',
      'recv_from_im2col_pkt__msg':"'0",'recv_from_im2col_pkt__val':"1'b0",'recv_from_im2col_pkt__rdy':'',
      'send_to_im2col_engine_pkt__msg':'','send_to_im2col_engine_pkt__val':'','send_to_im2col_engine_pkt__rdy':"1'b0"}
  else:
    text+='  initial if(!HAS_IM2COL || HAS_DMA || IS_MULTI) $fatal(1,"cgra_integrated_im2col requires HAS_IM2COL=1, HAS_DMA=0 and IS_MULTI=0");\n'
    text+=r'''  logic [HOST_BITS-1:0] engine_recv_msg,engine_send_msg;
  logic engine_recv_val,engine_recv_rdy,engine_send_val,engine_send_rdy,engine_done,engine_active;
  logic cpu_val,cpu_rdy;
  host_packet_t launch_packet;
  assign launch_packet=engine_recv_msg;
  always_ff @(posedge clk) begin
    if(reset)engine_active<=0;
    else if(engine_recv_val && engine_recv_rdy && launch_packet.payload.cmd==6'd52)engine_active<=1;
    else if(engine_done)engine_active<=0;
  end
  assign cpu_val=engine_active ? 1'b0 : recv_from_cpu_pkt__val;
  assign recv_from_cpu_pkt__rdy=engine_active ? 1'b0 : cpu_rdy;
  cgra_im2col_engine #(`CGRA_PROFILE_BIND,.SCRATCH_DEPTH(SCRATCH_DEPTH),.PRELOAD_IMAGE(PRELOAD_IMAGE)) engine (
    .clk,.reset,.recv_cmd_pkt__msg(engine_recv_msg),.recv_cmd_pkt__val(engine_recv_val),.recv_cmd_pkt__rdy(engine_recv_rdy),
    .send_pkt__msg(engine_send_msg),.send_pkt__val(engine_send_val),.send_pkt__rdy(engine_send_rdy),.done(engine_done)
  );
'''
    bindings={
      'dma_cmd__msg':'','dma_cmd__val':'','dma_cmd__rdy':"1'b0",'dma_done__msg':"'0",'dma_done__val':"1'b0",'dma_done__rdy':'',
      'recv_from_dma_spm_rd_req__msg':"'0",'recv_from_dma_spm_rd_req__val':"1'b0",'recv_from_dma_spm_rd_req__rdy':'',
      'recv_from_dma_spm_wr_req__msg':"'0",'recv_from_dma_spm_wr_req__val':"1'b0",'recv_from_dma_spm_wr_req__rdy':'',
      'send_to_dma_spm_rd_resp__msg':'','send_to_dma_spm_rd_resp__val':'','send_to_dma_spm_rd_resp__rdy':"1'b0",
      'recv_from_im2col_pkt__msg':'engine_send_msg','recv_from_im2col_pkt__val':'engine_send_val','recv_from_im2col_pkt__rdy':'engine_send_rdy',
      'send_to_im2col_engine_pkt__msg':'engine_recv_msg','send_to_im2col_engine_pkt__val':'engine_recv_val','send_to_im2col_engine_pkt__rdy':'engine_recv_rdy'}
  conns=[]
  for n in names:
    v=n
    if kind=='im2col' and n=='recv_from_cpu_pkt__val':v='cpu_val'
    if kind=='im2col' and n=='recv_from_cpu_pkt__rdy':v='cpu_rdy'
    conns.append(f'.{n}({v})')
  conns.extend(f'.{n}({v})' for n,v in bindings.items())
  text+='  cgra_system #(`CGRA_PROFILE_BIND,`CGRA_FU_BIND,\n    '+',\n    '.join(f'.{n}({n})' for n in topology)+') cgra (\n    '+',\n    '.join(conns)+'\n  );\nendmodule\n'
  (ROOT/'sv/rtl/peripheral'/(name+'.sv')).write_text(text,newline='\n')
