"""Freeze portable inputs, output evidence and a failure-preserving scope report."""
import argparse
import copy
import gzip
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from common import ROOT, SV, program, python_hashes, rtl_hashes, sha, write_json
from generate import generate
from oracle import check
from inventory import inventory
from run import matrix_passed
from structure import audit

HERE=Path(__file__).resolve().parent


def main():
  parser=argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--work',required=True,type=Path)
  parser.add_argument('--output',type=Path,default=HERE)
  args=parser.parse_args();work=args.work.resolve();out=args.output.resolve()
  out.mkdir(parents=True,exist_ok=True)
  result=json.loads((work/'results.json').read_text());matrix=json.loads((work/'matrix.json').read_text())
  assert result['rtl']==rtl_hashes(), 'Source changed after validation'
  pin=python_hashes();assert pin['python_target_commit']==result['python_target']
  guards=json.loads((work/'guards.json').read_text());assert guards['status']=='passed'
  result['guards']=guards;result['original_python_files_unchanged']=len(pin['source_sha256'])
  write_json(out/'parameters.json',inventory())
  result['suite_sources']={str(p.relative_to(ROOT)):sha(p) for p in sorted(HERE.glob('*.py'))}
  for path in [HERE/'driver.svh',SV/'migration_tools/parameterization_reference.py',
               SV/'tools/cgra_config.py',SV/'tools/cgra_program.py',SV/'tools/abi.json']:
    result['suite_sources'][str(path.relative_to(ROOT))]=sha(path)
  result['baseline_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
  # Regenerate every architecture/program in a fresh directory. This catches
  # manual edits to vectors or a changed generator being mislabeled as tested.
  regenerated=0
  with tempfile.TemporaryDirectory(dir=work,prefix='regenerate-') as temporary:
    fresh=Path(temporary);generate(fresh)
    for path in fresh.rglob('*'):
      if not path.is_file():continue
      relative=path.relative_to(fresh)
      assert path.read_bytes()==(work/relative).read_bytes(), 'Changed generated input '+str(relative)
      regenerated+=1
  result['regenerated_identical_files']=regenerated
  evidence=out/'evidence';evidence.mkdir(parents=True,exist_ok=True)
  hashes={}
  def keep(path):
    path=Path(path)
    relative=path.relative_to(work);dest=evidence/relative;dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(path,dest);hashes[str(relative)]=sha(dest)
    return str(dest.relative_to(out))
  comparisons={};rows=[];failures=[]
  for name in matrix['architectures']:
    p=result['profiles'].get(name)
    if p is None:
      rows.append([name,'未运行','0/12','0/3','0/2']);failures.append(name+': not_run');continue
    folder=work/name;entry=json.loads((folder/'architecture.json').read_text())
    required_cases={f'{a}_{seed}_schedule{s}' for a in matrix['algorithms']
                    for seed in matrix['seeds'] for s in matrix['schedules']}
    for label,actual,required in [('cases',set(p['cases']),required_cases),
        ('references',set(p['references']),set(matrix['algorithms'])),
        ('negatives',set(p['negatives']),{'last_tile_operation','register_index_alias','permanent_stall'})]:
      if actual!=required:
        failures.append(f'{name} {label}: missing={sorted(required-actual)}, extra={sorted(actual-required)}')
    for path in [folder/'config.json',folder/'architecture.json',folder/'generated/architecture.svh',
                 folder/'generated/bindings.svh',folder/'tb_parameterization.sv']:
      keep(path)
    if p.get('structure',{}).get('status')=='passed':
      xml=folder/'structure.xml';assert sha(xml)==p['structure']['xml_sha256']
      compressed=folder/'structure.xml.gz'
      compressed.write_bytes(gzip.compress(xml.read_bytes(),mtime=0))
      observed_structure=audit(compressed,entry)
      assert all(p['structure'][k]==v for k,v in observed_structure.items())
      p['structure']['evidence']=keep(compressed)
    binary_hashes=set();passed=0;refs=0
    for key,case in p['cases'].items():
      binary_hashes.add(case['binary_sha256'])
      case_name=key.split('_schedule')[0];case_folder=folder/case_name
      spec=json.loads((case_folder/'specification.json').read_text())
      for path in case_folder.iterdir():
        if path.is_file():keep(path)
      assert sha(case_folder/'program.hex')==case['program_sha256']
      if case['status']=='passed':
        observed=check(entry,spec,case_folder/f'trace_{case["schedule"]}.txt')
        # JSON changes tuple/list representation; normalize before comparing.
        assert json.loads(json.dumps(observed))==case['observations']
        passed+=1
        layout=program.layouts(entry['normalized'])['host']
        values={}
        if spec['streaming']:
          values[0]=observed['boundaries'][0][1]>>3
        else:
          for word in observed['responses']:
            packet=program.unpack(layout,word);payload=packet['payload']
            if payload['data_addr'] % spec['capacity']==spec['capacity']-1:
              values[packet['src_cgra_id']]=payload['data']['payload']
        for owner,value in values.items():
          key2=f'{spec["width"]}:{spec["algorithm"]}:{spec["seed"]}:{owner}'
          comparisons.setdefault(key2,[]).append(dict(profile=name,schedule=case['schedule'],value=value))
      else:
        failure=case.get('failure') or Path(case['log']).read_text()
        failures.append(name+' '+key+': '+failure.strip().splitlines()[-1])
    assert len(binary_hashes)<=1, 'Different executable used for programs on '+name
    p['same_binary_for_all_programs']=len(binary_hashes)==1
    for algorithm,ref in p['references'].items():
      if ref.get('exit_code')==0 and ref.get('result',{}).get('status')=='passed':
        refs+=1;case=folder/(algorithm+'_23');spec=json.loads((case/'specification.json').read_text())
        assert check(entry,spec,case/'python_trace.txt')==check(entry,spec,case/'trace_37.txt')
      else:
        text=ref.get('result',{}).get('failure',str(ref))
        failures.append(name+' Python '+algorithm+': '+text.strip().splitlines()[-1])
    negatives=sum(x.get('detected',False) for x in p['negatives'].values())
    for variant,neg in p['negatives'].items():
      if not neg.get('detected'):failures.append(name+' negative not detected: '+variant)
      negative_folder=folder/('negative_'+variant)
      if negative_folder.is_dir():
        for path in negative_folder.iterdir():
          if path.is_file():keep(path)
    if p['build']['exit_code']!=0: failures.append(name+': build_failed')
    structural=p.get('structure',{}).get('status','not_run')
    if structural!='passed':failures.append(name+': structure '+structural)
    rows.append([name,structural,f'{passed}/12',f'{negatives}/3',f'{refs}/2'])
    # Preserve all referenced build/run/error logs, verifying their recorded SHA.
    def portable(node):
      if isinstance(node,dict):
        for k,value in list(node.items()):
          if k=='log':
            path=Path(value)
            if node.get('sha256'):assert sha(path)==node['sha256'], str(path)
            node[k]=keep(path)
          else:portable(value)
      elif isinstance(node,list):
        for value in node:portable(value)
    portable(p)
  # Same input/word width must produce exactly the same result across profiles
  # and stalls. This is checked in addition to each run's independent oracle.
  for key,values in comparisons.items():
    assert len({x['value'] for x in values})==1, 'Cross-architecture result differs: '+key
  result['cross_architecture_comparisons']=comparisons
  result['memory_timing_same_programs']={}
  for algorithm in matrix['algorithms']:
    for seed in matrix['seeds']:
      relative=f'{algorithm}_{seed}/program.hex'
      left=sha(work/'rect_3x2_comb'/relative);right=sha(work/'rect_3x2_registered'/relative)
      assert left==right
      result['memory_timing_same_programs'][relative]=left
  result['failures']=failures
  result['all_passed']=bool(result['all_passed'] and matrix_passed(result,matrix) and not failures)
  result['commit_allowed']=False
  scheduling=work/'reference-scheduling-note.json'
  if scheduling.exists():
    result['reference_scheduling_note']=json.loads(scheduling.read_text())
    result['reference_scheduling_evidence']=keep(scheduling)
  toolchain=work/'toolchain.json'
  if toolchain.exists():
    result['toolchain']=json.loads(toolchain.read_text())
    result['toolchain_evidence']=keep(toolchain)
  result['evidence_sha256']=hashes
  write_json(out/'results.json',result)
  lines=['# 跨架构与跨程序验收结果','',
    '本表只表示本轮预先列出的九种配置；参数支持范围见 `../../PARAMETERIZATION.md`。',
    '原 Python、原 YAML、历史参考和本轮开始时的 SV RTL 均未修改。',
    '每架构正向 12 次、硬件/程序负例 3 次、Python 原模型完整程序对照 2 次。','',
    '| 架构 | 展开后结构 | 独立数学/完整结束 | 负例检出 | Python/SV 完整包 |',
    '|---|---|---|---|---|']
  lines += ['| '+' | '.join(row)+' |' for row in rows]
  lines += ['',f'全矩阵通过：**{result["all_passed"]}**。{len(guards["checks"])} 项配置/输出/参考复用验收保护通过；',
    f'独立重新生成并逐字节核对 {regenerated} 个输入文件。全部运行的程序哈希与二进制哈希见机器记录。',
    '逐架构保留 Verilator 实际展开后的 `structure.xml.gz`，导出时再次解析并核对 PE 参数和 FU 实例。',
    'add=`x+17`，affine=`3*x+11`，按位宽截断；同位宽、同输入跨架构/背压结果另作一致检查。',
    '3×2 组合/寄存内存使用逐字节相同的程序。Python 比较允许独立 Tile 完成消息交错，',
    '读请求串行、完整读回包逐项比较；不宣称逐周期等价。','', '## 未通过项','']
  lines += ['- '+failure for failure in failures] if failures else ['本轮上述有限矩阵没有未通过项。']
  retries=[(name,variant,x) for name,p in result['profiles'].items()
           for variant,x in p['negatives'].items() if x.get('previous_attempts')]
  if retries:
    lines += ['', '## 重跑记录','']
    for name,variant,x in retries:
      lines.append(f'- `{name}/{variant}`：首次达到 120 秒进程上限，不能计为负例检出；'
        f'保持程序、RTL 和 20,000 周期上限，进程预算改为 600 秒后重跑，检出={x["detected"]}。'
        '首轮失败记录与日志保留在 `previous_attempts`。')
  if scheduling.exists():
    lines += ['', '另有一次异构 Mesh add 参考进程在调度调整时中断，未产生完成结果；'
      '之后从头重新运行。中断不计通过，调度记录单独保留。']
  lines += ['', '## 保留的范围缺口','',
    '- HAS_CTRL_RING 尚未暴露到 JSON 工具；关闭控制环仅构造能力，不是另一套可运行配置通路。',
    '- 稀疏删 Tile、逐 CGRA 控制深度、任意坐标映射和任意 FU/消息位宽参数仍未完整对应。',
    '- 本轮未新增向量、浮点、DMA/im2col 或 Context 迁移、STREAM_LD 专项证明。',
    '- 原补测的 GEMM/GEMV/SPMV/Ring 四项未完成结论保持，不以这些新程序替代。',
    '- 因整体验收仍有未解决项，本轮不提交、不推送。','',
    '复现：`python3 -B sv/tests/parameterization/run.py --output work/parameterization --python <原PyMTL解释器>`。',
    '生成报告前运行 `guards.py --output <同目录>`，再运行 `report.py --work <同目录>`。',
    '测试台仅驱动公开接口，不写 DUT 内部状态。每次程序运行从复位开始。']
  (out/'RESULTS.md').write_text('\n'.join(lines)+'\n')
  print('PARAM_REPORT',len(rows),'profiles',len(failures),'failures',len(hashes),'evidence files')


if __name__=='__main__':main()
