"""Freeze unchanged ac96 FP wrappers and a reversible test-only namespace.

This migration-only exporter is never called by the maintained SV build.
"""
import argparse
import configparser
import hashlib
import inspect
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT.parent))
from pymtl3 import mk_bits, clog2
from pymtl3.passes.backends.verilog import VerilogPlaceholderPass, VerilogTranslationPass
from VectorCGRA.lib.messages import mk_data, mk_ctrl, mk_cgra_payload, mk_intra_cgra_pkt
from VectorCGRA.fu.float.FpAddRTL import FpAddRTL
from VectorCGRA.fu.float.FpMulRTL import FpMulRTL

BASELINE = 'ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b'

class WindowsPlaceholderPass(VerilogPlaceholderPass):
    """Identical prefix lookup, stopping at any platform's filesystem root."""
    def _get_auto_prefix(self, model):
        start = Path(inspect.getfile(model.__class__)).parent.resolve()
        for directory in (start, *start.parents):
            filename = directory / 'pymtl.ini'
            if filename.exists():
                config = configparser.ConfigParser()
                config.read(filename)
                if config.getboolean('placeholder', 'auto_prefix', fallback=False):
                    relative = start.name if directory == start else str(start.relative_to(directory))
                    return relative.replace(os.path.sep, '_') + '_'
                return ''
        return ''

    def _import_sources(self, cfg, source_list):
        if not source_list:
            return
        start = Path(source_list[0]).resolve().parent
        include_path = start
        for directory in (start, *start.parents):
            if (directory / 'pymtl.ini').exists():
                include_path = directory
                sys.path.insert(0, str(directory))
                break
        if cfg.v_include:
            assert len(cfg.v_include) == 1, 'Original pickler supports one include path'
            include_path = Path(cfg.v_include[0])
        return ''.join(self._output_verilog_file(str(include_path), source) for source in source_list)

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unit', choices=['add', 'mul'], required=True)
    parser.add_argument('--exp', type=int, default=8)
    parser.add_argument('--sig', type=int, default=23)
    args = parser.parse_args()
    data_w = args.exp + args.sig + 1
    profile = f'{args.unit}-e{args.exp}-s{args.sig}'
    folder = ROOT / 'sv/reference/phase3/float' / profile
    folder.mkdir(parents=True, exist_ok=True)
    if (folder / 'manifest.json').exists():
        raise SystemExit('Refuse to overwrite a frozen reference')
    changed = subprocess.check_output(['git', 'diff', '--name-only', BASELINE, '--', 'fu', 'lib'], cwd=ROOT, text=True)
    assert not changed.strip(), changed
    expected = subprocess.check_output(['git', 'ls-tree', BASELINE, 'fu/pymtl3_hardfloat'], cwd=ROOT, text=True).split()[2]
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT / 'fu/pymtl3_hardfloat', text=True).strip()
    assert expected == actual
    Data = mk_data(data_w, 1)
    Ctrl = mk_ctrl(4, 2, 4, 4, 16)
    Payload = mk_cgra_payload(Data, mk_bits(7), Ctrl, mk_bits(clog2(8)))
    Host = mk_intra_cgra_pkt(1, 1, 4, Payload)
    top = 'Phase3Fp' + args.unit.title() + f'E{args.exp}S{args.sig}'
    dut = (FpAddRTL if args.unit == 'add' else FpMulRTL)(Host, 4, 2, exp_nbits=args.exp, sig_nbits=args.sig)
    dut.elaborate()
    dut.apply(WindowsPlaceholderPass())
    dut.set_metadata(VerilogTranslationPass.enable, True)
    dut.set_metadata(VerilogTranslationPass.explicit_module_name, top)
    os.chdir(folder)
    dut.apply(VerilogTranslationPass())
    produced = Path(dut.get_metadata(VerilogTranslationPass.translated_filename))
    original = folder / 'original.v'
    original.write_bytes(produced.read_bytes())
    source = original.read_text()
    symbols = set(re.findall(r'(?m)^\s*module\s+(\w+)', source))
    symbols.update(re.findall(r'}\s+(\w+)\s*;', source))
    symbols.update(re.findall(r'`define\s+(\w+)', source))
    prefix = f'GoldFp{args.unit.title()}E{args.exp}S{args.sig}_'
    mapping = {name: prefix + name for name in sorted(symbols)}
    pattern = re.compile(r'\b(' + '|'.join(map(re.escape, sorted(symbols, key=len, reverse=True))) + r')\b')
    renamed = pattern.sub(lambda m: mapping[m[0]], source)
    reverse = {v: k for k, v in mapping.items()}
    back = re.sub(r'\b(' + '|'.join(map(re.escape, reverse)) + r')\b', lambda m: reverse[m[0]], renamed)
    assert back == source
    (folder / 'gold.v').write_text(renamed, newline='\n')
    (folder / 'exporter_snapshot.py').write_bytes(Path(__file__).read_bytes())
    source_hashes = {}
    for mod in list(sys.modules.values()):
        path = getattr(mod, '__file__', None)
        if path and Path(path).is_file():
            path = Path(path).resolve()
            if path.is_relative_to(ROOT):
                source_hashes[str(path.relative_to(ROOT)).replace('\\', '/')] = sha(path)
    manifest = dict(baseline_commit=BASELINE, hardfloat_commit=actual,
        parameters=dict(DATA_W=data_w, FP_EXP_W=args.exp, FP_SIG_W=args.sig),
        actual_hardfloat_parameters=dict(expWidth=args.exp+1, sigWidth=args.sig),
        original_top=top, gold_top=mapping[top], source_sha256=source_hashes,
        original_sha256=sha(original), gold_sha256=sha(folder/'gold.v'),
        namespace_mapping=mapping, namespace_roundtrip_verified=True,
        tool_adaptation='Windows-root-aware placeholder prefix and include-directory searches; original installed pass loops at a drive root in both searches. No RTL/source modification.',
        notes=['Unmodified ac96 wrapper and HardFloat source; no numerical or handshake fixes.',
               'ac96 passes exp_nbits+1 and sig_nbits to HardFloat; do not silently reinterpret these as IEEE exp/fraction widths.'])
    (folder / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', newline='\n')
    print(f'FLOAT_REFERENCE_PASS {profile} top={mapping[top]}')

if __name__ == '__main__':
    main()
