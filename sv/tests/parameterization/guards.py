"""Check that malformed architecture/acceptance inputs cannot claim success."""
import argparse
import copy
import json
from pathlib import Path
import tempfile
import shutil

from common import configuration, program, write_json
from generate import matrix
from oracle import check


def main():
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--output',required=True,type=Path)
  args=parser.parse_args();root=args.output
  profiles=matrix(); records=[]
  original=profiles['rect_3x2_comb']['config']
  invalid=[]
  d=copy.deepcopy(original);d['architectures'][0]['cols']=1;invalid.append(('minimum_shape',d))
  d=copy.deepcopy(original);d['parameters']['REG_DEPTH']=1;invalid.append(('minimum_registers',d))
  d=copy.deepcopy(original);d['parameters']['CTRL_DEPTH']=1;invalid.append(('minimum_control',d))
  d=copy.deepcopy(original);d['parameters']['NUM_BANKS']=3;invalid.append(('non_power_of_two_banks',d))
  d=copy.deepcopy(original);d['default_fus']=['ADDER','MEM'];invalid.append(('missing_nah',d))
  d=copy.deepcopy(original);d['parameters']['DATA_W']=64;d['parameters']['HAS_DMA']=1;invalid.append(('dma_word_width',d))
  d=copy.deepcopy(original);d['architectures'][0]['links']=[dict(src=0,dst=1,sp=3,dp=2)]*2;invalid.append(('shared_link_port',d))
  d=copy.deepcopy(original);d['architectures'][0]['fu_names']=[['ADDER','NAH']];invalid.append(('missing_tile_catalogs',d))
  for name,document in invalid:
    try: configuration.normalize(document)
    except configuration.ConfigError as exc: records.append(dict(name=name,rejected=True,reason=str(exc)))
    else: raise AssertionError('Invalid architecture accepted: '+name)
  # This remains an explicitly recorded frontend gap, not a failed-mode PASS.
  d=copy.deepcopy(original);d['parameters']['HAS_CTRL_RING']=0
  try: configuration.normalize(d)
  except configuration.ConfigError as exc: frontend_gap=str(exc)
  else: raise AssertionError('Update the documented HAS_CTRL_RING frontend status')
  folder=root/'base_2x2';entry=json.loads((folder/'architecture.json').read_text())
  case=folder/'add_23';spec=json.loads((case/'specification.json').read_text())
  lines=(case/'trace_37.txt').read_text().splitlines()
  layout=program.layouts(entry['normalized'])['host']
  completion=next(i for i,line in enumerate(lines) if line.startswith('H ') and
                 program.unpack(layout,int(line.split()[2],16))['payload']['cmd']==14)
  read=next(i for i,line in enumerate(lines) if line.startswith('H ') and
            program.unpack(layout,int(line.split()[2],16))['payload']['cmd']==11)
  traces={'missing_completion':lines[:completion]+lines[completion+1:],
          'duplicate_completion':lines+[lines[completion]],
          'missing_memory_word':lines[:read]+lines[read+1:],
          'empty_trace':[]}
  changed=lines[:];fields=changed[read].split();packet=program.unpack(layout,int(fields[2],16))
  packet['payload']['data']['payload']^=1;fields[2]=f'{program.pack(layout,packet):x}';changed[read]=' '.join(fields)
  traces['wrong_memory_word']=changed
  with tempfile.TemporaryDirectory(dir=root,prefix='guard-') as temp:
    for name,trace in traces.items():
      path=Path(temp)/'trace.txt';path.write_text('\n'.join(trace)+'\n' if trace else '')
      try: check(entry,spec,path)
      except AssertionError as exc: records.append(dict(name=name,rejected=True,reason=str(exc)))
      else: raise AssertionError('Corrupt trace accepted: '+name)
    from run import reference
    cached=Path(temp)/'cached';cached.mkdir()
    shutil.copyfile(folder/'architecture.json',cached/'architecture.json')
    clone=cached/'add_23';clone.mkdir()
    for filename in ['program.hex','specification.json','python_result.json','python_trace.txt','trace_37.txt']:
      shutil.copyfile(case/filename,clone/filename)
    result=reference(cached,entry,'add','/bin/false',{})
    assert result['exit_code']==0 and result['cached']
    records.append(dict(name='matching_reference_revalidated',accepted=True))
    (clone/'python_trace.txt').write_text((clone/'python_trace.txt').read_text()+'\n')
    try: reference(cached,entry,'add','/bin/false',{})
    except AssertionError:records.append(dict(name='corrupt_reference_hash',rejected=True))
    else:raise AssertionError('Corrupted cached Python trace accepted')
    shutil.copyfile(case/'python_trace.txt',clone/'python_trace.txt')
    original_record=json.loads((clone/'python_result.json').read_text())
    failed=dict(original_record,status='failed');write_json(clone/'python_result.json',failed)
    result=reference(cached,entry,'add','/bin/false',{})
    assert result['exit_code']!=0 and result['result']['status']=='failed' and not result.get('cached')
    records.append(dict(name='failed_reference_not_reused',rejected=True))
    write_json(clone/'python_result.json',dict(original_record,schedule=0))
    result=reference(cached,entry,'add','/bin/false',{})
    assert result['exit_code']!=0 and result['result']['status']=='failed' and not result.get('cached')
    records.append(dict(name='different_reference_schedule_not_reused',rejected=True))
    write_json(clone/'python_result.json',original_record)
    (clone/'program.hex').write_text((clone/'program.hex').read_text()+'\n')
    result=reference(cached,entry,'add','/bin/false',{})
    assert result['exit_code']!=0 and result['result']['status']=='failed' and not result.get('cached')
    records.append(dict(name='changed_program_and_stale_pass_not_reused',rejected=True))
  result=dict(status='passed',checks=records,frontend_gaps=dict(HAS_CTRL_RING=frontend_gap))
  write_json(root/'guards.json',result);print('PARAM_GUARDS_PASS',len(records))


if __name__=='__main__':main()
