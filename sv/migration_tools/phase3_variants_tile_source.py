"""One-time explicit wiring emitter; maintained RTL has no Python dependency."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
RTL=ROOT/'sv/rtl'
OUT=RTL/'tile/variants'
src=(RTL/'tile/tile_core.sv').read_text()
header=src[src.index(') (')+3:src.index('\n);')].replace('[0:3]','[0:TILE_PORTS-1]')
ports=re.findall(r'(?:input|output)\s+logic\s*\[[^]]+\]\s*(\w+)',header)
s=['// Native ac96 TileWithContextSwitchRTL / TileWithStreamingLoadRTL wiring.',
'// STREAMING selects the original structural/state differences, not a behavior model.',
'`include "cgra_profile_defs.svh"','`include "cgra_fu_catalog.svh"',
'module tile_variant_core #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS, parameter bit STREAMING=0) ('+header+'\n);',
'  `include "cgra_profile.svh"',
'  localparam int ROUTE_INPUTS = STREAMING ? TILE_PORTS : TILE_PORTS+4;',
'  host_packet_t packet; ctrl_t control;',
'  logic clear, element_done, routing_crossbar_done, fu_crossbar_done;',
'  assign packet=recv_from_controller_pkt__msg;',
'  initial begin',
'    if ((!STREAMING && TILE_PORTS!=4) || (STREAMING && TILE_PORTS!=8))',
'      $fatal(1,"ac96 validated Tile variants require context4 / streaming8 physical ports");',
'  end']

def component(path,module,instance,params,replace={}):
  text=(RTL/path).read_text(); head=text[text.index(') (')+3:text.index('\n);')]
  args=[]
  for line in head.splitlines():
    m=re.search(r'(input|output)\s+logic\s*(\[[^]]+\])?\s*(\w+)\s*((?:\[[^]]+\])*)',line)
    if not m:continue
    direction,width,name,array=m.groups()
    if name in ('clk','reset'): wire=name
    else:
      wire=instance+'__'+name;decl=f'  logic {width or ""} {wire} {array};'
      for a,b in replace.items():decl=decl.replace(a,b)
      s.append(decl)
    args.append(f'.{name}({wire})')
  s.append(f'  {module} #({params}) {instance} (\n    '+',\n    '.join(args)+'\n  );')

component(Path('tile/variants/tile_variant_const_queue.sv'),'tile_variant_const_queue','const_mem','`CGRA_PROFILE_BIND, .CONST_DEPTH(CTRL_DEPTH+(STREAMING?0:10))')
component(Path('tile/variants/tile_variant_ctrl_mem.sv'),'tile_variant_ctrl_mem','ctrl_mem','`CGRA_PROFILE_BIND')
component(Path('fu/tile_flexible_fu_configurable.sv'),'tile_flexible_fu_configurable','element','`CGRA_PROFILE_BIND, `CGRA_FU_BIND')
component(Path('mem/register_cluster.sv'),'register_cluster','register_cluster','`CGRA_PROFILE_BIND')
component(Path('tile/variants/tile_variant_crossbar.sv'),'tile_variant_crossbar','routing_crossbar','`CGRA_PROFILE_BIND, .INPUTS(ROUTE_INPUTS)',{'SELECT_W':'ROUTING_SEL_W','INPUTS':'ROUTE_INPUTS'})
component(Path('tile/variants/tile_variant_crossbar.sv'),'tile_variant_crossbar','fu_crossbar','`CGRA_PROFILE_BIND, .INPUTS(2)',{'SELECT_W':'2','INPUTS':'2'})

def assign(a,b):s.append(f'  assign {a}={b};')
def link(sender,receiver,index_a='',index_b=''):
  for field in ['msg','val']:assign(receiver+'__'+field+index_b,sender+'__'+field+index_a)
  assign(sender+'__rdy'+index_a,receiver+'__rdy'+index_b)

for inst in ['ctrl_mem','element','routing_crossbar','fu_crossbar']:assign(inst+'__tile_id','tile_id')
for inst in ['ctrl_mem','routing_crossbar','fu_crossbar']:assign(inst+'__cgra_id','cgra_id')
assign('routing_crossbar__crossbar_id',"1'b0");assign('fu_crossbar__crossbar_id',"1'b1")
assign('control','ctrl_mem__send_ctrl__msg')
link('const_mem__send_const','element__recv_const')
link('element__send_to_ctrl_mem','ctrl_mem__recv_from_element')
link('ctrl_mem__send_to_element','element__recv_from_ctrl_mem')
for inst in ['routing_crossbar','fu_crossbar']:
  assign(inst+'__ctrl_addr_inport','ctrl_mem__ctrl_addr_outport')
  assign(inst+'__compute_done','element_done');assign(inst+'__clear','clear')
  assign(inst+'__recv_opt__msg','control')
  assign(inst+'__recv_opt__val','ctrl_mem__send_ctrl__val & ~'+inst+'_done')
assign('element__recv_opt__msg','control')
assign('element__recv_opt__val','ctrl_mem__send_ctrl__val & ~element_done')
assign('element__prologue_count_inport','ctrl_mem__prologue_count_outport_fu')
assign('fu_crossbar__prologue_count_inport','ctrl_mem__prologue_count_outport_fu_crossbar')
assign('ctrl_mem__send_ctrl__rdy','(element__recv_opt__rdy | element_done) & (routing_crossbar__recv_opt__rdy | routing_crossbar_done) & (fu_crossbar__recv_opt__rdy | fu_crossbar_done)')
assign('const_mem__ctrl_proceed','ctrl_mem__send_ctrl__rdy & ctrl_mem__send_ctrl__val')
assign('register_cluster__inport_ctrl_proceed','const_mem__ctrl_proceed')
assign('register_cluster__inport_opt','control');assign('register_cluster__clear','clear')
assign('clear',"!STREAMING && recv_from_controller_pkt__val && packet.payload.cmd==6'd2")
s.extend(['  for(genvar a=0;a<CTRL_DEPTH;a++) begin : prologue_rows',
'    for(genvar i=0;i<ROUTE_INPUTS;i++) begin : columns',
'      assign routing_crossbar__prologue_count_inport[a][i]=ctrl_mem__prologue_count_outport_routing_crossbar[a][i];',
'    end','  end',
'  for(genvar i=0;i<ROUTING_OUTPUTS;i++) begin : selection',
'    assign routing_crossbar__crossbar_outport[i]=control.routing_xbar_outport[i];',
'    assign fu_crossbar__crossbar_outport[i]=control.fu_xbar_outport[i];','  end',
'  for(genvar i=0;i<TILE_PORTS;i++) begin : physical_ports',
'    cgra_channel #(.WIDTH(DATA_BITS),.LATENCY(1)) input_channel (',
'      .clk(clk),.reset(reset),.clear(clear),',
'      .recv_msg(recv_data__msg[i]),.recv_val(recv_data__val[i]),.recv_rdy(recv_data__rdy[i]),',
'      .send_msg(routing_crossbar__recv_data__msg[i]),.send_val(routing_crossbar__recv_data__val[i]),.send_rdy(routing_crossbar__recv_data__rdy[i]));',
'    tile_link_or #(`CGRA_PROFILE_BIND) output_link (',
'      .clk(clk),.reset(reset),',
'      .recv_fu__msg(fu_crossbar__send_data__msg[i]),.recv_fu__val(fu_crossbar__send_data__val[i]),.recv_fu__rdy(fu_crossbar__send_data__rdy[i]),',
'      .recv_xbar__msg(routing_crossbar__send_data__msg[i]),.recv_xbar__val(routing_crossbar__send_data__val[i]),.recv_xbar__rdy(routing_crossbar__send_data__rdy[i]),',
'      .send__msg(send_data__msg[i]),.send__val(send_data__val[i]),.send__rdy(send_data__rdy[i]));','  end',
'  for(genvar i=0;i<4;i++) begin : operands'])
link('routing_crossbar__send_data','register_cluster__recv_data_from_routing_crossbar','[TILE_PORTS+i]','[i]')
link('fu_crossbar__send_data','register_cluster__recv_data_from_fu_crossbar','[TILE_PORTS+i]','[i]')
link('register_cluster__send_data_to_fu','element__recv_in','[i]','[i]')
assign('register_cluster__recv_data_from_const__msg[i]',"'0");assign('register_cluster__recv_data_from_const__val[i]',"1'b0")
s.append('    if(STREAMING) begin : no_register_routing')
assign('register_cluster__send_data_to_routing_crossbar__rdy[i]',"1'b0")
s.append('    end else begin : register_routing')
link('register_cluster__send_data_to_routing_crossbar','routing_crossbar__recv_data','[i]','[TILE_PORTS+i]')
s.extend(['    end','  end'])
link('element__send_out','fu_crossbar__recv_data','[1]','[1]')
assign('element__send_out__rdy[0]','fu_crossbar__recv_data__rdy[0]')
s.extend(['  if(STREAMING) begin : streaming_wiring',
'    assign element__ctrl_addr_inport=ctrl_mem__ctrl_addr_outport;',
'    assign fu_crossbar__recv_data__msg[0]=element__send_out__msg[0];',
'    assign fu_crossbar__recv_data__val[0]=element__send_out__val[0];',
'    // ac96 leaves const_mem.clear unconnected in this Tile variant.',
'  end else begin : context_wiring',
'    logic [DATA_BITS-1:0] overwrite_msg; logic overwrite_val;',
'    tile_context_switch #(`CGRA_PROFILE_BIND) context_switch (',
'      .clk(clk),.reset(reset),.recv_cmd(packet.payload.cmd),.recv_cmd_vld(recv_from_controller_pkt__val),',
'      .phi_addr(packet.payload.ctrl_addr),.recv_opt(control.operation),',
'      .progress_in(element__send_out__msg[0]),.progress_in_val(element__send_out__val[0]),',
'      .ctrl_mem_rd_addr(ctrl_mem__ctrl_addr_outport),',
'      .overwrite_fu_outport__msg(overwrite_msg),.overwrite_fu_outport__val(overwrite_val),.overwrite_fu_outport__rdy());',
'    assign fu_crossbar__recv_data__msg[0]=overwrite_val ? overwrite_msg : element__send_out__msg[0];',
'    assign fu_crossbar__recv_data__val[0]=overwrite_val | element__send_out__val[0];',
'    assign const_mem__clear=clear;',
'    // ac96 leaves element.ctrl_addr_inport and its raw packet input undriven.',
'  end',
'  for(genvar i=0;i<FU_COUNT;i++) begin : memory_slots',
'    localparam logic [7:0] KIND=FU_KINDS[8*i+:8];',
'    assign element__clear[i]=(!STREAMING && (KIND==`CGRA_FU_PHI || KIND==`CGRA_FU_RET)) ? clear : 1\'b0;',
'    if((STREAMING && KIND==`CGRA_FU_STREAMING_MEM) || (!STREAMING && KIND==`CGRA_FU_MEM)) begin : attached'])
for chan in ['to_mem_raddr','to_mem_waddr','to_mem_wdata']:
  for field in ['msg','val']:assign(chan+'__'+field,'element__'+chan+'__'+field+'[i]')
  assign('element__'+chan+'__rdy[i]',chan+'__rdy')
for field in ['msg','val']:assign('element__from_mem_rdata__'+field+'[i]','from_mem_rdata__'+field)
assign('from_mem_rdata__rdy','element__from_mem_rdata__rdy[i]')
s.append('    end else begin : detached')
for chan in ['to_mem_raddr','to_mem_waddr','to_mem_wdata']:assign('element__'+chan+'__rdy[i]',"1'b0")
for field in ['msg','val']:assign('element__from_mem_rdata__'+field+'[i]',"'0")
s.extend(['    end','  end',
'  logic accepted_command;',
'  always_comb begin',
'    case(packet.payload.cmd)',
'      6\'d0,6\'d3,6\'d4,6\'d5,6\'d6,6\'d7,6\'d8,6\'d20,6\'d21,6\'d23,6\'d24,6\'d25: accepted_command=1;',
'      6\'d1,6\'d2,6\'d9,6\'d15,6\'d16,6\'d22: accepted_command=!STREAMING;',
'      default: accepted_command=0;',
'    endcase',
'    ctrl_mem__recv_pkt_from_controller__msg=\'0;',
'    ctrl_mem__recv_pkt_from_controller__val=0;',
'    const_mem__recv_const__msg=\'0; const_mem__recv_const__val=0;',
'    recv_from_controller_pkt__rdy=0;',
'    if(recv_from_controller_pkt__val && accepted_command) begin',
'      ctrl_mem__recv_pkt_from_controller__msg=packet; ctrl_mem__recv_pkt_from_controller__val=1;',
'      recv_from_controller_pkt__rdy=ctrl_mem__recv_pkt_from_controller__rdy | (STREAMING && element__recv_pkt_from_controller__rdy);',
'    end else if(recv_from_controller_pkt__val && packet.payload.cmd==6\'d13) begin',
'      const_mem__recv_const__msg=packet.payload.data; const_mem__recv_const__val=1;',
'      recv_from_controller_pkt__rdy=const_mem__recv_const__rdy;',
'    end',
'  end',
'  if(STREAMING) begin : retained_packet',
'    // ac96 feed_pkt has no default assignment to these two signals.',
'    // Preserve its transparent retention; adding defaults would change behavior.',
'    always_latch if(recv_from_controller_pkt__val && accepted_command) begin',
'      element__recv_pkt_from_controller__msg=packet; element__recv_pkt_from_controller__val=1;',
'    end',
'  end',
'  assign send_to_controller_pkt__val=ctrl_mem__send_pkt_to_controller__val;',
'  assign send_to_controller_pkt__msg=ctrl_mem__send_pkt_to_controller__val ? ctrl_mem__send_pkt_to_controller__msg : \'0;',
'  assign ctrl_mem__send_pkt_to_controller__rdy=send_to_controller_pkt__rdy;',
'  always_ff @(posedge clk) begin',
'    if(reset || ctrl_mem__send_ctrl__rdy || clear) begin',
'      element_done<=0; routing_crossbar_done<=0; fu_crossbar_done<=0;',
'    end else begin',
'      if(element__recv_opt__rdy) element_done<=1;',
'      if(routing_crossbar__recv_opt__rdy) routing_crossbar_done<=STREAMING ? element_done : 1\'b1;',
'      if(fu_crossbar__recv_opt__rdy) fu_crossbar_done<=STREAMING ? element_done : 1\'b1;',
'    end',
'  end','endmodule'])
(OUT/'tile_variant_core.sv').write_text('\n'.join(s)+'\n',newline='\n')
for name,stream in [('tile_context',0),('tile_streaming',1)]:
  text='`include "cgra_profile_defs.svh"\n`include "cgra_fu_catalog.svh"\n'
  text+=f'module {name} #(`CGRA_PROFILE_PARAMETERS, `CGRA_FU_PARAMETERS) ('+header+'\n);\n'
  text+=f'  tile_variant_core #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND, .STREAMING({stream})) core (\n'
  text+=',\n'.join(f'    .{p}({p})' for p in ports)+'\n  );\nendmodule\n'
  (OUT/(name+'.sv')).write_text(text,newline='\n')
