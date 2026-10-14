"""Enumerate every constructor argument at the original PE/CGRA entry points."""
import argparse
import ast
from pathlib import Path

from common import ROOT, python_hashes, write_json

SOURCES = ['cgra/CgraRTL.py','cgra/CgraTemplateRTL.py','cgra/CgraWithContextSwitchRTL.py',
  'cgra/CgraWithStreamingLoadRTL.py','multi_cgra/MeshMultiCgraRTL.py',
  'multi_cgra/RingMultiCgraRTL.py','multi_cgra/MeshMultiCgraTemplateRTL.py',
  'tile/TileRTL.py','tile/TileWithContextSwitchRTL.py','tile/TileWithStreamingLoadRTL.py']

# Status describes expressibility, never a blanket equivalence result.
GROUPS = [
  ('CgraPayloadType IntraCgraPktType','DATA_W and derived cgra_profile ABI','limited',
   'Payload/control/address widths derived; predicate/bypass/delay fixed to one bit'),
  ('width per_cgra_columns tile_columns','COLS / CGRA_COLS','limited','Rectangular arrays with columns >= 2'),
  ('height per_cgra_rows tile_rows','ROWS / CGRA_ROWS','limited','Rectangular arrays with rows >= 2'),
  ('multi_cgra_columns cgra_columns','MULTI_COLS','limited','Ring >=2 columns; Mesh >=2 columns'),
  ('multi_cgra_rows cgra_rows','MULTI_ROWS','limited','Ring one row; Mesh >=2 rows'),
  ('ctrl_mem_size','CTRL_DEPTH','limited','Depth >=2; common depth at multi top'),
  ('data_mem_size_global data_mem_size','GLOBAL_ADDR_W','limited','Address width 1..32; arbitrary non-power-of-two capacity not mapped'),
  ('data_mem_size_per_bank','BANK_DEPTH','limited','Power of two >=2'),
  ('num_banks_per_cgra','NUM_BANKS','limited','Power of two >=1'),
  ('num_registers_per_reg_bank','REG_DEPTH','limited','Depth >=2'),
  ('num_ctrl','NUM_CTRL / CONFIG_COUNT_PER_ITER','limited','1..CTRL_DEPTH'),
  ('total_steps','TOTAL_STEPS / CONFIG_TOTAL_CTRL_COUNT','limited','Eleven-bit counter; command reachability per variant'),
  ('mem_access_is_combinational','MEM_COMBINATIONAL','represented','Both modes in identical 3x2 architecture'),
  ('FunctionUnit Fu','tile_flexible_fu_configurable','fixed_implementation','No arbitrary Python class substitution'),
  ('FuList','FU_COUNT/FU_KINDS and TILE_FU_*','limited','Ordered supported catalog; exactly one Nah; at most one memory FU'),
  ('cgra_topology per_cgra_topology','TILE_PORTS and LINK_*','limited','4/8 ports; Streaming eight'),
  ('controller2addr_map','CUSTOM_ADDR_MAP/ADDR_MAP','limited','Permutation of equal-sized memory windows'),
  ('idTo2d_map','CUSTOM_COORD_MAP/COORD_*','frontend_gap','Native direct parameters; no arbitrary coordinate map in JSON'),
  ('is_multi_cgra','IS_MULTI / top','represented','Single local loopback or multi external NoC'),
  ('has_ctrl_ring','HAS_CTRL_RING','frontend_gap','cgra_system only; no JSON key and no alternate transport'),
  ('has_im2col_engine','HAS_IM2COL / integrated wrapper','limited','Dedicated peripheral interface; not available at multi top'),
  ('has_dma_ports','HAS_DMA / integrated wrapper','limited','32-bit CGRA words; not available at multi top'),
  ('DmaDataType DmaCmdType','fixed peripheral ABI','limited','Not arbitrary message layouts'),
  ('TileList id2validTiles','COLS*ROWS and TILE_FU_*','limited','No arbitrary sparse tile deletion'),
  ('LinkList id2validLinks','CUSTOM_TOPOLOGY/LINK_*','limited','One source/destination per physical port'),
  ('dataSPM id2dataSPM','MEM_PORTS/MEM_WRITE_PORTS and READ/WRITE_PORT_TILE','limited','At most one read/write attachment per tile'),
  ('cgra_id','cgra_id input / multi instance index','represented','Physical node identity distinct from address-map slot'),
  ('provided_max_per_cgra_rows','MAX_ROWS','represented','Must contain local geometry'),
  ('provided_max_per_cgra_cols','MAX_COLS','represented','Must contain local geometry'),
  ('provided_max_num_rd_tiles','MAX_MEM_PORTS','represented','Shared response packet geometry'),
  ('provided_max_num_wr_tiles','MEM_WRITE_PORTS','limited','Common write capacity; no separate MAX_WRITE_PORTS parameter'),
  ('id2ctrlMemSize_map','common CTRL_DEPTH','frontend_and_top_gap','No per-CGRA control-depth array at maintained multi top'),
  ('id2cgraSize_map','CGRA_ROWS/CGRA_COLS','limited','Rectangles >=2x2; shared packet geometry'),
  ('support_task_switching','TILE_VARIANT / variant=context','represented','Context-specific commands and state still need dedicated acceptance'),
  ('num_fu_inports','four FU operands','fixed','No configurable operand count at public PE'),
  ('num_fu_outports','two FU results','fixed','No configurable result count at public PE'),
  ('num_tile_inports num_tile_outports','TILE_PORTS','limited','Equal input/output counts, 4/8 ports'),
  ('num_cgras','MULTI_COLS*MULTI_ROWS','derived','Packet geometry derived from system dimensions'),
  ('num_tiles','COLS*ROWS / MAX_TILES','derived','Local tile count and shared packet geometry are distinct'),
]


def inventory():
  pin=python_hashes();mapping={}
  for names,sv,status,note in GROUPS:
    for name in names.split():
      assert name not in mapping
      mapping[name]=dict(sv=sv,status=status,note=note)
  rows=[]
  for source in SOURCES:
    tree=ast.parse((ROOT/source).read_text())
    constructor=next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name=='construct')
    for argument in constructor.args.args[1:]:
      assert argument.arg in mapping, 'Unmapped original argument '+source+':'+argument.arg
      rows.append(dict(source=source,line=argument.lineno,argument=argument.arg,**mapping[argument.arg]))
  return dict(python_target=pin['python_target_commit'],entry_points=len(SOURCES),
    argument_occurrences=len(rows),rows=rows,
    note='Expressibility audit; represented/limited does not imply all parameter values were tested')


if __name__=='__main__':
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output',required=True,type=Path)
  args=parser.parse_args();value=inventory();write_json(args.output,value)
  print('PARAM_INVENTORY',value['entry_points'],'entry points',value['argument_occurrences'],'arguments')
