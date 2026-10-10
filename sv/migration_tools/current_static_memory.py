"""Freeze static API behavior from pinned, unchanged project Python.

CtrlMem needs a type-only operation -> ctrl field-name adapter. It is not a
claim that the obsolete module accepts today's mk_ctrl type unmodified.
"""
import argparse
import contextlib
import hashlib
import importlib
import io
import json
from pathlib import Path
import random
import sys
import types

ROOT = Path(__file__).resolve().parents[2]
package = types.ModuleType('VectorCGRA')
package.__path__ = [str(ROOT)]
sys.modules['VectorCGRA'] = package
from pymtl3 import DefaultPassGroup, mk_bitstruct, mk_bits
from VectorCGRA.lib.messages import mk_ctrl, mk_data
from VectorCGRA.mem.ctrl.CtrlMemRTL import CtrlMemRTL
from VectorCGRA.mem.const.ConstQueueRTL import ConstQueueRTL


def digest(path):
  return hashlib.sha256(path.read_bytes()).hexdigest()


def packed(items):
  result = 0
  for value, width in items:
    result = (result << width) | int(value.to_bits() if hasattr(value, 'to_bits') else value)
  return result


def ctrl_type(bits, legacy=True):
  C = mk_ctrl(4, 2, 4, 2 if bits == 107 else 4)
  assert C.nbits == bits
  return mk_bitstruct('StaticCtrlLegacy'+str(bits),
    {'ctrl' if k == 'operation' else k: v for k, v in C.__bitstruct_fields__.items()}) if legacy else C


