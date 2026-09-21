"""One-time source derivation of parameterized variant local modules.

The resulting SV is the maintained, Python-independent implementation.
This expands physical-port dimensions only; all ac96 update logic remains.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'sv/rtl/tile/variants'
OUT.mkdir(parents=True,exist_ok=True)

def put(name,text): (OUT/name).write_text(text,newline='\n')

s=(ROOT/'sv/rtl/mem/ctrl_mem.sv').read_text()
s=s.replace('module ctrl_mem #(','module tile_variant_ctrl_mem #(')
s=s.replace('[0:7]','[0:ROUTING_OUTPUTS-1]')
s=re.sub(r"localparam logic \[3:0\] (num_routing_\w+)  = 4'd8;",r'localparam int \1 = ROUTING_OUTPUTS;',s)
s=re.sub(r"4'\( (num_routing_\w+) \)",r'\1',s)
s=s.replace("[3'(i)]","[i]")
s=s.replace("[3'(tmp_update_prologue_reg_temp_routing_crossbar_in - 4'd1)]","[$clog2(ROUTING_OUTPUTS)'(tmp_update_prologue_reg_temp_routing_crossbar_in - 4'd1)]")
put('tile_variant_ctrl_mem.sv',s)

s=(ROOT/'sv/rtl/tile/tile_static_crossbar.sv').read_text()
s=s.replace('module tile_static_crossbar #(','module tile_variant_crossbar #(')
s=s.replace('[0:7]','[0:ROUTING_OUTPUTS-1]').replace('[7:0]','[ROUTING_OUTPUTS-1:0]')
s=s.replace('p<=7','p<ROUTING_OUTPUTS')
s=re.sub(r"localparam logic \[3:0\] (num_outports_\w+)  = 4'd8;",r'localparam int \1 = ROUTING_OUTPUTS;',s)
s=re.sub(r"4'\( (num_outports_\w+) \)",r'\1',s)
s=s.replace("localparam logic [2:0] outport_towards_local_base_id_at_update_rdy_vector  = 3'd4;",'localparam int outport_towards_local_base_id_at_update_rdy_vector = TILE_PORTS;')
s=s.replace("3'( outport_towards_local_base_id_at_update_rdy_vector )",'outport_towards_local_base_id_at_update_rdy_vector')
s=s.replace("8'd0","'0")
put('tile_variant_crossbar.sv',s)

s=(ROOT/'sv/rtl/mem/const_queue.sv').read_text()
s=s.replace('module const_queue #(','module tile_variant_const_queue #(')
s=s.replace('  `CGRA_PROFILE_PARAMETERS','  `CGRA_PROFILE_PARAMETERS,\n  parameter int CONST_DEPTH = CTRL_DEPTH,\n  localparam int CONST_ADDR_W = $clog2(CONST_DEPTH)')
head,body=s.split('  `include "cgra_profile.svh"',1)
body=body.replace('CTRL_DEPTH','CONST_DEPTH').replace('CTRL_ADDR_W','CONST_ADDR_W')
put('tile_variant_const_queue.sv',head+'  `include "cgra_profile.svh"'+body)
