"""One-time native array extension for FU selection and original Tile variants."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
text=(ROOT/'rtl/cgra/cgra_scalar.sv').read_text()
text=text.replace('`include "cgra_profile_defs.svh"','`include "cgra_profile_defs.svh"\n`include "cgra_fu_catalog.svh"')
text=text.replace('module cgra_scalar #(`CGRA_PROFILE_PARAMETERS)',
    'module cgra_programmable #(\n  `CGRA_PROFILE_PARAMETERS,\n  `CGRA_FU_PARAMETERS,\n  parameter int TILE_VARIANT=0\n)')
text=text.replace('[0:NUM_TILES-1][0:3]','[0:NUM_TILES-1][0:TILE_PORTS-1]')
text=text.replace('  initial begin','''  initial begin
    if(TILE_VARIANT<0 || TILE_VARIANT>2) $fatal(1,"Unknown Tile variant");
    if((TILE_VARIANT==2 && TILE_PORTS!=8) || (TILE_VARIANT!=2 && TILE_PORTS!=4))
      $fatal(1,"Supported profiles: base/context four ports; original streaming KingMesh eight ports");''',1)
instance=re.search(r'    tile_core #\(`CGRA_PROFILE_BIND\) tile \((.*?)\n    \);',text,re.S)
assert instance
connections=instance[1]
body=''
for i,module in enumerate(['tile_programmable','tile_context','tile_streaming']):
    body+=f'    {"if" if i==0 else "else if"}(TILE_VARIANT=={i}) begin : variant_{i}\n'
    body+=f'      {module} #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND) tile ('+connections+'\n      );\n    end\n'
text=text[:instance.start()]+body+text[instance.end():]
# The last two ends close the cardinal-port and Tile loops.
index=text.rfind('  end\nendmodule')
assert index!=-1
diagonals=r'''    if(TILE_PORTS==8) begin : king_mesh
      for(genvar d=4;d<8;d++) begin : diagonal
        localparam int DX=(d==4 || d==7) ? -1 : 1;
        localparam int DY=(d==4 || d==5) ? 1 : -1;
        localparam int OPP=d==4 ? 6 : d==5 ? 7 : d==6 ? 4 : 5;
        localparam int NEIGHBOR=t+DY*COLS+DX;
        localparam bit BOUNDARY=(X+DX<0 || X+DX>=COLS || Y+DY<0 || Y+DY>=ROWS);
        if(!BOUNDARY) begin : connected
          assign tile_recv_msg[t][d]=tile_send_msg[NEIGHBOR][OPP];
          assign tile_recv_val[t][d]=tile_send_val[NEIGHBOR][OPP];
          assign tile_send_rdy[t][d]=tile_recv_rdy[NEIGHBOR][OPP];
        end else begin : terminated
          // ac96 has no diagonal exterior interfaces; preserve its tie-offs.
          assign tile_recv_msg[t][d]='0;
          assign tile_recv_val[t][d]=0;
          assign tile_send_rdy[t][d]=0;
        end
      end
    end
'''
text=text[:index]+diagonals+text[index:]
text=text.replace('// Single-CGRA scalar mesh. All Tile, bank and control-ring instances are',
    '// Single-CGRA mesh/KingMesh with an ordered FU list and original Tile variants.\n// All Tile, bank and control-ring instances are')
(ROOT/'rtl/cgra/cgra_programmable.sv').write_text(text,newline='\n')
print('PROGRAMMABLE_CGRA_SCAFFOLD_PASS')
