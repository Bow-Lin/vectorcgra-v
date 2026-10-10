"""Independent COO acceptance program, distinct from the broken SPMV YAML.

One programmable PE in a 2x2 fabric serializes 8 sparse entries. Repeated
rows test true read/modify/write dependencies. All arrays have distinct bases.
No original Python source, YAML or reference trace is modified.
"""
import hashlib
import json
from pathlib import Path
from native_kernels import ROOT, FIELDS, encode


def main():
  params = dict(COLS=2, ROWS=2, CTRL_DEPTH=64, GLOBAL_ADDR_W=8,
                BANK_DEPTH=32, NUM_BANKS=2, REG_DEPTH=8, NUM_CTRL=10,
                TOTAL_STEPS=80, MEM_COMBINATIONAL=1, MULTI_ROWS=1, MULTI_COLS=4)
  reg_width, ctrl_addr_width = 3, 6
  ctrl_width = sum(width * count for _, width, count in FIELDS(reg_width))
  payload_width = 6 + 35 + params['GLOBAL_ADDR_W'] + ctrl_width + ctrl_addr_width
  dst_shift = payload_width + 9 + 2 * (2 + 2 + 1)

  def packet(cmd, value=0, pred=0, address=0, control=0, pc=0):
    data = ((value & 0xffffffff) << 3) | (pred << 2)
    return ((cmd << (payload_width-6)) |
            (data << (params['GLOBAL_ADDR_W'] + ctrl_width + ctrl_addr_width)) |
            (address << (ctrl_width + ctrl_addr_width)) |
            (control << ctrl_addr_width) | pc)

  def control(op, operands=(), destination=None, retain=None):
    c = {name: [0] * count for name, _, count in FIELDS(reg_width)}
    c['op'] = [op]
    c['last'] = [1]
    for lane, bank in enumerate(operands):
      c['fu_in'][lane] = bank + 1
      c['read_src'][bank] = 1
    if destination is not None:
      c['write_src'][destination] = 2
      c['fu_out'][4+destination] = 1
    if retain is not None:
      assert destination != retain
      c['read_src'][retain] |= 2
      c['write_src'][retain] = 1
      c['route'][4+retain] = 5+retain
    return encode(c, reg_width)

  rows = [0, 1, 0, 3, 1, 2, 3, 0]
  columns = [1, 0, 2, 3, 2, 1, 0, 3]
  values = [2, 3, 4, 5, -1, 6, 7, 8]
  feature = [10, 20, 30, 40]
  initial = [1, 2, 3, 4]
  expected = initial.copy()
  for row, column, value in zip(rows, columns, values):
    expected[row] = (expected[row] + value * feature[column]) & 0xffffffff

  # Registers bank0=product/value, bank1=column/feature,
  # bank2=row/output address, bank3=old output.
  program = [control(28, destination=0),
             control(28, destination=1),
             control(25, (1,), 1),
             control(12, (1,), 1),
             control(7, (0, 1), 0),
             control(28, destination=2),
             control(25, (2,), 2),
             control(12, (2,), 3, retain=2),
             control(2, (0, 3), 0),
             control(13, (2, 0))]
  packets = []
  for base, data in [(0, rows), (8, columns), (16, values), (24, feature), (32, initial)]:
    packets.extend(packet(12, value, 1, base+i) for i, value in enumerate(data))
  for i in range(8):
    packets.extend(packet(13, value, 1) for value in (16+i, 8+i, 24, i, 32))
  packets.extend([packet(8, 10), packet(7, 80)])
  packets.extend(packet(3, control=c, pc=i) for i, c in enumerate(program))
  packets.append(packet(0))
  # One administrative completion, after all 80 control steps retire.
  expected_return = (4 << dst_shift) | packet(14)
  kinds = [0, 1, 2, 3]
  flags = [f'-G{k}={v}' for k,v in params.items()] + ['-GFU_COUNT=4', "-GFU_KINDS=32'h03020100"]
  files = {'program.hex': ''.join(f'{v:x}\n' for v in packets),
           'return.hex': f'{expected_return:x}\n',
           'expected.hex': ''.join(f'{32+i} {v:x}\n' for i,v in enumerate(expected)),
           'verilator.args': '\n'.join(flags)+'\n'}
  out = ROOT/'sv/reference/native/kernels/spmv_coo'
  out.mkdir(parents=True, exist_ok=True)
  for name, data in files.items():
    (out/name).write_text(data)
  manifest = dict(kernel='spmv_coo', status='native_candidate', parameters=params,
                  fu_kinds=kinds, rows=rows, columns=columns, values=values,
                  feature=feature, initial_output=initial,
                  expected_memory_base=32, expected_memory=expected,
                  completion='Tile 0 administrative completion after 80 retired steps',
                  claim='Independent native COO algorithm; not the original YAML program or Python equivalence',
                  fixture_sha256={name:hashlib.sha256(data.encode()).hexdigest() for name,data in files.items()})
  (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
  print('NATIVE_COO_GENERATED', expected)


if __name__ == '__main__':
  main()
