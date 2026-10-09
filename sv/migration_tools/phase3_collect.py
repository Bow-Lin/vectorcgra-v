"""Archive completed stage-3 evidence; not required for daily HDL builds."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

SV=Path(__file__).resolve().parents[1]
ROOT=SV.parent
BASELINE='ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b'
IMPLEMENTATION='d71a2bb69b8f0fe22fc1d1bd29562ea4ed9df9c1'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path,data): path.write_text(json.dumps(data,indent=2)+'\n',newline='\n')
def git(*args): return subprocess.check_output(['git','-c','core.excludesFile=D:/work/VectorCGRA/.git/info/exclude',*args],cwd=ROOT,text=True).strip()
def log_banner(path,pattern):
    match=re.search(pattern,path.read_text(errors='replace'))
    assert match, (path,pattern)
    return match[0]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive',action='store_true')
    args=parser.parse_args()
    changed=[p for p in git('diff','--name-only',BASELINE,'--','*.py').splitlines() if not p.startswith('sv/')]
    assert not changed,changed
    scalar=read(SV/'results/phase3-scalar.json')
    fp=read(SV/'results/phase3-float.json')
    vector=read(SV/'tests/phase3/vector_combo/results.json')
    variants=read(SV/'results/phase3-tile-variants.json')
    synthesis=read(SV/'results/phase3-system-synthesis.json')
    assert scalar['status']=='pass' and fp['status']=='passed' and vector['status']=='pass'
    assert variants['status']=='passed'
    assert {p['profile'] for p in synthesis['profiles']}=={'base','logic','float','vector','context','streaming'}
    assert all(p['status']=='passed' and p['checks'][-1]==0 for p in synthesis['profiles'])
    for path,digest in synthesis['source_sha256'].items(): assert sha(SV/path)==digest,path
    systems=[]
    for label in ['base','logic','float','vector']:
        folder=SV/'build/phase3/system'/label
        banner=log_banner(folder/'run.log',rf'PHASE3_PROGRAMMABLE_{label.upper()}_PASS[^\n]+')
        assert 'cycles=134' in banner and 'bits=489' in banner
        assert f'pymtl_cycles={0 if label=="float" else 134}' in banner
        assert len(re.findall('SCENARIO_PASS',(folder/'run.log').read_text()))==2
        log_banner(folder/'negative.log','intentional negative control')
        log_banner(folder/'timeout.log','TIMEOUT scenario=')
        systems.append(dict(profile=label,cycles=134,raw_output_bits=489,pass_banner=banner,
            reference='Original HDL and independent mathematical results'+(' plus original Python replay' if label!='float' else ''),
            negative_controls=['wrong independent result','permanent output backpressure'],
            logs_sha256={p.relative_to(SV).as_posix():sha(p) for p in folder.glob('*.log')}))
    for label,cycles,bits in [('context',134,489),('streaming',160,513)]:
        folder=SV/'build/phase3/tile_variants'/f'cgra_{label}'
        banner=log_banner(folder/'run.log',rf'CGRA_{label.upper()}_PASS[^\n]+')
        assert f'cycles={cycles}' in banner and 'complete=8' in banner and 'reads=4' in banner
        log_banner(folder/'negative.log','CGRA replay mismatch cycle=20')
        systems.append(dict(profile=label,cycles=cycles,raw_output_bits=bits,pass_banner=banner,
            reference='Unmodified Python raw-cycle replay plus independent transaction results',
            negative_controls=['expected bit corruption at cycle20'],
            logs_sha256={p.relative_to(SV).as_posix():sha(p) for p in folder.glob('*.log')}))
    regressions=[]
    for label,cycles,bits in [('2x2',134,489),('3x2',158,563),('4x4',286,789),('2x2-w64-c16-r8',134,770)]:
        path=SV/'build/phase2'/label/'run.log'
        banner=log_banner(path,'PHASE2_CGRA_PASS[^\n]+')
        assert f'cycles={cycles}' in banner and f'bits={bits}' in banner
        regressions.append(dict(profile=label,cycles=cycles,raw_output_bits=bits,banner=banner,log_sha256=sha(path)))
    files=[SV/line for line in (SV/'filelists/phase3.f').read_text().splitlines() if line and not line.startswith('+')]
    files+=list((SV/'rtl/common').glob('*.svh'))+list((SV/'rtl/vendor/hardfloat').glob('*.vi'))
    files+=[SV/'Makefile',SV/'scripts/run.ps1',SV/'filelists/phase3.f',SV/'filelists/phase3_float.f']
    files += [p for p in (SV/'tests/phase3').rglob('*') if p.suffix in ('.sv','.sh','.ps1')]
    for name in ['tb_cgra_types.sv','phase2_tb_cgra_scalar.sv']: files.append(SV/'tests'/name)
    summary=dict(schema=1,status='passed',collected_utc=datetime.now(timezone.utc).isoformat(),
        baseline_commit=BASELINE,reference_commit=git('rev-parse','9daf3ec'),implementation_commit=IMPLEMENTATION,
        validation_commit=git('rev-parse','HEAD'),branch=git('branch','--show-current'),original_python_modified=False,
        agents_reused={'area_report':'Boyle: scalar FUs, vector system, FU/profile review',
          'noc_contract':'Bernoulli: vector/combo/MAC, FP review',
          'synth_tools':'Socrates: StreamingMem/Tile variants, complete variant systems, connection/provenance review'},
        agents_created_this_stage=[],
        systems=systems,phase2_regression=regressions,phase2_negative_controls=dict(profile='3x2',result='wrong arithmetic result and permanent output backpressure rejected'),
        component_reports=['phase3-scalar.json','phase3-float.json','phase3-tile-variants.json','phase3-vector-system.json','../tests/phase3/vector_combo/results.json'],
        synthesis_report='phase3-system-synthesis.json',parameter_guard_report='phase3-system-guard.json',
        source_sha256={p.relative_to(SV).as_posix():sha(p) for p in sorted(set(files))},
        routine_project_python_required=False,area_measured=False,frequency_measured=False,
        scope='Stage3 FU catalog and Base/Context/Streaming single-CGRA integration; multi-CGRA/DMA/im2col remain stage4.',
        limitations=['Finite two-state tests, not exhaustive/four-state formal equivalence.',
          'FP format/FINC behavior and VectorMulCombo Python-versus-HDL discrepancy retained; see PHASE3_REPORT.md.',
          'Reference adapters and original translation failures have explicit provenance.',
          'Baseline undriven signals/latches retained; final Yosys checks do not establish fully defined source semantics.',
          'Component structural checks, standalone full synthesis, and complete-CGRA synthesis are separately reported.'])
    save(SV/'results/phase3-summary.json',summary)
    print('PHASE3_SUMMARY_PASS systems=6 phase2_regressions=4')
    if not args.archive: return
    selected=set()
    for path in (SV/'build/phase3').rglob('*'):
        if path.is_file() and (path.suffix in ('.log','.ys','.json','.il') or path.name=='SHA256SUMS'):
            selected.add(path)
    for label,_,_ in [('2x2',134,489),('3x2',158,563),('4x4',286,789),('2x2-w64-c16-r8',134,770)]:
        for filename in (['run.log','negative.log','timeout-negative.log'] if label=='3x2' else ['run.log']):
            path=SV/'build/phase2'/label/filename
            if path.is_file(): selected.add(path)
    selected.update(p for p in (SV/'results').glob('phase3*.json') if 'evidence' not in p.name)
    selected.update((SV/'tests/phase3/vector_combo').glob('*.json'))
    archive=SV/'results/phase3-evidence.zip'
    entries={}
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for path in sorted(selected):
            name=path.relative_to(SV).as_posix(); data=path.read_bytes()
            output.writestr(name,data)
            entries[name]=dict(size=len(data),sha256=hashlib.sha256(data).hexdigest())
    with zipfile.ZipFile(archive) as zipped:
        assert set(zipped.namelist())==set(entries)
        for name,entry in entries.items(): assert hashlib.sha256(zipped.read(name)).hexdigest()==entry['sha256'],name
    save(SV/'results/phase3-evidence-manifest.json',dict(archive=archive.name,size=archive.stat().st_size,
        sha256=sha(archive),entries=entries,entry_count=len(entries),readback_verified=True))
    print('PHASE3_ARCHIVE_PASS',len(entries),archive.stat().st_size,sha(archive))

if __name__=='__main__': main()