def write_trace(root, name, params, rows, source, notes):
  directory = root/name
  directory.mkdir(parents=True, exist_ok=True)
  (directory/'vectors.txt').write_text(''.join(f'{i:x} {o:x}\n' for i, o, _ in rows))
  (directory/'labels.json').write_text(json.dumps([label for _, _, label in rows], indent=2)+'\n')
  is_ctrl = 'CTRL_BITS' in params
  output_bits = params['CTRL_BITS']+3 if is_ctrl else params['DATA_BITS']+1
  input_bits = params['CTRL_BITS']+(params['DEPTH']-1).bit_length()+4 if is_ctrl else 2
  manifest = dict(parameters=params, cycles=len(rows), input_bits=input_bits,
    output_bits=output_bits, reset_samples=sum(i >> (input_bits-1) for i,_,_ in rows), notes=notes,
    python_target='cd7aad878915e389cecf8cc01ff6987d156bd019',
    source_sha256=digest(ROOT/source), generator_sha256=digest(Path(__file__)),
    vectors_sha256=digest(directory/'vectors.txt'))
  (directory/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
  print('STATIC_PYTHON_FROZEN', name, len(rows), flush=True)


def freeze_ctrl(root, name, bits, depth, count, total):
  C = ctrl_type(bits)
  m = CtrlMemRTL(C, depth, count, total)
  m.apply(DefaultPassGroup())
  aw = (depth-1).bit_length()
  rows = []
  rng = random.Random(25000+depth)
  def word(index):
    return C.from_bits(mk_bits(bits)(((index+1) << (bits-7)) | rng.getrandbits(bits-7)))
  def tick(label, addr=0, av=0, data=None, dv=0, ready=0, reset=0):
    m.reset @= reset
    m.recv_waddr.msg @= addr
    m.recv_waddr.val @= av
    m.recv_ctrl.msg @= C() if data is None else data
    m.recv_ctrl.val @= dv
    m.send_ctrl.rdy @= ready
    m.sim_eval_combinational()
    ins = packed([(m.reset,1),(m.recv_waddr.val,1),(m.recv_waddr.msg,aw),
                  (m.recv_ctrl.val,1),(m.recv_ctrl.msg,bits),(m.send_ctrl.rdy,1)])
    outs = packed([(m.recv_waddr.rdy,1),(m.recv_ctrl.rdy,1),
                   (m.send_ctrl.val,1),(m.send_ctrl.msg,bits)])
    rows.append((ins,outs,label))
    m.sim_tick()
  tick('power_on_reset', reset=1)
  tick('unpaired_address_lost', addr=0, av=1)
  tick('unpaired_data_lost', data=word(0), dv=1)
  for i in reversed(range(count)):
    tick('paired_program', addr=i, av=1, data=word(i), dv=1)
  for n in range(3): tick('accept_then_stall', ready=int(n != 1))
  # Reproduce budget exhaustion after only two accepted instructions.
  for n in range(total+3): tick('stalled_budget_exhaustion')
  assert int(m.send_ctrl.val) == 0
  for n in range(200):
    tick('mixed_reset_write_ready', addr=rng.randrange(depth), av=rng.randrange(2),
         data=C() if n%13 == 0 else word(n%31), dv=rng.randrange(2),
         ready=rng.randrange(2), reset=int(n%11 == 0))
  write_trace(root, name, dict(CTRL_BITS=bits,DEPTH=depth,COUNT_PER_ITER=count,TOTAL_STEPS=total),
    rows, 'mem/ctrl/CtrlMemRTL.py',
    ['Type-only adapter renames operation to ctrl; identical packed field layout.',
     'All outputs compared, including invalid messages and reset cycles.',
     'Budget expires under stall; reset is ignored; unpaired writes are lost.'])


def const_words(width, count, original=False):
  D = mk_data(width, 1)
  if original:
    return [D(x, 1) for x in (9,8,7)]
  return [D((1 << (width-1)) | (0x13579 + i*0x2468), i&1, (i>>1)&1, (i^1)&1)
          for i in range(count)]


def freeze_const(root, name, width, count, original=False):
  D = mk_data(width,1)
  values = const_words(width,count,original)
  m = ConstQueueRTL(D,values)
  m.apply(DefaultPassGroup())
  rows=[]
  for n in range(160):
    m.reset @= int(n in (0,1,19,20,77,131))
    m.send_const.rdy @= int(n%7 in (0,1,3,6))
    m.sim_eval_combinational()
    rows.append((packed([(m.reset,1),(m.send_const.rdy,1)]),
      packed([(m.send_const.val,1),(m.send_const.msg,D.nbits)]),'reset_stall_wrap:'+str(n)))
    m.sim_tick()
  write_trace(root,name,dict(DATA_BITS=D.nbits,NUM_CONST=count,
    CONST_WORDS_HEX=f'{sum(int(x.to_bits()) << (i*D.nbits) for i,x in enumerate(values)):x}'),
    rows,'mem/const/ConstQueueRTL.py',
    ['Unmodified static ROM; all message metadata, invalid and reset samples compared.'])


def failures(root):
  L = ctrl_type(119)
  def build_ctrl(C= L, depth=4, count=4, total=9, execute=False):
    m=CtrlMemRTL(C,depth,count,total)
    m.apply(DefaultPassGroup())
    m.sim_eval_combinational()
    if execute:
      m.recv_waddr.msg @= 0
      m.recv_waddr.val @= 1
      m.recv_ctrl.msg @= L.from_bits(mk_bits(119)(1 << 112))
      m.recv_ctrl.val @= 1
      m.send_ctrl.rdy @= 1
      m.sim_tick()
      m.sim_tick()
  cases = [
    ('modern_ctrl_field', lambda: build_ctrl(C=ctrl_type(119,False)), 'VarNotDeclaredError'),
    ('unlimited_steps', lambda: build_ctrl(total=0), 'AssertionError'),
    ('single_ctrl_slot', lambda: build_ctrl(depth=1,count=1), 'AssertionError'),
    ('empty_constants', lambda: ConstQueueRTL(mk_data(32,1),[]).apply(DefaultPassGroup()), 'AssertionError'),
    ('missing_constants', lambda: ConstQueueRTL(mk_data(32,1)).apply(DefaultPassGroup()), 'TypeError')]
  results=[]
  for name,fn,expected in cases:
    try:
      fn()
    except Exception as exc:
      assert type(exc).__name__ == expected, (name,type(exc),str(exc))
      # Remove absolute workspace paths from reproducible evidence.
      message=str(exc).replace(str(ROOT),'<ROOT>')
      results.append(dict(case=name,exception=expected,message=message))
    else:
      raise AssertionError('Expected original failure: '+name)
  build_ctrl(depth=8,count=2,execute=True)
  output=io.StringIO()
  with contextlib.redirect_stdout(output):
    importlib.import_module('VectorCGRA.mem.const.test.ConstQueueRTL_test').test_const_queue()
  (root/'original_const_test.txt').write_text(output.getvalue())
  (root/'python_boundaries.json').write_text(json.dumps(dict(failures=results,
    narrow_pc_zext='depth=8/count=2 executes: custom PyMTL type-form zext accepts narrower type',
    original_const_test='passed unmodified, original Source/Sink assertions active',
    deprecated_ctrl_tests='not collected: deprecated files use obsolete constructors; not claimed passed'),indent=2)+'\n')


def main():
  parser=argparse.ArgumentParser()
  parser.add_argument('--output-root',type=Path,default=ROOT/'sv/reference/current/static_memory')
  args=parser.parse_args()
  target=json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for path,expected in target['source_sha256'].items():
    assert digest(ROOT/path)==expected, 'Pinned Python modified: '+path
  for profile in [('ctrl_default',119,4,4,9),('ctrl_nonpower',107,3,3,7),('ctrl_subset',119,8,2,13)]:
    freeze_ctrl(args.output_root,*profile)
  for profile in [('const_original',16,3,True),('const_four',32,4,False),
                  ('const_wide',64,3,False),('const_single',32,1,False)]:
    freeze_const(args.output_root,*profile)
  failures(args.output_root)
  print('STATIC_PYTHON_BOUNDARIES_PASS original_sources',len(target['source_sha256']))


if __name__ == '__main__':
  main()
