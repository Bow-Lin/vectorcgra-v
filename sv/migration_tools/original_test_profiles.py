"""Explicit parameter/port correspondence for original-test SV replay."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
FU_NAMES = ('AdderRTL MulRTL MemUnitRTL NahRTL ConstRTL CompRTL LogicRTL '
            'ShifterRTL SelRTL PhiRTL GrantRTL GepRTL ExtractPredicateRTL '
            'RetRTL LoopCounterRTL LoopControlRTL DivRTL InclusiveDivRTL '
            'ExclusiveDivRTL VectorAdderComboRTL VectorMulComboRTL VectorAllReduceRTL '
            'SeqMulAdderRTL SeqMulShifterRTL PrlMulAdderRTL ThreeMulAdderShifterRTL '
            'FourIncCmpNotGrantRTL AluGenMacWrapperRTL FpAddRTL FpMulRTL').split()
FU_NAMES[27] = 'AluGenMacRTL'
FU_KINDS = {name: i for i, name in enumerate(FU_NAMES)}
FU_KINDS['StreamingMemUnitRTL'] = 32


def module_for(name):
  inventory = json.loads((ROOT/'sv/reference/current/inventory/inventory.json').read_text())
  candidates = [f for f in inventory['files'] if Path(f['source']).stem == name]
  assert len(candidates)==1, name
  path = next(ROOT/p for p in candidates[0]['targets'] if p.endswith('.sv'))
  return re.search(r'\bmodule\s+(\w+)', path.read_text())[1]


def payload_profile(payload):
  ctrl = payload.get_field_type('ctrl')
  fields = ctrl.__bitstruct_fields__
  data = payload.get_field_type('data')
  return dict(DATA_W=data.get_field_type('payload').nbits if hasattr(data,'get_field_type') else data.nbits,
              CTRL_DEPTH=1 << payload.get_field_type('ctrl_addr').nbits,
              GLOBAL_ADDR_W=payload.get_field_type('data_addr').nbits,
              REG_DEPTH=1 << fields['read_reg_idx'][0].nbits,
              TILE_PORTS=len(fields['routing_xbar_outport'])-len(fields['fu_in']))


def packet_profile(packet):
  p = payload_profile(packet.get_field_type('payload'))
  # Geometry below preserves the original packet field widths. System
  # constructors replace these representative dimensions with actual sizes.
  p.update(COLS=2, ROWS=2,
           MAX_COLS=(1 << packet.get_field_type('src').nbits)-1, MAX_ROWS=1,
           MULTI_COLS=1, MULTI_ROWS=1)
  shape = re.search(r'_(\d+)x(\d+)_', packet.__name__)
  if shape:
    p.update(MULTI_COLS=int(shape[1]), MULTI_ROWS=int(shape[2]))
  return p


def noc_profile(packet):
  p = payload_profile(packet.get_field_type('payload'))
  shape = re.search(r'_(\d+)x(\d+)_', packet.__name__)
  assert shape, packet.__name__
  p.update(COLS=2, ROWS=2, MULTI_COLS=int(shape[1]), MULTI_ROWS=int(shape[2]),
           MAX_COLS=(1 << packet.get_field_type('src_tile_id').nbits)-1, MAX_ROWS=1,
           MAX_MEM_PORTS=(1 << packet.get_field_type('remote_src_port').nbits)-1)
  return p


def address_maps(p, args):
  count=p['MULTI_COLS']*p['MULTI_ROWS']
  width=lambda n:max(1,(n-1).bit_length())
  mapping=args.get('controller2addr_map')
  if mapping:
    slots=sorted(mapping, key=lambda k:mapping[k][0])
    p.update(CUSTOM_ADDR_MAP=1, ADDR_MAP=packed(slots,width(count)))
  coords=args.get('idTo2d_map')
  if coords and len(coords)==count:
    p.update(CUSTOM_COORD_MAP=1,
             COORD_X_MAP=packed([coords[i][0] for i in range(count)],width(p['MULTI_COLS'])),
             COORD_Y_MAP=packed([coords[i][1] for i in range(count)],width(p['MULTI_ROWS'])))


def fu_list(names):
  names = [n.__name__ if not isinstance(n, str) else n for n in names]
  # FlexibleFuRTL appends Nah internally, preserving last-valid order.
  if 'NahRTL' not in names:
    names.append('NahRTL')
  kinds = [FU_KINDS[n] for n in names]
  value = sum(v << (8*i) for i, v in enumerate(kinds))
  return dict(FU_COUNT=len(kinds), FU_KINDS=f"{8*len(kinds)}'h{value:x}")


def packed(values, width):
  return f"{max(1,len(values))*width}'h{sum(int(v) << (width*i) for i,v in enumerate(values)):x}"


def array_profile(model, args):
  p = payload_profile(args['CgraPayloadType'])
  p.update(COLS=args.get('width', args.get('tile_columns', args.get('per_cgra_columns'))),
           ROWS=args.get('height', args.get('tile_rows', args.get('per_cgra_rows'))),
           MULTI_COLS=args.get('multi_cgra_columns', args.get('cgra_columns', 1)),
           MULTI_ROWS=args.get('multi_cgra_rows', args.get('cgra_rows', 1)),
           CTRL_DEPTH=args['ctrl_mem_size'], REG_DEPTH=args['num_registers_per_reg_bank'],
           BANK_DEPTH=args['data_mem_size_per_bank'], NUM_BANKS=args['num_banks_per_cgra'],
           NUM_CTRL=args['num_ctrl'], TOTAL_STEPS=args['total_steps'],
           MEM_COMBINATIONAL=int(args['mem_access_is_combinational']))
  p.update(fu_list(args['FuList']))
  address_maps(p,args)
  return p


def tile_fu_parameters(model, p):
  tiles = model.tile
  names = [[type(f).__name__ for f in tile.element.fu] for tile in tiles]
  slots = max(len(row) for row in names)
  p['FU_COUNT'] = slots
  p['FU_KINDS'] = packed([FU_KINDS[n] for n in names[0]], 8)
  p['TILE_FU_COUNTS'] = packed([len(row) for row in names], 32)
  p['TILE_FU_KINDS'] = packed([sum(FU_KINDS[n] << (8*i) for i,n in enumerate(row)) for row in names], slots*8)


def template_parameters(model, args, p):
  tiles, links = args['TileList'], args['LinkList']
  p['CUSTOM_TOPOLOGY'] = 1
  rd = [0xffffffff]*args['dataSPM'].numOfReadPorts
  wr = [0xffffffff]*args['dataSPM'].numOfWritePorts
  internal = []
  for link in links:
    if link.isFromMem():
      if not link.disabled:
        rd[link.getMemReadPort()] = link.dstTile.getIndex(tiles)
    elif link.isToMem():
      if not link.disabled:
        wr[link.getMemWritePort()] = link.srcTile.getIndex(tiles)
    else:
      internal.append((link.srcTile.getIndex(tiles),link.srcPort,
                       link.dstTile.getIndex(tiles),link.dstPort,int(not link.disabled)))
  p.update(MEM_PORTS=len(rd), MEM_WRITE_PORTS=len(wr), LINK_COUNT=max(1,len(internal)),
           READ_PORT_TILE=packed(rd,32), WRITE_PORT_TILE=packed(wr,32))
  for i,key in enumerate(['LINK_SRC_TILE','LINK_SRC_PORT','LINK_DST_TILE','LINK_DST_PORT','LINK_ENABLED']):
    p[key] = packed([row[i] for row in internal], 1 if i==4 else 32)
  ins=[];outs=[]
  for i,tile in enumerate(tiles):
    x,y=i%p['COLS'],i//p['COLS']
    directions=[d for d,active in [(0,y==p['ROWS']-1),(1,y==0),(2,x==0),(3,x==p['COLS']-1)] if active]
    ins.append(sum(1<<d for d in directions if d not in tile.getInvalidInPorts()))
    outs.append(sum(1<<d for d in directions if d not in tile.getInvalidOutPorts()))
  for i in range(len(tiles)):
    x,y=i%p['COLS'],i//p['COLS']
    if not args.get('is_multi_cgra'):
      ins[i]=outs[i]=0
    else:
      # CgraTemplateRTL explicitly connects west/south on inner CGRAs,
      # independent of the memory links' invalid-port marks.
      cid=args.get('cgra_id',0)
      for direction,boundary,neighbor in [(1,y==0,cid//p['MULTI_COLS']>0),
                                           (2,x==0,cid%p['MULTI_COLS']>0)]:
        if boundary:
          ins[i]=(ins[i]&~(1<<direction))|((1<<direction) if neighbor else 0)
          outs[i]=(outs[i]&~(1<<direction))|((1<<direction) if neighbor else 0)
  p['BOUNDARY_IN_ENABLE']=packed(ins,p['TILE_PORTS'])
  p['BOUNDARY_OUT_ENABLE']=packed(outs,p['TILE_PORTS'])
  tile_fu_parameters(model,p)


def normalized_type(dtype, meta):
  """Widen original 2-input ctrl records into the native four-bank ABI.

  Existing fields/indices are preserved; additional operands/banks are zero.
  This is layout adaptation only, never an opcode/program rewrite.
  """
  if not meta.get('normalize_ctrl') or not hasattr(dtype, '__bitstruct_fields__'):
    return dtype
  from pymtl3 import mk_bitstruct
  from VectorCGRA.lib.messages import mk_ctrl
  fields = dtype.__bitstruct_fields__
  if 'fu_in' in fields:
    p = meta['parameters']
    return mk_ctrl(4, 2, p['TILE_PORTS'], p['TILE_PORTS'], p['REG_DEPTH'])
  replaced = {n: normalized_type(t, meta) if not isinstance(t, list) else t for n, t in fields.items()}
  if all(replaced[n] == t for n, t in fields.items()):
    return dtype
  return mk_bitstruct('OriginalTest_'+dtype.__name__, replaced)


def repack(value, dtype):
  if type(value) is dtype:
    return value
  if not hasattr(dtype, '__bitstruct_fields__'):
    return dtype(int(value))
  result = dtype()
  for name, kind in dtype.__bitstruct_fields__.items():
    source = getattr(value, name)
    if isinstance(kind, list):
      assert len(source) <= len(kind), name
      target = getattr(result, name)
      for i, item in enumerate(source):
        target[i] = repack(item, kind[i])
    else:
      setattr(result, name, repack(source, kind))
  return result


def profile_for(model, args):
  name = type(model).__name__
  def profile(module, p, **extra):
    return dict(module=module, parameters=p, mode='native', bindings={}, **extra)
  if name == 'DmaEngineRTL':
    return profile('cgra_dma_engine', {v:args[k] for k,v in dict(spm_data_nbits='SPM_DATA_W',
      dram_data_nbits='DRAM_DATA_W',dram_addr_nbits='DRAM_ADDR_W',spm_addr_nbits='SPM_ADDR_W',
      bytes_nbits='BYTES_W',tag_nbits='TAG_W').items()})
  if name == 'Im2colEngineRTL':
    p=packet_profile(args['IntraCgraPktType'])
    p.update(SCRATCH_DEPTH=args['scratch_mem_size'],
      PRELOAD_IMAGE=packed([int(x.payload) if hasattr(x,'payload') else int(x) for x in args['preload_image']],p['DATA_W']))
    return profile('cgra_im2col_engine',p,normalize_ctrl=True,transaction_replay=True)
  if name in ['ControllerRTL','GlobalReduceUnitRTL','DataMemControllerRTL']:
    p=noc_profile(args.get('InterCgraPktType',args.get('NocPktType')))
    p.update(MULTI_COLS=args.get('multi_cgra_columns',p['MULTI_COLS']),
             MULTI_ROWS=args.get('multi_cgra_rows',p['MULTI_ROWS']),
             MAX_COLS=args.get('num_tiles',p['MAX_COLS']),
             HAS_DMA=int(args.get('has_dma_ports',False)), HAS_IM2COL=int(args.get('has_im2col_engine',False)))
    address_maps(p,args)
    if name=='ControllerRTL':
      spans={hi-lo+1 for lo,hi in args['controller2addr_map'].values()}
      assert len(spans)==1,'Controller requires uniform address slots'
      p.update(NUM_BANKS=1,BANK_DEPTH=spans.pop())
    if name=='DataMemControllerRTL':
      p.update(BANK_DEPTH=args['data_mem_size_per_bank'],NUM_BANKS=args['num_banks_per_cgra'],
               MEM_PORTS=args['num_rd_tiles'],MEM_WRITE_PORTS=args['num_wr_tiles'],
               MEM_COMBINATIONAL=int(args['mem_access_is_combinational']))
    return profile({'ControllerRTL':'cgra_controller','GlobalReduceUnitRTL':'cgra_global_reduce',
                    'DataMemControllerRTL':'cgra_data_memory'}[name],p,normalize_ctrl=True)
  if name=='DataMemWrapperRTL':
    rd,wr=args['MemReadType'],args['MemWriteType']
    bits=lambda field: rd.get_field_type(field).nbits
    p=dict(DATA_W=args['DataType'].get_field_type('payload').nbits,
      GLOBAL_ADDR_W=bits('addr'),BANK_DEPTH=args['per_bank_data_mem_size'],
      MEM_PORTS=(1<<bits('src'))-1,MEM_WRITE_PORTS=(1<<wr.get_field_type('src').nbits)-1,
      NUM_BANKS=(1<<bits('dst'))-1,MAX_MEM_PORTS=(1<<bits('remote_src_port'))-1,
      MULTI_COLS=1<<bits('src_cgra'),MULTI_ROWS=1,MAX_COLS=(1<<bits('src_tile'))-1,MAX_ROWS=1,
      MEM_COMBINATIONAL=int(args['is_combinational']))
    return profile('cgra_data_bank',p)
  if name in ['ChannelWithClearRTL','RegisterRTL']:
    p=dict(WIDTH=args.get('PacketType',args.get('DataType')).nbits,LATENCY=args['latency'])
    return profile('cgra_channel',p,single_underscore=True)
  if name=='RegFile':
    return profile('cgra_reg_file',dict(DATA_BITS=args['DataType'].nbits,DEPTH=args['nregs']))
  if name=='StaticSwitchUnitRTL':
    return profile('cgra_switch',dict(WIDTH=args['PacketType'].nbits,INPUTS=args['num_inports']),single_underscore=True)
  if name=='RingNetworkRTL':
    dtype=args['PacketType'];fields=dtype.__bitstruct_fields__;offset=0;offsets={}
    for key,t in reversed(list(fields.items())):
      offsets[key]=offset;offset+=t.nbits
    return profile('cgra_inter_ring',dict(WIDTH=dtype.nbits,NODES=args['num_routers'],
      DST_LSB=offsets['dst'],DST_WIDTH=fields['dst'].nbits,VC_LSB=offsets['vc_id'],
      VC_WIDTH=fields['vc_id'].nbits),single_underscore=True,transaction_replay=True)
  if name in ['LinkOrRTL','OrLinkRTL','SelectorRTL']:
    p=dict(DATA_W=args['DataType'].get_field_type('payload').nbits) if name!='SelectorRTL' else dict(DATA_BITS=args['DataType'].nbits)
    if name!='LinkOrRTL':p['NUM_INPUTS']=args['num_in_ports']
    return profile({'LinkOrRTL':'tile_link_or','OrLinkRTL':'cgra_or_link','SelectorRTL':'cgra_selector'}[name],p)
  if name=='CrossbarRTL':
    fields=args['CtrlType'].__bitstruct_fields__
    p=dict(DATA_W=args['DataType'].get_field_type('payload').nbits,CTRL_DEPTH=args['ctrl_mem_size'],
      REG_DEPTH=1<<fields['read_reg_idx'][0].nbits,TILE_PORTS=args['outport_towards_local_base_id'],
      INPUTS=args['num_inports'],MULTI_COLS=args['num_cgras'],MULTI_ROWS=1,MAX_COLS=args['num_tiles'],MAX_ROWS=1)
    return profile('tile_static_crossbar',p,normalize_ctrl=True)
  if name in ['RegisterBankRTL', 'RegisterClusterRTL']:
    ctrl = args.get('CtrlType', args.get('ConfigType'))
    data = args['DataType']
    fields = ctrl.__bitstruct_fields__
    assert len(fields['fu_in']) == 4
    params = dict(DATA_W=data.get_field_type('payload').nbits,
                  REG_DEPTH=args.get('num_registers', args.get('num_registers_per_reg_bank')),
                  TILE_PORTS=len(fields['routing_xbar_outport'])-4)
    if name == 'RegisterBankRTL':
      params['BANK_ID'] = args['reg_bank_id']
    else:
      assert args['num_reg_banks'] == 4
    return dict(module='register_bank' if name == 'RegisterBankRTL' else 'register_cluster',
                parameters=params, mode='native', bindings={})
  if name == 'ConstQueueDynamicRTL':
    return dict(module='const_queue', parameters=dict(DATA_W=args['DataType'].get_field_type('payload').nbits,
      CTRL_DEPTH=args['const_mem_size']), mode='native', bindings={})
  if name == 'ConstQueueRTL':
    words = args['const_list']
    bits = args['DataType'].nbits
    value = sum(int(v.to_bits()) << (i*bits) for i, v in enumerate(words))
    return dict(module='cgra_static_const_queue', parameters=dict(DATA_BITS=bits, NUM_CONST=len(words),
      CONST_WORDS=f"{bits*len(words)}'h{value:x}"), mode='native', bindings={})
  if name == 'ContextSwitchRTL':
    return dict(module='tile_context_switch', parameters=dict(DATA_W=args['data_nbits'],
      CTRL_DEPTH=1 << args['ctrl_addr_nbits']), mode='native', bindings={})
  if name.startswith('AluGenMacWrapperRTL'):
    return dict(module='cgra_alu_gen_mac', parameters={}, mode='native', bindings={})
  if name in ['VectorAdderRTL', 'VectorMulRTL']:
    p = packet_profile(args['CtrlPktType'])
    p['LANE_W'] = args['bw']
    return dict(module=module_for(name), parameters=p, mode='native', bindings={}, normalize_ctrl=True)
  if name in ['CtrlMemDynamicRTL', 'TileRTL', 'TileWithContextSwitchRTL', 'TileWithStreamingLoadRTL']:
    p = packet_profile(args['IntraCgraPktType'])
    p.update(CTRL_DEPTH=args['ctrl_mem_size'], NUM_CTRL=args.get('num_ctrl', args.get('ctrl_count_per_iter', 4)),
             TOTAL_STEPS=args.get('total_steps', args.get('total_ctrl_steps', 4)))
    if name == 'CtrlMemDynamicRTL':
      module = 'ctrl_mem'
    else:
      p.update(fu_list(args['FuList']))
      p['VARIANT'] = ['TileRTL', 'TileWithContextSwitchRTL', 'TileWithStreamingLoadRTL'].index(name)
      module = 'cgra_pe'
    return dict(module=module, parameters=p, mode='native', bindings={}, normalize_ctrl=True)
  if name in FU_KINDS:
    packet = args.get('CtrlPktType', args.get('IntraCgraPktType'))
    p = packet_profile(packet)
    module = 'tile_alu_gen_mac' if name=='AluGenMacRTL' else module_for(name)
    source = next(q for q in (ROOT/'sv/rtl').rglob('*.sv') if re.search(r'\bmodule\s+'+module+r'\b', q.read_text()))
    header = source.read_text().split(') (')[0]
    if 'VECTOR_FACTOR_POWER' in header:
      p['VECTOR_FACTOR_POWER'] = args.get('vector_factor_power', 0)
    for key, value in [('vector_factor_power','VECTOR_FACTOR_POWER'), ('num_lanes','LANES'),
                       ('exp_nbits','FP_EXP_W'), ('sig_nbits','FP_SIG_W'), ('latency','LATENCY')]:
      if key in args and re.search(r'\b'+value+r'\b', header):
        p[value] = args[key]
    return dict(module=module, parameters=p, mode='native', bindings={}, normalize_ctrl=True)
  if name == 'FlexibleFuRTL':
    p = packet_profile(args['CtrlPktType'])
    p.update(fu_list(args['FuList']))
    return dict(module='tile_flexible_fu_configurable', parameters=p, mode='native', bindings={}, normalize_ctrl=True)
  if name in ['CgraRTL','CgraWithContextSwitchRTL','CgraWithStreamingLoadRTL','IntegratedIm2ColWithCgraRTL']:
    p = array_profile(model,args)
    p['IS_MULTI'] = int(args.get('is_multi_cgra',False))
    if name=='CgraRTL' and not args.get('has_ctrl_ring',True):
      p['HAS_CTRL_RING']=0
    p['TILE_VARIANT'] = {'CgraWithContextSwitchRTL':1,'CgraWithStreamingLoadRTL':2}.get(name,0)
    core = model.cgra if name=='IntegratedIm2ColWithCgraRTL' else model
    tile_fu_parameters(core,p)
    module='cgra_system'
    if name=='IntegratedIm2ColWithCgraRTL':
      module='cgra_integrated_im2col'
      p['HAS_IM2COL']=1
      p['SCRATCH_DEPTH']=args['engine_scratch_mem_size']
      image=args['engine_preload_image']
      p['PRELOAD_IMAGE']=packed([int(x.payload) if hasattr(x,'payload') else int(x) for x in image],p['DATA_W'])
    return dict(module=module,parameters=p,mode='native',bindings={},normalize_ctrl=True,
                original_has_ctrl_ring=args.get('has_ctrl_ring',True),transaction_replay=True)
  if name in ['CgraTemplateRTL','IntegratedCgraWithDmaRTL']:
    p=array_profile(model,args)
    p['IS_MULTI']=int(args['is_multi_cgra'])
    core=model.cgra if name=='IntegratedCgraWithDmaRTL' else model
    template_parameters(core,args,p)
    module='cgra_system'
    if name=='IntegratedCgraWithDmaRTL':
      module='cgra_integrated_dma'
      p.update(HAS_DMA=1,DRAM_DATA_W=args['dram_data_nbits'])
    return dict(module=module,parameters=p,mode='native',bindings={},normalize_ctrl=True,transaction_replay=True)
  if name in ['MeshMultiCgraRTL','RingMultiCgraRTL']:
    p=array_profile(model,args)
    p.update(TOPOLOGY=int(name=='RingMultiCgraRTL'),
             TILE_VARIANT=int(args.get('support_task_switching',False)))
    return dict(module='cgra_multi',parameters=p,mode='native',bindings={},normalize_ctrl=True,transaction_replay=True)
  if name=='MeshMultiCgraTemplateRTL':
    import inspect
    local=[]
    for core in model.cgra:
      bound=inspect.signature(core.construct).bind(*core._dsl.args,**core._dsl.kwargs)
      bound.apply_defaults();a=bound.arguments
      p=array_profile(core,a);template_parameters(core,a,p);local.append(p)
    p=local[0].copy();n=len(local)
    mc=max(q['COLS'] for q in local);mr=max(q['ROWS'] for q in local);mt=mc*mr
    slots=max(q['FU_COUNT'] for q in local);links=max(q['LINK_COUNT'] for q in local)
    rd=max(q['MEM_PORTS'] for q in local);wr=max(q['MEM_WRITE_PORTS'] for q in local)
    assert len({q['CTRL_DEPTH'] for q in local})==1,'Per-CGRA control depths require separate native support'
    p.update(COLS=mc,ROWS=mr,MAX_COLS=mc,MAX_ROWS=mr,MEM_PORTS=rd,MAX_MEM_PORTS=rd,
      MEM_WRITE_PORTS=wr,FU_COUNT=slots,LINK_COUNT=links,CUSTOM_TOPOLOGY=(1<<n)-1,
      CGRA_COLS=packed([q['COLS'] for q in local],32),CGRA_ROWS=packed([q['ROWS'] for q in local],32))
    number=lambda s:int(s.split("'h")[1],16)
    for key,width in [('LINK_SRC_TILE',32*links),('LINK_SRC_PORT',32*links),('LINK_DST_TILE',32*links),
      ('LINK_DST_PORT',32*links),('LINK_ENABLED',links),('BOUNDARY_IN_ENABLE',mt*p['TILE_PORTS']),
      ('BOUNDARY_OUT_ENABLE',mt*p['TILE_PORTS']),('TILE_FU_COUNTS',mt*32)]:
      p[key]=packed([number(q[key]) for q in local],width)
    fus=[]
    for q in local:
      value=number(q['TILE_FU_KINDS']);old=q['FU_COUNT']*8
      fus.append(sum(((value>>(old*i))&((1<<old)-1))<<(slots*8*i) for i in range(q['COLS']*q['ROWS'])))
    p['TILE_FU_KINDS']=packed(fus,mt*slots*8)
    for key,width,countkey in [('READ_PORT_TILE',rd*32,'MEM_PORTS'),('WRITE_PORT_TILE',wr*32,'MEM_WRITE_PORTS')]:
      p[key]=packed([number(q[key])|(((1<<width)-1)^((1<<(q[countkey]*32))-1)) for q in local],width)
    return profile('cgra_multi_template',p,normalize_ctrl=True,transaction_replay=True)
  raise NotImplementedError('Original-test SV profile: '+name)
