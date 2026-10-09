"""Write checked-in SV replay benches from immutable Python trace manifests."""
import argparse,json
from pathlib import Path

SV=Path(__file__).resolve().parents[1]


def generate(label):
  ref=SV/'reference/phase4/migration'/label
  m=json.loads((ref/'manifest.json').read_text())
  out=SV/'tests/phase4/migration'/label;out.mkdir(parents=True,exist_ok=True)
  params=m['parameters'];hostbits=m['host']['nbits'];dynamic=params['TILE_VARIANT']==1
  effective_kinds=list(m['fu_kinds'])
  implicit_nah=3 not in effective_kinds
  if implicit_nah:effective_kinds.append(3)
  (out/'test_profile.json').write_text(json.dumps(dict(parameters=params,
    declared_fu_kinds=m['fu_kinds'],effective_fu_kinds=effective_kinds,
    implicit_nah_appended=implicit_nah,
    reason='ac96 FlexibleFuRTL.py appends NahRTL at elaboration if absent from the caller FuList; SV lists it explicitly.'),indent=2)+'\n',newline='\n')
  fields={f['field']:f for f in m['host']['fields']}
  inp=m['inputs'];outputs=m['outputs'];ib=sum(f['width'] for f in inp);ob=sum(f['width'] for f in outputs)
  def slice(field):
    f=fields[field];return f"send_to_cpu_pkt__msg[{f['lsb']} +: {f['nbits']}]"
  def native(expr):
    # The trace exporter labels its semantic context endpoint independently of
    # the native generate-block names. Only this SV hierarchical spelling adapts.
    return expr.replace('.context_tile.tile.core.context_switch','.variant_1.tile.core.context_wiring.context_switch')
  lines=['`timescale 1ns/1ps','module tb_multi_migration;',
    '  logic clk=0, reset;',f'  logic [{hostbits-1}:0] recv_from_cpu_pkt__msg,send_to_cpu_pkt__msg;',
    '  logic recv_from_cpu_pkt__val,recv_from_cpu_pkt__rdy,send_to_cpu_pkt__val,send_to_cpu_pkt__rdy;',
    '  cgra_multi #('+','.join(f'.{k}({v})' for k,v in params.items())+',',
    f"    .FU_COUNT({len(effective_kinds)}),.FU_KINDS({{{','.join('8\'d'+str(k) for k in reversed(effective_kinds))}}})) dut (.*);",
    f'  logic [{ib-1}:0] replay_input;',f'  logic [{ob-1}:0] expected_output,actual_output;',
    '  assign actual_output={'+','.join(native(f['sv']) for f in outputs)+'};',
    '  integer fd,status,cycle,expected_cycles,host_inputs,complete_count,result_count,math_expected;',
    '  integer fdresult,boundary_transfers,resume_count;',
    '  bit intentional_failure; string vector_path,result_path;',
    '  bit [15:0] completion_seen,saved_seen,resume_seen,cleared_seen;',
    '  integer source_cgra,source_tile;']
  if dynamic:
    lines += ['  wire [34:0] saved_progress[0:15],overwrite_progress[0:15];','  wire resume_active[0:15],overwrite_valid[0:15];']
    for c in range(4):
      for t in range(4):
        p=f'dut.cgras[{c}].cgra.tiles[{t}].variant_1.tile.core.context_wiring.context_switch';idx=4*c+t
        lines += [f'  assign saved_progress[{idx}]={p}.progress_reg;',f'  assign overwrite_progress[{idx}]={p}.overwrite_fu_outport__msg;',
          f'  assign resume_active[{idx}]={p}.is_resuming;',f'  assign overwrite_valid[{idx}]={p}.overwrite_fu_outport__val;']
  lines += ['  initial begin','#50000; $fatal(1,"MIGRATION_TIMEOUT wall-clock guard");','  end','  initial begin',
    '    cycle=0;host_inputs=0;complete_count=0;result_count=0;boundary_transfers=0;resume_count=0;',
    "    completion_seen='0;saved_seen='0;resume_seen='0;cleared_seen='0;",
    '    intentional_failure=$test$plusargs("EXPECT_FAILURE");',
    '    if(!$value$plusargs("TRACE=%s",vector_path)) $fatal(1,"TRACE argument required");',
    '    if(!$value$plusargs("CYCLES=%d",expected_cycles) || expected_cycles<1) $fatal(1,"CYCLES required");',
    '    if(!$value$plusargs("RESULT=%s",result_path)) result_path="migration-result.json";',
    '    fd=$fopen(vector_path,"r");if(fd==0) $fatal(1,"cannot read replay trace");',
    '    while(!$feof(fd)) begin',
    '      status=$fscanf(fd,"%h %h\\n",replay_input,expected_output);',
    '      if(status!=2) $fatal(1,"malformed replay row %0d",cycle);',
    '      {'+','.join(f['sv'] for f in inp)+'}=replay_input;',
    '      #4;',
    '      if(actual_output!==expected_output) begin']
  offset=ob
  for f in outputs:
    offset-=f['width'];w=f['width']
    lines.append(f'        if(actual_output[{offset}+:{w}]!==expected_output[{offset}+:{w}]) $fatal(1,"RAW_DIFF cycle=%0d field={f["name"]} actual=%h expected=%h",cycle,actual_output[{offset}+:{w}],expected_output[{offset}+:{w}]);')
  lines += ['        $fatal(1,"unclassified replay mismatch");','      end','      if(!reset) begin',
    '        if(recv_from_cpu_pkt__val && recv_from_cpu_pkt__rdy) host_inputs++;',
    '        if(send_to_cpu_pkt__val && send_to_cpu_pkt__rdy) begin',
    f'          source_cgra=int\'({slice("src_cgra_id")});source_tile=int\'({slice("src")});',
    f'          if({slice("payload.cmd")}!=6\'d14) $fatal(1,"unexpected non-complete host packet");',
    '          if(completion_seen[4*source_cgra+source_tile]) $fatal(1,"duplicate completion");',
    '          completion_seen[4*source_cgra+source_tile]=1;complete_count++;']
  if dynamic:
    lines += ['          math_expected=3;for(int i=2;i<10;i++) math_expected+=(10+i)*(12+i);',
      '          if(source_cgra!=2 || source_tile!=1) $fatal(1,"wrong result source");',
      '          if(intentional_failure) math_expected++;',
      f'          if({slice("payload.data.payload")}!=32\'(math_expected) || {slice("payload.data.predicate")}!=1\'b1)',
      '            $fatal(1,"MATH_RESULT mismatch%s",intentional_failure?" intentional negative control":"");',
      '          result_count++;']
  else:
    lines += ['          if(source_tile==1) begin',
      '            math_expected=0;for(int i=1;i<=8;i++) math_expected+=i;',
      '            if(source_cgra==0) math_expected+=17;else if(source_cgra==3) math_expected-=5;else $fatal(1,"wrong reduce participant");',
      '            if(intentional_failure) math_expected++;',
      f'            if({slice("payload.data.payload")}!=32\'(math_expected) || {slice("payload.data.predicate")}!=1\'b1)',
      '              $fatal(1,"MATH_RESULT mismatch%s",intentional_failure?" intentional negative control":"");',
      '            result_count++;','          end']
  lines+=['        end']
  if dynamic:
    for c in range(4):
      for direction in ['north','south','west','east']:
        for p in range(2):lines.append(f'        if(dut.send_{direction}_val[{c}][{p}] && dut.send_{direction}_rdy[{c}][{p}]) boundary_transfers++;')
    lines+=['        for(int i=0;i<16;i++) begin',"          if(saved_progress[i]!='0) saved_seen[i]=1;",
      '          if(resume_active[i] && overwrite_valid[i]) begin',
      "            if(saved_progress[i]=='0 || overwrite_progress[i]!==saved_progress[i]) $fatal(1,\"bad context restore\");",
      '            resume_seen[i]=1;resume_count++;','          end',
      "          if(resume_seen[i] && saved_progress[i]=='0) cleared_seen[i]=1;",'        end']
  lines += ['      end','      #1;clk=1;#1;clk=0;cycle++;','    end','$fclose(fd);',
    '    if(cycle!=expected_cycles) $fatal(1,"truncated cycle replay actual=%0d expected=%0d",cycle,expected_cycles);',
    f'    if(host_inputs!={len(m["configuration_packets"])} || complete_count!={1 if dynamic else 6} || result_count!={1 if dynamic else 2}) $fatal(1,"coverage count mismatch inputs=%0d complete=%0d results=%0d",host_inputs,complete_count,result_count);']
  if dynamic:
    lines+=['    if(boundary_transfers==0 || !saved_seen[0] || !saved_seen[3] || !resume_seen[0] || !resume_seen[3] || !cleared_seen[0] || !cleared_seen[3]) $fatal(1,"preserve/restore/physical-link coverage absent");']
  lines += ['    fdresult=$fopen(result_path,"w");if(fdresult==0) $fatal(1,"result output unavailable");',
    f'    $fdisplay(fdresult,"{{\\"status\\":\\"pass\\",\\"cycles\\":%0d,\\"raw_bits_per_cycle\\":{ob},\\"host_inputs\\":%0d,\\"completions\\":%0d,\\"math_results\\":%0d,\\"boundary_transfers\\":%0d,\\"resume_count\\":%0d}}",cycle,host_inputs,complete_count,result_count,boundary_transfers,resume_count);',
    '    $fclose(fdresult);',f'    $display("PHASE4_MIGRATION_PASS label={label} cycles=%0d raw_bits={ob} inputs=%0d completions=%0d math=%0d boundary=%0d resume=%0d",cycle,host_inputs,complete_count,result_count,boundary_transfers,resume_count);',
    '    $finish;','  end','endmodule']
  (out/'tb_multi_migration.sv').write_text('\n'.join(lines)+'\n',newline='\n')
  if m['status']=='recorded':(out/'replay_counts.txt').write_text(str(m['cycles'])+'\n',newline='\n')
  print('WROTE '+label+' oracle_status='+m['status'])


if __name__=='__main__':
  p=argparse.ArgumentParser();p.add_argument('labels',nargs='+');args=p.parse_args()
  for label in args.labels:generate(label)
