import hashlib,json,subprocess,re
from pathlib import Path
from datetime import datetime,timezone
root=Path.cwd();sv=root/'sv';out=sv/'tests/phase4/compatibility';out.mkdir(parents=True,exist_ok=True)
def git(*a):return subprocess.check_output(['git','-c','core.excludesFile=D:/work/VectorCGRA/.git/info/exclude',*a],cwd=root)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
draft=git('rev-parse','codex/sv-phase5-draft').decode().strip()
def prior(name):return git('show',draft+':sv/tests/phase5/coverage/'+name)
old_names=['shared_profile_regression.json','shared_profile_initial_failure.json','shared_profile_recovery_collector_failure.json','shared_profile_tb_compatibility.json','shared_profile_variant_replay.json']
assets={}
for name in old_names:
 p=out/name;p.write_bytes(prior(name));assets[p.relative_to(sv).as_posix()]=sha(p)
raw=json.loads((out/old_names[0]).read_text(encoding='utf-8-sig'));assert raw['status']=='passed',raw['failure']
patch=json.loads((out/'shared_profile_tb_compatibility.json').read_text(encoding='utf-8-sig'))
assert len(patch['files'])==35
for f in patch['files']:assert sha(sv/f['path'])==f['after_sha256'],f['path']
filtered={};excluded=[]
entrypoints={'Makefile','scripts/run.ps1','filelists/native.f'}
for name,digest in raw['source_sha256'].items():
 p=sv/name
 if p.is_file() and sha(p)==digest:filtered[name]=digest;continue
 prior_blob=git('show',draft+':sv/'+name)
 assert hashlib.sha256(prior_blob).hexdigest()==digest,('historical snapshot mismatch',name)
 if name in entrypoints:reason='Only deferred stage5 entries removed after validation; phase1-4 commands/RTL unchanged.'
 else:
  assert name.startswith(('rtl/legacy/','rtl/controller/loop/')) and not p.exists(),name
  reason='Unused deferred stage5 DUT; not consumed by any recorded phase2/3 regression compilation.'
 excluded.append(dict(path=name,historical_sha256=digest,current_sha256=sha(p) if p.is_file() else None,reason=reason))
assert len(excluded)==11,excluded
logs={};historical_log_mapping={}
for name,digest in raw['logs_sha256'].items():
 p=sv/name;assert p.is_file() and sha(p)==digest,('log changed',name)
 if name.startswith('build/phase5/'):
  target=sv/'build/phase4/compatibility-history'/p.name
  target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(p.read_bytes())
  newname=target.relative_to(sv).as_posix();historical_log_mapping[name]=newname;logs[newname]=digest
 else:logs[name]=digest
metadata={}
folders=['build/phase2','build/phase3/system','build/phase3/scalar','build/phase3/vector_combo','build/phase3/tile_variants']
for folder in folders:
 for p in (sv/folder).rglob('*__verFiles.dat'):
  text=p.read_text(errors='replace').replace('\\','/')
  assert not re.search(r'rtl/(legacy/|controller/loop/)',text),p
  metadata[p.relative_to(sv).as_posix()]=sha(p)
assert metadata
result=dict(schema=1,status='passed',scope='Stage4 shared-profile compatibility with prior stage2/3 programs and affected components',
 derived_utc=datetime.now(timezone.utc).isoformat(),historical_snapshot_branch='codex/sv-phase5-draft',historical_snapshot_commit=draft,
 historical_report_assets=assets,profile_pass_banners=raw['profile_pass_banners'],component_replays=raw['component_replays'],
 source_sha256=filtered,logs_sha256=logs,compiled_metadata_sha256=metadata,
 post_validation_scope_changes=excluded,historical_log_relocations=historical_log_mapping,
 tb_compatibility_patch_count=35,semantics=raw['semantics'],environment=raw['environment'],
 source_scope='Derived delivery index, not a rewrite of the historical capture: all retained source hashes rechecked; unused stage5 files and entrypoint-only removals listed explicitly; original full reports copied byte-for-byte.',
 initial_failure_preserved=True,collector_utc_failure_preserved=True,python_executed=False,synthesis_executed=False,
 limitations=raw['limitations'])
save(out/'results.json',result)
(out/'README.md').write_text('''# 第四阶段共享参数兼容回归

`results.json` 是按第四阶段交付范围生成的索引：第二阶段四个参数点、第三阶段六个完整系统，以及受共享 profile 影响的两标量、30 向量/组合和两个 Tile 组件实际重跑通过。

`shared_profile_*.json` 原字节保存当时的完整采集、第一次 Context 编译失败和 UTC 时间收集器失败。它们在范围收窄之前存放于 `tests/phase5/coverage`，其中路径和历史 Git SHA 未被改写。历史广泛源码快照包含八个未被这些测试使用的第五阶段 RTL 文件和三个后来删除第五阶段入口的文件；当前索引逐项列明排除理由，并复核其草稿分支 Git blob 与原 SHA。它们不是第四阶段 DUT 的运行依赖。

35 个旧测试平台各新增一行默认位宽别名，未改 DUT、测试刺激、正确结果或冻结参照。独立组件及完整系统的实际编译日志和输入记录可由第四阶段证据 ZIP 追溯。日常重跑继续使用 `scripts/run.ps1 -Task phase2` 和第三阶段已有入口；这些 JSON 只记录迁移取证，不参与运行。
''',encoding='utf-8',newline='\n')
print('PHASE4_COMPATIBILITY_SCOPE_PASS',len(filtered),len(logs),len(metadata),len(excluded))