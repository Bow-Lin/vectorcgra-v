"""Inspect Verilator's elaborated cells, not the generated input table alone."""
import re
import gzip
from pathlib import Path
import xml.etree.ElementTree as ET

FU_MODULES = dict(ADDER='tile_adder',MUL='tile_multiplier',CONST='scalar_const',
                 MEM='tile_memory_fu',STREAMING_MEM='tile_streaming_memory_fu',NAH='tile_nah')


def audit(path, entry):
  path=Path(path)
  with (gzip.open(path,'rb') if path.suffix=='.gz' else path.open('rb')) as source:
    root = ET.parse(source).getroot()
  modules = {m.get('name'):m for m in root.findall('./netlist/module')}
  cells = root.findall('./cells//cell')
  pe_cells = [c for c in cells if modules[c.get('submodname')].get('origName')=='cgra_pe']
  expected = {(c,t) for c,a in enumerate(entry['normalized']['architectures'])
                   for t in range(a['cols']*a['rows'])}
  seen = set(); records = []
  for cell in pe_cells:
    hierarchy = cell.get('hier')
    cgra = re.search(r'cgras__BRA__(\d+)__KET__',hierarchy)
    c = int(cgra[1]) if cgra else 0
    t = int(re.search(r'tiles__BRA__(\d+)__KET__',hierarchy)[1])
    assert (c,t) in expected and (c,t) not in seen
    seen.add((c,t));module = modules[cell.get('submodname')]
    constants = {}
    for var in module.findall('var'):
      value = var.find('const')
      if var.get('param')=='true' and value is not None:
        literal = value.get('name'); match = re.fullmatch(r"\d+'s?h([0-9a-f]+)",literal)
        if match: constants[var.get('name')]=int(match[1],16)
    p = entry['normalized']['parameters']; a = entry['normalized']['architectures'][c]
    want = {k:p[k] for k in ['DATA_W','TILE_PORTS','REG_DEPTH','CTRL_DEPTH','BANK_DEPTH',
                             'NUM_BANKS','GLOBAL_ADDR_W','MEM_COMBINATIONAL']}
    want.update(COLS=a['cols'],ROWS=a['rows'],FU_COUNT=len(a['fu_names'][t]),
                VARIANT=['base','context','streaming'].index(entry['normalized']['variant']))
    assert all(constants.get(k)==v for k,v in want.items()), (hierarchy,constants,want)
    fus=[]
    for child in cell.findall('.//cell'):
      match = re.search(r'\.units__BRA__(\d+)__KET__\.kind_\w+\.fu$',child.get('hier'))
      if match:
        fus.append((int(match[1]),modules[child.get('submodname')].get('origName')))
    assert sorted(fus)==[(i,FU_MODULES[n]) for i,n in enumerate(a['fu_names'][t])], (c,t,fus)
    records.append(dict(cgra=c,tile=t,parameters=want,instantiated_fus=[n for _,n in sorted(fus)]))
  assert seen==expected, 'Missing or extra PE instances'
  return dict(status='passed',pe_count=len(seen),cells=records)
