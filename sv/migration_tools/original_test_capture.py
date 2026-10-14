"""Capture original test stimuli with original assertions left active.

This migration-only tool imports the pinned Python design. Native replay does
not. A failed Python test is always recorded as failed, even if it produced a
usable trace. Capture hooks observe settled ports immediately before each
clock edge, including the original sim_reset edges.
"""
import argparse
import contextlib
import hashlib
import importlib
import inspect
import json
from pathlib import Path
import re
import signal
import sys
import traceback
import types

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from original_test_profiles import profile_for, normalized_type, repack


def digest(path):
  return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def ports(model):
  from pymtl3 import InPort, OutPort, Interface
  result = []
  def walk(obj, path):
    if isinstance(obj, (InPort, OutPort)):
      if path != 'clk':
        result.append((path, obj._dsl.Type, 'input' if isinstance(obj, InPort) else 'output'))
    elif isinstance(obj, list):
      for i, item in enumerate(obj):
        walk(item, f'{path}[{i}]')
    elif isinstance(obj, Interface) or obj is model:
      for name, value in vars(obj).items():
        if not name.startswith('_'):
          walk(value, f'{path}.{name}' if path else name)
  walk(model, '')
  return sorted(result)


def get(model, path):
  obj = model
  for name, index in re.findall(r'([A-Za-z_]\w*)|\[(\d+)\]', path):
    obj = obj[int(index)] if index else getattr(obj, name)
  return obj


def sv_name(path):
  indexes = re.findall(r'\[\d+\]', path)
  return re.sub(r'\[\d+\]', '', path).replace('.', '__') + ''.join(indexes)


def serial(value):
  if isinstance(value, (str, int, float, bool)) or value is None:
    return value
  if isinstance(value, (list, tuple)):
    return [serial(x) for x in value]
  if isinstance(value, dict):
    return {str(k): serial(v) for k, v in value.items()}
  if hasattr(value, '__name__'):
    return value.__name__
  if hasattr(value, 'to_bits'):
    return int(value.to_bits())
  return repr(value)


