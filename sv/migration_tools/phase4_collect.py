"""Close stage 4 and archive actual evidence; not used by runtime builds."""
import argparse,hashlib,json,re,subprocess,zipfile
from datetime import datetime,timezone
from pathlib import Path
SV=Path(__file__).resolve().parents[1]
ROOT=SV.parent
BASELINE='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
def git(*args):return subprocess.check_output(['git','-c','core.excludesFile=D:/work/VectorCGRA/.git/info/exclude',*args],cwd=ROOT,text=True).strip()
def banner(p,pattern):
  m=re.search(pattern,p.read_text(errors='replace'),re.M);assert m,(p,pattern)
  return m[0]
def validate_sources(d):
  count=0
  if isinstance(d,dict):
    for k,v in d.items():
      if k in ('source_sha256','consumed_source_sha256','profile_header_sha256','compiled_input_sha256','runtime_inputs_sha256','logs_sha256','compiled_metadata_sha256','historical_report_assets','sha256') and isinstance(v,dict):
        for name,digest in v.items():
          if isinstance(digest,str) and re.fullmatch('[0-9a-f]{64}',digest):
            p=SV/name
            assert p.is_file() and sha(p)==digest,('source mismatch',name)
            count+=1
      else:count+=validate_sources(v)
  elif isinstance(d,list):
    for v in d:count+=validate_sources(v)
  return count

