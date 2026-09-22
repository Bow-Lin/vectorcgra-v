"""Collect completed NoC evidence; does not simulate or generate RTL."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
  results=[];baseline_failures=[]
  for manifest_path in sorted((ROOT/'reference/phase4/noc').glob('*/manifest.json')):
    m=json.loads(manifest_path.read_text())
    assert sha(manifest_path.parent/'exporter_snapshot.py')==m['exporter_sha256']
    if m['status']!='exported':
      baseline_failures.append(dict(label=m['label'],status=m['status'],reason=m['failure'].splitlines()[-1],manifest_sha256=sha(manifest_path)))
      continue
    assert sha(manifest_path.parent/'reference.v')==m['rtl_sha256']
    result_path=ROOT/'build/phase4/noc'/m['label']/'result.json'
    r=json.loads(result_path.read_text())
    assert r['status']=='pass' and r['cycles']==2081 and r['accepted']==r['delivered']==128*r['nodes']
    r.update(label=m['label'],parameters=m['parameters'],reference_sha256=m['rtl_sha256'],
      exporter_sha256=m['exporter_sha256'],log_sha256=sha(result_path.parent/'run.log'),
      reference_manifest_sha256=sha(manifest_path))
    results.append(r)
  assert len(results)==9
  for filename,marker in [('negative.log','intentional negative control'),('timeout.log','NOC_TIMEOUT')]:
    assert marker in (ROOT/'build/phase4/noc/mesh_2x2_l1_w32'/filename).read_text()
  source_files=[ROOT/line for line in (ROOT/'filelists/phase4_noc.f').read_text().splitlines() if line and not line.startswith('+')]
  source_files+=[ROOT/'tests/phase4/noc/tb_inter_cgra_noc.sv']
  result=dict(status='pass',oracle='unmodified ac96 translated HDL, complete raw external output comparison',
    profiles=results,total_cycles=sum(r['cycles'] for r in results),
    total_delivered=sum(r['delivered'] for r in results),
    total_raw_compared_bits=sum(r['cycles']*r['raw_bits_per_cycle'] for r in results),
    baseline_failures=baseline_failures,
    negative_controls=dict(scoreboard='nonzero exit and intentional negative control marker',timeout='nonzero exit and NOC_TIMEOUT marker'),
    limitations=['Two-state Verilator execution; not a four-state X proof.',
      'Arbitrary warm-up traffic is compared but not included in accepted-packet scoreboards.',
      'Packet order is checked within source/destination/initial-VC flows; cross-VC reordering is allowed.',
      'Ring CHANNEL_LATENCY is intentionally ignored, matching the original RingNetworkRTL constructor.',
      'Original Ring nondefault VC/credit arguments are not propagated to routers; native supports only the actual VCS=2/CREDITS=2 implementation.',
      'Original Mesh one-dimensional construction fails Bits0; no equivalence claim for those shapes.'],
    source_sha256={p.relative_to(ROOT).as_posix():sha(p) for p in source_files})
  destination=ROOT/'tests/phase4/noc/simulation_results.json'
  destination.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
  print(f"NOCTEST_RESULTS_PASS profiles=9 cycles={result['total_cycles']} packets={result['total_delivered']}")


if __name__=='__main__':main()
