"""One-time extension of the reviewed native Tile for an ordered FU list."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
text=(ROOT/'rtl/tile/tile_core.sv').read_text()
text=text.replace('module tile_core #(', 'module tile_programmable #(')
text=text.replace('`include "cgra_profile_defs.svh"', '`include "cgra_profile_defs.svh"\n`include "cgra_fu_catalog.svh"')
text=text.replace('`CGRA_PROFILE_PARAMETERS', '`CGRA_PROFILE_PARAMETERS,\n  `CGRA_FU_PARAMETERS',1)
text=text.replace('tile_flexible_fu #(`CGRA_PROFILE_BIND)', 'tile_flexible_fu_configurable #(`CGRA_PROFILE_BIND, `CGRA_FU_BIND)')
text=re.sub(r'(element__(?:clear|from_mem_\w+|to_mem_\w+)) \[0:3\]',r'\1 [0:FU_COUNT-1]',text)
text=re.sub(r'  assign element__clear\[\d+\] = 1\'d0;\n','',text)
start=text.index("  assign element__to_mem_raddr__rdy[0]")
end=text.index('\n',text.index("  assign element__to_mem_wdata__rdy[3]",start))
text=text[:start]+r'''  function automatic int memory_count();
    int count;
    count=0;
    for(int i=0;i<FU_COUNT;i++) if(FU_KINDS[8*i+:8]==`CGRA_FU_MEM) count++;
    return count;
  endfunction
  initial begin
    if(TILE_PORTS!=4) $fatal(1,"Base programmable Tile requires four mesh ports");
    if(memory_count()>1) $fatal(1,"Multiple MemUnit writers are not a legal ac96 Tile");
    for(int i=0;i<FU_COUNT;i++) if(FU_KINDS[8*i+:8]==`CGRA_FU_STREAMING_MEM)
      $fatal(1,"StreamingMem requires the streaming Tile variant");
  end
  for(genvar slot=0;slot<FU_COUNT;slot++) begin : memory_ports
    assign element__clear[slot]=1'b0;
    if(FU_KINDS[8*slot+:8]==`CGRA_FU_MEM) begin : memory
      assign to_mem_raddr__msg=element__to_mem_raddr__msg[slot];
      assign to_mem_raddr__val=element__to_mem_raddr__val[slot];
      assign element__to_mem_raddr__rdy[slot]=to_mem_raddr__rdy;
      assign element__from_mem_rdata__msg[slot]=from_mem_rdata__msg_typed;
      assign element__from_mem_rdata__val[slot]=from_mem_rdata__val;
      assign from_mem_rdata__rdy=element__from_mem_rdata__rdy[slot];
      assign to_mem_waddr__msg=element__to_mem_waddr__msg[slot];
      assign to_mem_waddr__val=element__to_mem_waddr__val[slot];
      assign element__to_mem_waddr__rdy[slot]=to_mem_waddr__rdy;
      assign to_mem_wdata__msg_typed=element__to_mem_wdata__msg[slot];
      assign to_mem_wdata__val=element__to_mem_wdata__val[slot];
      assign element__to_mem_wdata__rdy[slot]=to_mem_wdata__rdy;
    end else begin : unused_memory
      assign element__to_mem_raddr__rdy[slot]=0;
      assign element__from_mem_rdata__msg[slot]='0;
      assign element__from_mem_rdata__val[slot]=0;
      assign element__to_mem_waddr__rdy[slot]=0;
      assign element__to_mem_wdata__rdy[slot]=0;
    end
  end
  // With no memory FU, the corresponding Tile outputs remain undriven as in ac96.
'''+text[end:]
text=text.replace('// Native parameterized scalar profile; migrated from ac96 TileRTL.',
    '// Native ac96 TileRTL with an elaboration-time ordered FU catalog.')
(ROOT/'rtl/tile/tile_programmable.sv').write_text(text,newline='\n')
print('PROGRAMMABLE_TILE_SCAFFOLD_PASS')
