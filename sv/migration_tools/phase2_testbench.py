"""Migration-time derivation of the parameterized SV acceptance test.

Reads the reviewed phase1 test; normal builds compile the emitted SV directly.
"""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]


def main():
  source = (ROOT / 'sv/tests/tb_cgra_2x2_scalar.sv').read_text()
  source = source.replace('module tb_cgra_2x2_scalar;', '''`include "cgra_profile_defs.svh"
`ifndef PHASE2_REFERENCE_MODULE
`define PHASE2_REFERENCE_MODULE Phase2Reference2x2
`endif
module phase2_tb_cgra_scalar #(`CGRA_PROFILE_PARAMETERS);
  `include "cgra_profile.svh"
  typedef data_t tb_data_t;
  typedef ctrl_t tb_ctrl_t;
  typedef host_packet_t tb_packet_t;
  typedef payload_t tb_payload_t;
  localparam int REPLAY_IN_BITS = 4 + 2*GLOBAL_ADDR_W + HOST_BITS + 2*(COLS+ROWS)*(DATA_BITS+2);
  localparam int REPLAY_OUT_BITS = 2 + HOST_BITS + 2*(COLS+ROWS)*(DATA_BITS+2);
  localparam int PACKET_COUNT = 5*NUM_TILES+6;
  int chain [0:NUM_TILES-1];
  int expected_cycles, expected_samples;
  localparam int CMD_LAUNCH=0, CMD_CONFIG=3, CMD_CONFIG_TOTAL_CTRL_COUNT=7,
    CMD_CONFIG_COUNT_PER_ITER=8, CMD_LOAD_REQUEST=10, CMD_LOAD_RESPONSE=11,
    CMD_STORE_REQUEST=12, CMD_CONST=13, CMD_COMPLETE=14;

  function automatic tb_data_t data_word(input logic [DATA_W-1:0] value, input logic predicate=1);
    return {value,predicate,2'b00};
  endfunction
  function automatic logic [DATA_W-1:0] result_for(input logic [DATA_W-1:0] value);
    return ((value+DATA_W'(5))*DATA_W'(3))-DATA_W'(8*(NUM_TILES-3));
  endfunction
  function automatic int dir(input int src, input int dst);
    if (dst==src+COLS) return 0;
    if (dst==src-COLS) return 1;
    if (dst==src-1) return 2;
    if (dst==src+1) return 3;
    $fatal(1,"Nonadjacent chain edge %0d -> %0d",src,dst);
    return -1;
  endfunction
  function automatic tb_ctrl_t workload_ctrl(input int tile_id, input int step_id=0);
    tb_ctrl_t c;
    int position;
    c='0;
    for(int i=0;i<4;i++) c.fu_in[i]=3'(i+1);
    if(tile_id==0) begin
      c.operation=step_id==0 ? 7'd28 : 7'd58;
      if(step_id==0) c.fu_xbar_outport[3]=1;
      else c.routing_xbar_outport[4]=1;
    end else begin
      position=0;
      for(int i=1;i<NUM_TILES;i++) if(chain[i]==tile_id) position=i;
      if(position==0) $fatal(1,"Tile missing from chain");
      c.operation=position==2 ? 7'd29 : 7'd25;
      c.routing_xbar_outport[4]=4'(dir(tile_id,chain[position-1])+1);
      c.fu_xbar_outport[dir(tile_id,chain[(position+1)%NUM_TILES])]=1;
      if(position==NUM_TILES-1) c.fu_xbar_outport[2]=1;
    end
    return c;
  endfunction
  function automatic tb_packet_t packet(input int command, input int destination,
      input logic [DATA_W-1:0] value='0, input logic predicate=0,
      input logic [GLOBAL_ADDR_W-1:0] address='0, input tb_ctrl_t control_word='0,
      input logic [CTRL_ADDR_W-1:0] control_address='0, input logic [TILE_ID_W-1:0] source='0);
    tb_packet_t p;
    p='0; p.src=source; p.dst=TILE_ID_W'(destination);
    p.payload.cmd=6'(command); p.payload.data=data_word(value,predicate);
    p.payload.data_addr=address; p.payload.ctrl=control_word; p.payload.ctrl_addr=control_address;
    return p;
  endfunction''')
  source = source.replace('  import scalar_workload_pkg::*;\n', '')
  for old, new in [('[190:0]', '[HOST_BITS-1:0]'), ('[193:0]', '[NOC_BITS-1:0]'),
      ('[34:0]', '[DATA_BITS-1:0]'), ('[31:0]', '[DATA_W-1:0]'), ('[6:0] address_lower', '[GLOBAL_ADDR_W-1:0] address_lower'),
      ("191'(", "HOST_BITS'("), ('[0:25]', '[0:PACKET_COUNT-1]'),
      ('[3:0] completed_tiles', '[NUM_TILES-1:0] completed_tiles'), ('mesh_link_count [0:3]', 'mesh_link_count [0:NUM_TILES-1]'),
      ('[504:0]', '[REPLAY_IN_BITS-1:0]'), ('[488:0]', '[REPLAY_OUT_BITS-1:0]'), ('[0:133]', '[0:8191]')]:
    source = source.replace(old, new)
  for d in ['north', 'south', 'east', 'west']:
    dim = 'COLS' if d in ['north', 'south'] else 'ROWS'
    source = re.sub(r'(\w*boundary_' + d + r'__\w+) \[0:1\]', r'\1 [0:' + dim + '-1]', source)
  source = source.replace('  cgra_2x2 dut (.*);', '''`ifdef PHASE2_REFERENCE_ONLY
  `PHASE2_REFERENCE_MODULE dut (.*);
`else
  cgra_scalar #(`CGRA_PROFILE_BIND) dut (.*);
`endif''')
  source = source.replace('  VectorCGRA2x2Reference gold (', '  `PHASE2_REFERENCE_MODULE gold (')
  source = source.replace('vector_dir = "sv/vectors"', 'vector_dir = "sv/vectors/phase2/2x2"')
  start = source.index('  task automatic compare_pymtl();')
  end = source.index('  task automatic compare_signal', start)
  code = '''  task automatic compare_pymtl();
    logic [REPLAY_IN_BITS-1:0] actual_inputs;
    logic [REPLAY_OUT_BITS-1:0] actual_outputs;
    int sample_index, a, b;
    sample_index=scenario_id*(expected_cycles+3)+cycle_count+3;
    actual_inputs='0; actual_outputs='0; a=0; b=0;
'''
  for field, width in [('reset','1'),('cgra_id','1'),('address_lower','GLOBAL_ADDR_W'),('address_upper','GLOBAL_ADDR_W'),('recv_from_cpu_pkt__val','1'),('recv_from_cpu_pkt__msg','HOST_BITS'),('send_to_cpu_pkt__rdy','1')]:
    code += f'    actual_inputs[a +: {width}]={field}; a+={width};\n'
  for field, width in [('recv_from_cpu_pkt__rdy','1'),('send_to_cpu_pkt__val','1'),('send_to_cpu_pkt__msg','HOST_BITS')]:
    code += f'    actual_outputs[b +: {width}]={field}; b+={width};\n'
  for d in ['north','south','west','east']:
    dim='COLS' if d in ['north','south'] else 'ROWS'
    code += f'    for(int i=0;i<{dim};i++) begin\n'
    for io, arr, field, width in [('inputs','a','recv','1'),('outputs','b','send','1')]:
      code += f'      actual_{io}[{arr} +: {width}]={field}_data_on_boundary_{d}__val[i]; {arr}+={width};\n'
    code += f'      actual_inputs[a +: DATA_BITS]=recv_data_on_boundary_{d}__msg[i]; a+=DATA_BITS;\n'
    code += f'      actual_outputs[b +: DATA_BITS]=send_data_on_boundary_{d}__msg[i]; b+=DATA_BITS;\n'
    code += f'      actual_outputs[b]=recv_data_on_boundary_{d}__rdy[i]; b++;\n'
    code += f'      actual_inputs[a]=send_data_on_boundary_{d}__rdy[i]; a++;\n    end\n'
  code += '''    if(a!=REPLAY_IN_BITS || b!=REPLAY_OUT_BITS) $fatal(1,"Replay layout width mismatch");
    if(!stall_forever) begin
      if(sample_index<0 || sample_index>=expected_samples) $fatal(1,"Replay length mismatch");
      if(actual_inputs !== pymtl_inputs[sample_index]) $fatal(1,"PYMTL_INPUT_MISMATCH scenario=%0d cycle=%0d expected=%h actual=%h",scenario_id,cycle_count,pymtl_inputs[sample_index],actual_inputs);
      if(actual_outputs !== pymtl_outputs[sample_index]) $fatal(1,"PYMTL_OUTPUT_MISMATCH scenario=%0d cycle=%0d xor=%h",scenario_id,cycle_count,actual_outputs^pymtl_outputs[sample_index]);
      pymtl_compared_cycles++;
    end
  endtask

'''
  source = source[:start] + code + source[end:]
  start=source.index('    for (int i = 0; i < 2; i++) begin',source.index('task automatic compare_outputs'))
  end=source.index('    all_compared_cycles++;',start)
  code=''
  for d in ['north','south','west','east']:
    dim='COLS' if d in ['north','south'] else 'ROWS'
    code+=f'    for(int i=0;i<{dim};i++) begin\n'
    for prefix, key in [('recv','rdy'),('send','val'),('send','msg')]:
      field=f'{prefix}_data_on_boundary_{d}__{key}[i]'
      code+=f'      compare_signal($sformatf("{prefix}.{d}.%0d.{key}",i), HOST_BITS\'({field}), HOST_BITS\'(gold_{field}));\n'
    code+='    end\n'
  source=source[:start]+code+source[end:]
  start=source.index('  task automatic record_cycle();');end=source.index('  task automatic check_transactions();',start)
  source=source[:start]+'''  task automatic record_cycle();
    if(trace_fd) $fwrite(trace_fd,"%0d,%0d,%0d,%h,%h\\n",scenario_id,cycle_count,reset,recv_from_cpu_pkt__msg,send_to_cpu_pkt__msg);
  endtask

'''+source[end:]
  start=source.index('    for (int i = 0; i < 2; i++) begin',source.index('task automatic check_transactions'))
  end=source.index('    last_input_fire',start)
  code=''
  for d in ['north','south','east','west']:
    dim='COLS' if d in ['north','south'] else 'ROWS'
    skip='if(i!=1) ' if d=='west' else ''
    code+=f'    for(int i=0;i<{dim};i++) {skip}if(send_data_on_boundary_{d}__val[i] !== 1\'b0) $fatal(1,"Unexpected {d} boundary output %0d",i);\n'
  source=source[:start]+code+source[end:]
  source=source.replace('received.src >= 4','received.src >= NUM_TILES')
  source=source.replace('packet(CMD_COMPLETE, 4,','packet(CMD_COMPLETE, NUM_TILES,')
  source=source.replace('packet(CMD_LOAD_RESPONSE, 4,','packet(CMD_LOAD_RESPONSE, NUM_TILES,')
  start=source.index('      // Fixed-profile coverage');end=source.index('      if (cycle_count >= max_cycles)',start)
  source=source[:start]+'''      // Full-array links are checked on the independently generated gold hierarchy.
      // Native implementation hierarchy is intentionally not part of this TB contract.
      for(int i=0;i<NUM_TILES;i++) begin
        logic [DATA_W-1:0] expected_value;
        expected_value=i==0 ? scenario_input : i==1 ? scenario_input+DATA_W'(5) :
          (scenario_input+DATA_W'(5))*DATA_W'(3)-DATA_W'(8*(i-2));
        check_mesh_link(i,gold.tile__send_data__val[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          gold.tile__send_data__rdy[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          gold.tile__send_data__msg[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],expected_value);
      end
'''+source[end:]
  source=source.replace('input_packets >= 26','input_packets >= PACKET_COUNT')
  start=source.index('    case (tile_id)',source.index('task automatic program_tile'))
  end=source.index('    send_packet(packet(CMD_CONFIG_COUNT_PER_ITER',start)
  source=source[:start]+'''    if(tile_id==0) begin
      send_packet(packet(CMD_CONST,0,15,1));
      send_packet(packet(CMD_CONST,0,16,1));
    end else begin
      int position;
      position=0;
      for(int i=1;i<NUM_TILES;i++) if(chain[i]==tile_id) position=i;
      send_packet(packet(CMD_CONST,tile_id,position==1 ? DATA_W'(5) : position==2 ? DATA_W'(3) : DATA_W'(-8),1));
    end
'''+source[end:]
  source=source.replace("3'(step_id)","CTRL_ADDR_W'(step_id)")
  source=source.replace('tile_id < 4','tile_id < NUM_TILES')
  start=source.index('    send_packet(packet(CMD_LAUNCH, 2));');end=source.index('    queries_started = 1;',start)
  source=source[:start]+'''    for(int i=NUM_TILES-1;i>=0;i--) send_packet(packet(CMD_LAUNCH,chain[i]));
    while(completed_tiles != {NUM_TILES{1'b1}} || west_count != 1) tick();
'''+source[end:]
  source=source.replace('cycle_count != 64','cycle_count != expected_cycles')
  source=source.replace('input_packets != 26 || completion_count != 4','input_packets != PACKET_COUNT || completion_count != NUM_TILES')
  source=source.replace('$bits(tb_data_t) != 35','$bits(tb_data_t) != DATA_BITS').replace('$bits(tb_ctrl_t) != 119','$bits(tb_ctrl_t) != CTRL_BITS').replace('$bits(tb_payload_t) != 170','$bits(tb_payload_t) != PAYLOAD_BITS').replace('$bits(tb_packet_t) != 191','$bits(tb_packet_t) != HOST_BITS')
  location=source.index('    begin\n      int replay_fd;')
  source=source[:location]+'''    begin
      int n,meta_fd,got;
      n=0; chain[n++]=0;
      for(int y=0;y<ROWS;y++) begin
        if(y%2==0) for(int x=1;x<COLS;x++) chain[n++]=y*COLS+x;
        else for(int x=COLS-1;x>=1;x--) chain[n++]=y*COLS+x;
      end
      for(int y=ROWS-1;y>=1;y--) chain[n++]=y*COLS;
      if(n!=NUM_TILES || ROWS%2!=0 || COLS<2) $fatal(1,"Unsupported Hamiltonian test geometry");
      meta_fd=$fopen({vector_dir,"/replay_meta.txt"},"r");
      if(!meta_fd) $fatal(1,"Cannot read replay metadata");
      got=$fscanf(meta_fd,"%d %d",expected_cycles,expected_samples); $fclose(meta_fd);
      if(got!=2 || expected_samples!=2*(expected_cycles+3) || expected_samples>8192) $fatal(1,"Invalid replay metadata");
    end
'''+source[location:]
  source=source.replace('$readmemh({vector_dir, "/replay_inputs.hex"}, pymtl_inputs);','$readmemh({vector_dir, "/replay_inputs.hex"}, pymtl_inputs,0,expected_samples-1);')
  source=source.replace('$readmemh({vector_dir, "/replay_outputs.hex"}, pymtl_outputs);','$readmemh({vector_dir, "/replay_outputs.hex"}, pymtl_outputs,0,expected_samples-1);')
  start=source.index('    for (int i = 0; i < 2; i++) begin',source.index('  initial begin'))
  end=source.index('    run_scenario(0,',start)
  code=''
  for d in ['north','south','west','east']:
    dim='COLS' if d in ['north','south'] else 'ROWS'
    code+=f'    for(int i=0;i<{dim};i++) begin\n      recv_data_on_boundary_{d}__msg[i]=\'0;\n      recv_data_on_boundary_{d}__val[i]=0;\n      send_data_on_boundary_{d}__rdy[i]=1;\n    end\n'
  source=source[:start]+code+source[end:]
  source=source.replace("run_scenario(0, 32'd7)","run_scenario(0, DATA_W'(7))").replace("run_scenario(1, 32'hffff_fffa)","run_scenario(1, DATA_W'(-6))")
  source=source.replace('all_compared_cycles != 134 || pymtl_compared_cycles != 134','all_compared_cycles != expected_samples || pymtl_compared_cycles != expected_samples')
  source=source.replace('expected=134','expected=%0d').replace('all_compared_cycles, pymtl_compared_cycles);','all_compared_cycles, pymtl_compared_cycles,expected_samples);',1)
  start=source.index('    $display("CGRA_2X2_PASS');end=source.index('    $finish;',start)
  source=source[:start]+'''`ifdef PHASE2_REFERENCE_ONLY
    $display("PHASE2_REFERENCE_TEST_PASS geometry=%0dx%0d cycles=%0d pymtl_cycles=%0d bits=%0d",COLS,ROWS,all_compared_cycles,pymtl_compared_cycles,REPLAY_OUT_BITS);
`else
    $display("PHASE2_CGRA_PASS geometry=%0dx%0d cycles=%0d pymtl_cycles=%0d bits=%0d",COLS,ROWS,all_compared_cycles,pymtl_compared_cycles,REPLAY_OUT_BITS);
`endif
'''+source[end:]
  source=source.replace('// Fixed ac96a7 2x2 scalar acceptance test. This is not a parameterization claim.', '// ac96-derived whole-array scalar tests for the three explicitly validated geometries.')
  source=source.replace('// Fixed-profile coverage of all four directional internal links.', '// Whole-array Hamiltonian chain coverage.')
  source=source.replace('int mesh_link_count [0:NUM_TILES-1];','int mesh_link_count [0:NUM_TILES-1];\n  int native_mesh_link_count [0:NUM_TILES-1];')
  start=source.index('  task automatic check_mesh_link(')
  end=source.index('  task automatic tick();',start)
  task=source[start:end].replace('check_mesh_link','check_native_mesh_link').replace('mesh_link_count','native_mesh_link_count').replace('MESH_LINK','NATIVE_MESH_LINK')
  source=source[:end]+task+source[end:]
  marker='gold.tile__send_data__msg[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],expected_value);'
  source=source.replace(marker,marker+'''
`ifndef PHASE2_REFERENCE_ONLY
        check_native_mesh_link(i,dut.tile_send_val[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          dut.tile_send_rdy[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],
          dut.tile_send_msg[chain[i]][dir(chain[i],chain[(i+1)%NUM_TILES])],expected_value);
`endif''')
  source=source.replace('foreach (mesh_link_count[i]) mesh_link_count[i] = 0;', 'foreach (mesh_link_count[i]) mesh_link_count[i] = 0;\n    foreach (native_mesh_link_count[i]) native_mesh_link_count[i] = 0;')
  marker='if (mesh_link_count[i] != 1) $fatal(1, "Missing mesh link %0d", i);'
  source=source.replace(marker,marker+'''
`ifndef PHASE2_REFERENCE_ONLY
    foreach(native_mesh_link_count[i])
      if(native_mesh_link_count[i]!=1) $fatal(1,"Missing native mesh link %0d",i);
`endif''')
  source=source.replace('"Incomplete scenario replay: expected 64 post-reset cycles, got %0d", cycle_count', '"Incomplete scenario replay: expected %0d post-reset cycles, got %0d", expected_cycles, cycle_count')
  (ROOT/'sv/tests/phase2_tb_cgra_scalar.sv').write_text(source)
  for folder in (ROOT/'sv/vectors/phase2').iterdir():
    manifest=folder/'manifest.json'
    if not manifest.exists(): continue
    m=json.loads(manifest.read_text()); cycles=[s['cycles_after_reset'] for s in m['scenarios']]
    assert cycles[0]==cycles[1]
    (folder/'replay_meta.txt').write_text(f"{cycles[0]} {m['trace_rows']}\n")
  print('Wrote phase2_tb_cgra_scalar.sv and completed geometry replay metadata')


if __name__=='__main__': main()