def main():
  ap=argparse.ArgumentParser();ap.add_argument('--archive',action='store_true');args=ap.parse_args()
  changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')];assert not changed,changed
  report_paths=[
    'results/phase4-system-simulation.json','results/phase4-system-synthesis.json','results/phase4-reference-audit.json',
    'tests/phase4/noc/simulation_results.json','tests/phase4/noc/synthesis_results.json','tests/phase4/migration/results.json',
    'tests/phase4/memory/results.json','tests/phase4/memory/synthesis_results.json',
    'tests/phase4/peripheral/component-results.json','tests/phase4/peripheral/synthesis-results.json','tests/phase4/peripheral/system-synthesis-results.json',
    'tests/phase4/compatibility/results.json']
  reports={p:read(SV/p) for p in report_paths};verified=sum(validate_sources(d) for d in reports.values())
  systems=reports['results/phase4-system-simulation.json'];synth=reports['results/phase4-system-synthesis.json']
  assert systems['status']=='passed' and len(systems['profiles'])==5
  assert len(synth['profiles'])==5 and all(p['status']=='passed' and p['checks'][-1]==0 for p in synth['profiles'])
  compatibility=reports['tests/phase4/compatibility/results.json']
  assert compatibility['status']=='passed'
  audit=reports['results/phase4-reference-audit.json']
  assert audit['status']=='all_declared_hashes_resolved_and_matched' and not audit['unresolved'] and not audit['failures']
  for name in ['tests/phase4/noc/simulation_results.json','tests/phase4/noc/synthesis_results.json','tests/phase4/migration/results.json','tests/phase4/memory/results.json','tests/phase4/memory/synthesis_results.json']:
    assert reports[name]['status'] in ('pass','passed'),name
  peripheral=reports['tests/phase4/peripheral/component-results.json']['results']
  assert len(peripheral)==8 and all(p['status']=='passed' and not p['inputs_changed_after_verilator'] for p in peripheral)
  peripheral_synth=reports['tests/phase4/peripheral/system-synthesis-results.json']
  assert not peripheral_synth['source_changes_during_run']
  assert len(peripheral_synth['profiles'])==2 and all(p['exit_code']==0 and p['check_problem_counts'][-1]==0 for p in peripheral_synth['profiles'])
  assert len(reports['tests/phase4/noc/simulation_results.json']['profiles'])==9
  ns=reports['tests/phase4/noc/synthesis_results.json']['profiles']
  assert len(ns)==9 and all(p['status']=='pass' and p['final_problems']==0 and p['top_ports_preserved'] for p in ns)
  assert len(reports['tests/phase4/migration/results.json']['profiles'])==2
  assert reports['tests/phase4/memory/results.json']['label']=='r1w3'
  ps=reports['tests/phase4/peripheral/synthesis-results.json']['profiles']
  assert len(ps)==6 and all(p['exit_code']==0 and p['check_problem_counts'][-1]==0 for p in ps)
  result=dict(schema=1,status='passed',collected_utc=datetime.now(timezone.utc).isoformat(),baseline_commit=BASELINE,
    implementation_commit=git('rev-parse','c56d0c6'),validation_commit=git('rev-parse','HEAD'),branch=git('branch','--show-current'),
    original_python_modified=False,routine_project_python_required=False,
    area_measured=False,frequency_measured=False,phase5_status='deferred_pending_user_instruction',
    agents_created=[],agents_reused=['noc_contract (Bernoulli)','synth_tools (Socrates)','area_report (Boyle)'],
    verified_current_source_hash_records=verified,
    source_sha256={p.relative_to(SV).as_posix():sha(p) for p in sorted((SV/'rtl').rglob('*')) if p.is_file()},
    scope='Mesh/Ring multi-CGRA, heterogeneous static structures, memory mapping, dynamic FIR migration, global reduction, DMA/im2col',
    systems=systems['profiles'],component_reports={p:sha(SV/p) for p in report_paths},
    synthesis_profiles=synth['profiles'],noc_totals={k:reports['tests/phase4/noc/simulation_results.json'][k] for k in ['total_cycles','total_delivered','total_raw_compared_bits']},
    compatibility_report='tests/phase4/compatibility/results.json',
    limitations=['Finite two-state tests, not formal equivalence or proof for arbitrary programs/parameters.',
      'Baseline defects and source/translated-HDL discrepancies are retained and documented.',
      'Full synthesis and frontend structural checks are distinct; neither is standard-cell area/Fmax.',
      '64-Tile system compared to frozen translated HDL and independent expected results; no completed Python cycle trace.',
      'Stage 5 work is preserved on a separate draft branch and is excluded from this delivery.'])
  save(SV/'results/phase4-summary.json',result)
  print('PHASE4_SUMMARY_PASS source_hash_records='+str(verified))
  if not args.archive:return
  selected=set()
  for p in (SV/'build/phase4').rglob('*'):
    if not p.is_file():continue
    if p.suffix in ('.log','.ys','.sha256') or p.name.endswith('__verFiles.dat') or p.name in ('result.json','stat.json','generic-stat.json','top-interface.il','attempt.json','runtime-input-scope.txt','clean-rebuild-result.json','scope-audit.json'):
      selected.add(p)
  for p in (SV/'results').glob('phase4*.json'):
    if 'evidence' not in p.name:selected.add(p)
  selected.update((SV/'tests/phase4').rglob('*.json'))
  for name in list(compatibility['logs_sha256'])+list(compatibility['compiled_metadata_sha256']):selected.add(SV/name)
  for name in ['implementation-staging.json','validation-staging.json','scope-final-check.json']:
    p=SV/'build/phase4'/name
    if p.is_file():selected.add(p)
  for p in (SV/'build/phase2').rglob('*.log'):selected.add(p)
  for folder in ['build/phase3/system','build/phase3/scalar','build/phase3/vector_combo','build/phase3/tile_variants/context_switch','build/phase3/tile_variants/streaming_memory','build/phase3/tile_variants/cgra_context','build/phase3/tile_variants/cgra_streaming']:
    selected.update((SV/folder).rglob('*.log'))
    selected.update((SV/folder).rglob('*__verFiles.dat'))
  archive=SV/'results/phase4-evidence.zip';entries={}
  with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for p in sorted(selected):
      name=p.relative_to(SV).as_posix();data=p.read_bytes();output.writestr(name,data)
      entries[name]=dict(size=len(data),sha256=hashlib.sha256(data).hexdigest())
  with zipfile.ZipFile(archive) as z:
    assert set(z.namelist())==set(entries)
    for name,meta in entries.items():assert hashlib.sha256(z.read(name)).hexdigest()==meta['sha256'],name
  save(SV/'results/phase4-evidence-manifest.json',dict(archive=archive.name,size=archive.stat().st_size,sha256=sha(archive),entry_count=len(entries),entries=entries,readback_verified=True))
  print('PHASE4_ARCHIVE_PASS',len(entries),archive.stat().st_size,sha(archive))
if __name__=='__main__':main()