class Capture:
  def __init__(self, model, directory):
    self.model = model
    self.directory = directory
    directory.mkdir(parents=True, exist_ok=True)
    args = inspect.signature(model.construct).bind(*model._dsl.args, **model._dsl.kwargs)
    args.apply_defaults()
    self.meta = dict(python_class=type(model).__name__, arguments=serial(args.arguments),
                     hierarchy=repr(model), samples=0, edges=0)
    self.meta.update(profile_for(model, args.arguments))
    self.layout = ports(model)
    if type(model).__name__=='StaticSwitchUnitRTL':
      # These three internal values are explicitly asserted by the original
      # differential test, so port-only replay would omit part of its contract.
      observed={'encoder.out':'selected','arbiter.grants':'grants',
                'arbiter.priority_reg.out':'arbiter.priority_state'}
      self.meta['switch_observables']={sv_name(path):target for path,target in observed.items()}
      for path in observed:
        self.layout.append((path,get(model,path)._dsl.Type,'output'))
    self.types = [normalized_type(t, self.meta) for p, t, d in self.layout]
    self.meta['ports'] = [dict(path=p, name=sv_name(p), width=n.nbits,
                               original_width=t.nbits, direction=d)
                          for (p, t, d), n in zip(self.layout, self.types)]
    self.file = (directory/'vectors.txt').open('w')
    self.last_edge = -1
    self.save()

  def save(self):
    (self.directory/'manifest.json').write_text(json.dumps(self.meta, indent=2)+'\n')

  def sample(self, edge=1):
    if self.meta['python_class']=='IntegratedCgraWithDmaRTL' and not self.model.reset and self.model.recv_from_cpu_pkt.val and 'memory_setup' not in self.meta:
      self.meta['memory_setup']=self.memory_snapshot()
    values = []
    for (path, dtype, direction), native_type in zip(self.layout, self.types):
      value = repack(get(self.model, path), native_type)
      values.append(int(value.to_bits() if hasattr(value, 'to_bits') else value))
    self.file.write(str(edge)+' '+' '.join(f'{v:x}' for v in values)+'\n')
    self.meta['samples'] += 1
    self.meta['edges'] += edge
    if self.meta['samples'] % 100 == 0:
      self.file.flush()
      self.save()

  def close(self):
    if self.meta['python_class']=='IntegratedCgraWithDmaRTL':
      self.meta['memory_final']=self.memory_snapshot()
    self.file.close()
    self.meta['vectors_sha256'] = digest(self.directory/'vectors.txt')
    self.save()

  def memory_snapshot(self):
    return [[int(v.to_bits()) for v in bank.memory.regs]
            for bank in self.model.cgra.data_mem.memory_wrapper]


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--case', type=Path, required=True)
  parser.add_argument('--output', type=Path, required=True)
  parser.add_argument('--wall-seconds', type=int, default=1800)
  args = parser.parse_args()
  args.output.mkdir(parents=True, exist_ok=True)
  case = json.loads(args.case.read_text())
  target = json.loads((ROOT/'sv/reference/current/target.json').read_text())
  for name, expected in target['source_sha256'].items():
    assert digest(ROOT/name) == expected, name
  package = types.ModuleType('VectorCGRA')
  package.__path__ = [str(ROOT)]
  sys.modules['VectorCGRA'] = package
  from pymtl3.passes.sim.PrepareSimPass import PrepareSimPass
  captures = []
  adapter_errors=[]
  original_prepare = PrepareSimPass.__call__
  original_ff = PrepareSimPass.collect_ff_funcs
  model_captures = {}
  captured_tops=[]
  def prepare(instance, top):
    models = sorted(top.get_all_components(), key=lambda m: (repr(m).count('.'), repr(m)))
    selected = []
    for model in models:
      if not any(type(model).__name__==c or type(model).__name__.startswith(c+'_') for c in case['classes']):
        continue
      if any(repr(model).startswith(repr(parent)+'.') for parent in selected):
        continue
      selected.append(model)
    current = []
    for model in selected:
      try:
        capture = Capture(model, args.output/f'dut{len(captures):03d}')
      except Exception as error:
        adapter_errors.append(dict(hierarchy=repr(model),error=repr(error),traceback=traceback.format_exc()))
        (args.output/'adapter_errors.json').write_text(json.dumps(adapter_errors,indent=2)+'\n')
        continue
      captures.append(capture)
      current.append(capture)
    model_captures[id(top)] = current
    if current:captured_tops.append(top)
    original_prepare(instance, top)
    original_eval = top.sim_eval_combinational
    def evaluate():
      original_eval()
      for capture in current:
        capture.sample(0)
    top.sim_eval_combinational = evaluate
  def ff(instance, top):
    def sample():
      for capture in model_captures.get(id(top), []):
        capture.sample(1)
    return [sample] + original_ff(instance, top)
  PrepareSimPass.__call__ = prepare
  PrepareSimPass.collect_ff_funcs = ff
  if case.get('kind')=='elaboration':
    from pymtl3.passes.backends.verilog import VerilogTranslationPass
    original_translate=VerilogTranslationPass.__call__
    def translate(instance,top):
      original_translate(instance,top)
      for model in sorted(top.get_all_components(),key=repr):
        if type(model).__name__ in case['classes']:
          capture=Capture(model,args.output/f'dut{len(captures):03d}')
          capture.meta['elaboration_only']=True
          captures.append(capture)
    VerilogTranslationPass.__call__=translate
  result = dict(case=case, status='running', source_sha256=target['source_sha256'][case['file']],
                python_target=target['python_target_commit'], source_files_checked=len(target['source_sha256']))
  (args.output/'result.json').write_text(json.dumps(result, indent=2)+'\n')
  def timeout(signum, frame):
    raise TimeoutError(f'Original test exceeded {args.wall_seconds} seconds')
  signal.signal(signal.SIGALRM, timeout)
  signal.alarm(args.wall_seconds)
  try:
    with (args.output/'python.log').open('w') as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
      module = importlib.import_module('VectorCGRA.'+case['file'][:-3].replace('/', '.'))
      func = module
      for name in case['function'].replace('::','.').split('.'):
        func = getattr(func, name)
        if inspect.isclass(func):
          func = func()
      kwargs = dict(case.get('parameters', {}))
      import pytest
      monkeypatch=pytest.MonkeyPatch()
      if 'tmp_path' in inspect.signature(func).parameters:
        kwargs['tmp_path']=Path.cwd()
      if 'monkeypatch' in inspect.signature(func).parameters:
        kwargs['monkeypatch']=monkeypatch
      if 'cmdline_opts' in inspect.signature(func).parameters:
        kwargs['cmdline_opts'] = dict(test_verilog='', test_yosys_verilog='', dump_textwave=False,
                                    dump_vcd='', dump_vtb='', max_cycles=None)
      func(**kwargs)
      if case.get('require_sink_completion'):
        assert len(captured_tops)==1
        top=captured_tops[0];sink=get(top,case['require_sink_completion'])
        sink_args=inspect.signature(sink.construct).bind(*sink._dsl.args,**sink._dsl.kwargs)
        sink_args.apply_defaults()
        messages=sink_args.arguments['msgs']
        capture=captures[0]
        dtype=next(t for (path,_,_),t in zip(capture.layout,capture.types) if path=='send_to_cpu_pkt.msg')
        capture.meta['required_output_words']={'send_to_cpu_pkt':[int(repack(x,dtype).to_bits()) for x in messages]}
        result['original_function_status']='passed'
        for _ in range(case['completion_cycles']):
          if sink.done():break
          top.sim_tick()
        else:raise AssertionError('Supplemented completion check timed out; original test only waited for configuration source')
      monkeypatch.undo()
    result['status'] = 'passed'
  except BaseException as error:
    result.update(status='failed', error=repr(error), traceback=traceback.format_exc())
  finally:
    signal.alarm(0)
    for capture in captures:
      capture.close()
    result['captures'] = [str(c.directory.relative_to(args.output)) for c in captures]
    result['adapter_errors']=adapter_errors
    if result['status']=='passed' and adapter_errors:
      result['status']='adapter_failed'
    if result['status']=='passed' and not captures:
      result.update(status='adapter_failed',error='No selected DUT was captured')
    for name, expected in target['source_sha256'].items():
      assert digest(ROOT/name) == expected, name
    (args.output/'result.json').write_text(json.dumps(result, indent=2)+'\n')
  print(json.dumps({k: result[k] for k in ['status', 'captures']}, sort_keys=True))
  return int(result['status'] != 'passed')


if __name__ == '__main__':
  sys.exit(main())
