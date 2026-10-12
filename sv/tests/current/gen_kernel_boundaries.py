#!/usr/bin/env python3
"""Independent integer math for bounded frozen kernel configurations; stdlib only."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('program', ROOT / 'sv/tools/cgra_program.py')
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)
MASK = (1 << 32) - 1

def sha(p):
  return hashlib.sha256(p.read_bytes()).hexdigest()

def repair_axpy(packets):
  """Return from store PE after retirement; route exit predicate 9->5->1->0."""
  changes=[]
  def control(tile, pc):
    return next(x['payload']['ctrl'] for x in packets if x['dst']==tile and x['payload']['cmd']==3 and x['payload']['ctrl_addr']==pc)
  def prologue(tile, pc, source, count):
    return dict(dst=tile,payload=dict(cmd=6,ctrl_addr=pc,data=dict(payload=count,predicate=1),
      ctrl=dict(routing_xbar_outport={'0':source})))
  c=control(9,1)
  assert c['operation']==64 and not any(c['fu_xbar_outport'])
  c['operation']=31; c['fu_xbar_outport'][1]=1
  # The old return's predicate now travels south instead of signaling the host.
  c=control(1,3)
  assert c['operation']==1 and not any(c['routing_xbar_outport'])
  c['routing_xbar_outport'][2]=1
  c=control(0,0)
  assert c['operation']==1 and not any(c['routing_xbar_outport'])
  c['operation']=64; c['fu_in']=[1,0,0,0]; c['routing_xbar_outport'][4]=4
  additions=[prologue(1,3,1,1),prologue(0,0,4,2)]
  for cmd in (4,5): additions.append(dict(dst=0,payload=dict(cmd=cmd,ctrl_addr=0,data=dict(payload=2,predicate=1))))
  # Tile 5 is unused in the original map. It relays predicates north->south.
  assert not any(x['dst']==5 for x in packets)
  additions.extend([dict(dst=5,payload=dict(cmd=8,data=dict(payload=5,predicate=1))),
                    dict(dst=5,payload=dict(cmd=7,data=dict(payload=90,predicate=1)))])
  for pc in range(5):
    additions.append(dict(dst=5,payload=dict(cmd=3,ctrl_addr=pc,ctrl=dict(operation=1,
      routing_xbar_outport={'1':1} if pc==2 else {}))))
  additions.extend([prologue(5,2,1,1),dict(dst=5,payload=dict(cmd=0))])
  # Configuration must precede each tile's LAUNCH, especially the new prologues.
  launches=[x for x in packets if x['payload']['cmd']==0]
  packets[:]=[x for x in packets if x['payload']['cmd']!=0]+additions+launches
  changes.append(dict(kind='store_ordered_return',return_tile_before=9,return_tile_after=0,
    predicate_route=[9,5,1,0],return_pc=0,return_prologue=2,
    reason='PC0 follows the previous PC4 STORE retirement; extra pipeline prologue aligns the first real store.'))
  return changes

def repair_gemv(packets):
  """Return at store PE after its STORE; use previously idle perimeter tiles."""
  def control(tile, pc):
    return next(x['payload']['ctrl'] for x in packets if x['dst']==tile and x['payload']['cmd']==3 and x['payload']['ctrl_addr']==pc)
  c=control(8,10)
  assert c['operation']==64 and not any(c['fu_xbar_outport'])
  c['operation']=31;c['fu_xbar_outport'][0]=1
  c=control(2,1)
  assert c['operation']==1 and not any(c['routing_xbar_outport'])
  c['operation']=64;c['fu_in']=[1,0,0,0];c['routing_xbar_outport'][4]=4
  additions=[]
  for cmd in (4,5): additions.append(dict(dst=2,payload=dict(cmd=cmd,ctrl_addr=1,data=dict(payload=1,predicate=1))))
  additions.append(dict(dst=2,payload=dict(cmd=6,ctrl_addr=1,data=dict(payload=1,predicate=1),ctrl=dict(routing_xbar_outport={'0':4}))))
  # Each relay executes a one-word routing loop; it has no mathematical FU work.
  # North/South/West/East port indices are 0/1/2/3, selectors are index+1.
  for tile,source,dest in [(12,2,3),(13,3,3),(14,3,3),(15,3,1),(11,1,1),(7,1,1),(3,1,2)]:
    assert not any(x['dst']==tile for x in packets)
    additions.extend([
      dict(dst=tile,payload=dict(cmd=8,data=dict(payload=1,predicate=1))),
      dict(dst=tile,payload=dict(cmd=7,data=dict(payload=196,predicate=1))),
      dict(dst=tile,payload=dict(cmd=3,ctrl_addr=0,ctrl=dict(operation=1,routing_xbar_outport={str(dest):source}))),
      dict(dst=tile,payload=dict(cmd=0))])
  launches=[x for x in packets if x['payload']['cmd']==0]
  packets[:]=[x for x in packets if x['payload']['cmd']!=0]+additions+launches
  return [dict(kind='store_ordered_return',return_tile_before=8,return_tile_after=2,
    predicate_route=[8,12,13,14,15,11,7,3,2],return_pc=1,return_prologue=1,
    reason='Return PC1 follows PC0 STORE retirement; idle perimeter relays avoid dependencies on the arithmetic path.')]

def prepare(kernel, out):
  source = ROOT / ('sv/reference/current/kernels/axpy' if kernel == 'axpy' else 'sv/reference/native/kernels/' + kernel)
  meta = json.loads((source / 'manifest.json').read_text())
  p = dict(P.configuration.DEFAULTS, **meta['parameters'])
  p.update(MAX_COLS=p['COLS'], MAX_ROWS=p['ROWS'], MEM_PORTS=p['COLS']+p['ROWS']-1,
           MEM_WRITE_PORTS=p['COLS']+p['ROWS']-1, MAX_MEM_PORTS=p['COLS']+p['ROWS']-1)
  schema = P.layouts(dict(parameters=p, widths=P.configuration.profile_widths(p)))['host']
  packets = [P.unpack(schema, int(s, 16)) for s in (source / 'program.hex').read_text().splitlines()]
  assert all(P.pack(schema, v) == int(s, 16) for v, s in zip(packets, (source/'program.hex').read_text().splitlines()))
  repairs = repair_axpy(packets) if kernel=='axpy' else repair_gemv(packets) if kernel=='gemv' else []
  ret = [x for x in packets if x['payload']['cmd'] == 3 and x['payload']['ctrl']['operation'] == 64]
  assert len(ret) == 1
  expected_return = P.unpack(schema, int(meta['expected_packets'][0] if kernel=='axpy' else meta['expected_return_packet'], 16))
  expected_return['payload']['ctrl'] = ret[0]['payload']['ctrl']
  expected_return['src'] = ret[0]['dst']
  # Ret's return packet preserves its ctrl word; no sampled RTL result is used.
  kinds = meta['fu_kinds']
  flags = [f'-G{k}={v}' for k,v in meta['parameters'].items()] + [f'-GFU_COUNT={len(kinds)}', f"-GFU_KINDS={8*len(kinds)}'h{sum(v<<(8*i) for i,v in enumerate(kinds)):x}"]
  (out / 'verilator.args').write_text('\n'.join(flags)+'\n')
  return source, p, schema, packets, expected_return, repairs

def values(kernel, n, pattern, count):
  mem = [(0x5a000000 + a*0x101) & MASK for a in range(count)]
  def val(i, salt=0):
    if pattern=='zero': return 0
    if pattern=='signed': return (-1 if (i+salt)%2 else 1)*(3*i+salt+1)
    if pattern=='wrap': return [0, 1, 0x7fffffff, 0x80000000, 0xffffffff, 0x40000001][(i+salt)%6]
    return i+1+salt
  if kernel=='axpy':
    mem[:16] = [10+i if pattern=='original' else val(i) for i in range(16)]
  elif kernel=='gemm':
    for i in range(n):
      for j in range(n):
        mem[i*n+j] = (i*(j+1))%17 if pattern=='original' else int(i==j) if pattern=='identity' else val(i*n+j)
        mem[16+i*n+j] = (i*(j+2))%19 if pattern=='original' else val(i*n+j,2)
        mem[32+i*n+j] = (i*j)%13 if pattern=='original' else val(i*n+j,4)
  else:
    for i in range(n):
      for j in range(n):
        mem[4*i+j] = 4*i+j+1 if pattern=='original' else int(i==j) if pattern=='identity' else val(i*n+j)
      mem[16+i] = i+1 if pattern=='original' else val(i,2)
  return [v & MASK for v in mem]

def oracle(kernel, memory, n, coefficient):
  # Computes from immutable input arrays, independent of packet order/RTL.
  result = memory[:]; counts = {}
  if kernel=='axpy':
    for i in range(n): result[i] = ((coefficient+1)*memory[i]) & MASK; counts[i]=1
  elif kernel=='gemm':
    for i in range(n):
      for j in range(n):
        a = 32+i*n+j
        result[a] = (memory[a] + sum(memory[i*n+k]*memory[16+k*n+j] for k in range(n))) & MASK
        counts[a] = n
  else:
    for i in range(n):
      result[20+i] = sum(memory[4*i+k]*memory[16+k] for k in range(n)) & MASK
      counts[20+i] = 1
  return result, counts

def main():
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output', type=Path, required=True)
  args=parser.parse_args()
  args.output.mkdir(parents=True, exist_ok=True)
  cases={
    'axpy': [(16,'original',3),(1,'signed',3),(2,'zero',3),(15,'wrap',3),(16,'signed',-2),(16,'wrap',0)],
    'gemm': [(4,'original',0),(1,'signed',0),(2,'identity',0),(3,'signed',0),(4,'zero',0),(4,'wrap',0)],
    'gemv': [(4,'original',0),(1,'signed',0),(2,'identity',0),(3,'signed',0),(4,'zero',0),(4,'wrap',0)],
  }
  manifests=[]
  for kernel, scenarios in cases.items():
    base=args.output/kernel; base.mkdir(exist_ok=True)
    source,p,schema,packets,ret,repairs=prepare(kernel,base)
    for n,pattern,coefficient in scenarios:
      label=f'n{n}_{pattern}'+(f'_a{coefficient}' if kernel=='axpy' else '')
      out=base/label; out.mkdir(exist_ok=True)
      memory=values(kernel,n,pattern,p['NUM_BANKS']*p['BANK_DEPTH'])
      expected,counts=oracle(kernel,memory,n,coefficient)
      program=[]
      for addr,value in enumerate(memory):
        program.append(dict(payload=dict(cmd=12,data=dict(payload=value,predicate=1),data_addr=addr)))
      edits=[]
      for original in packets:
        pkt=copy.deepcopy(original); payload=pkt['payload']; cmd=payload['cmd']
        if cmd==12: continue # Replace all host preloads with the complete independent memory image.
        if cmd==13:
          value=payload['data']['payload']
          if kernel=='axpy' and pkt['dst']==10 and value==16: payload['data']['payload']=n
          elif kernel=='axpy' and pkt['dst']==3 and value==3: payload['data']['payload']=coefficient & MASK
          elif kernel in ('gemm','gemv') and value==4: payload['data']['payload']=n
        if cmd==43 and kernel=='gemm': payload['data']['payload']=n
        if pkt!=original: edits.append(dict(tile=pkt['dst'],command=cmd,before=original['payload']['data']['payload'],after=payload['data']['payload']))
        program.append(pkt)
      files={'program.hex':''.join(f'{P.pack(schema,x):x}\n' for x in program),
             'return.hex':f'{P.pack(schema,ret):x}\n',
             'expected.hex':''.join(f'{a} {expected[a]:x}\n' for a in list(counts)+[i for i in range(len(expected)) if i not in counts]),
             'stores.txt':''.join(f'{a} {v}\n' for a,v in counts.items())}
      for name,text in files.items(): (out/name).write_text(text)
      row=dict(kernel=kernel,case=label,n=n,pattern=pattern,coefficient=coefficient if kernel=='axpy' else None,
        initial_memory=memory,expected_memory=expected,expected_stores=counts,configuration_changes=edits,program_repairs=repairs,
        input_files={str((source/f).relative_to(ROOT)):sha(source/f) for f in ['program.hex','manifest.json']},
        fixture_sha256={f:sha(out/f) for f in files},
        scope='Native math on bounded mapped programs; AXPY aliases x/y, GEMV row stride remains 4, GEMM row stride n. Not general DFG compilation or Python equivalence.')
      (out/'manifest.json').write_text(json.dumps(row,indent=2)+'\n'); manifests.append(row)
  (args.output/'cases.json').write_text(json.dumps(manifests,indent=2)+'\n')
  print(f'KERNEL_BOUNDARIES_GENERATED cases={len(manifests)}')

if __name__=='__main__': main()
