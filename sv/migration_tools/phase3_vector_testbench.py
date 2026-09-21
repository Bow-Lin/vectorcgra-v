"""Freeze SV-only differential benches and independent arithmetic assertions."""
from pathlib import Path
import argparse
import json
import re
from phase3_vector_port import ROOT, REF

OPS={
 'vector_adder':[2,25,3,4,36,31], 'vector_mul':[7],
 'vector_adder_combo':[51,71,53,73,52,72,54,74], 'vector_mul_combo':[55,75],
 'vector_all_reduce':[56,68,57,69,76,77,78,79],
 'seq_mul_adder':[18,30,29,19], 'seq_mul_shifter':[20,21],
 'prl_mul_adder':[18,19], 'three_mul_adder_shifter':[22,23,24],
 'four_inc_cmp_not_grant':[82], 'alu_gen_mac':[2,4,60,61,62,63,7,18],
 'alu_gen_mac_wrapper':list(range(64)),
}


def ports(info,ref):
  # Placeholder headers spell widths as [16-1:0], unlike translated modules.
  if info['native_module']!='cgra_alu_gen_mac': return info['ports']
  result=[]
  for direction,packed,name in re.findall(r'\b(input|output)\s+logic\s*(\[[0-9+* -]+:[0-9+* -]+\])?\s*(\w+)',(ref/'top_ports.txt').read_text()):
    width=1
    if packed:
      hi,lo=packed[1:-1].split(':');width=abs(eval(hi,{'__builtins__':{}})-eval(lo,{'__builtins__':{}}))+1
    result.append(dict(direction=direction,name=name,width=width,shape=''))
  return result


def arithmetic(case):
  if case=='alu_gen_mac_wrapper':
    return '''expected[0]=ip_value(i_rhs_0,i_rhs_1,i_rhs_1b,i_rhs_2);
      if(d_lhs_0 !== 16'(expected[0]))$fatal(1,"independent IP arithmetic cycle=%0d",cycle);
      arithmetic_checks++;'''
  base='''expected[0]='0;expected[1]='0;
      a=DATA_W'(i_recv_in__msg[0]>>3);b=DATA_W'(i_recv_in__msg[1]>>3);
      c=DATA_W'(i_recv_in__msg[2]>>3);d=DATA_W'(i_recv_in__msg[3]>>3);
      k=DATA_W'(i_recv_const__msg>>3);
      ix0=ctrl.fu_in[0]==0?0:(int'(ctrl.fu_in[0])-1)%4;
      ix1=ctrl.fu_in[1]==0?0:(int'(ctrl.fu_in[1])-1)%4;
      ix2=ctrl.fu_in[2]==0?0:(int'(ctrl.fu_in[2])-1)%4;
'''
  if case in ('vector_adder','vector_mul'):
    body='''if(i_recv_opt__val) begin
        a=128'(i_recv_in__msg[ix0]);b=128'(i_recv_in__msg[ix1]);k=128'(i_recv_const__msg);
'''
    if case=='vector_adder':
      body+='''case(ctrl.operation)
          2:expected[0]=a+b+(i_carry_in&i_combine_adder);
          25:expected[0]=a+k+(i_carry_in&i_combine_adder);
          3:expected[0]=a+1;
          4:expected[0]=a-b-(i_carry_in&i_combine_adder);
          36:expected[0]=a-k-(i_carry_in&i_combine_adder);
          31:expected[0]=a;
          default:begin end
        endcase
'''
    else: body+='        if(ctrl.operation==7)expected[0]=a*b;\n'
    body+='''end
      if($test$plusargs("EXPECT_FAILURE")&&cycle==64)begin
        expected[0]^=1;$display("intentional negative control: corrupt independent expected result");
      end
      if(d_send_out__msg[0] !== RESULT_W'(expected[0]))$fatal(1,"independent leaf arithmetic cycle=%0d op=%0d expected=%h got=%h",cycle,ctrl.operation,RESULT_W'(expected[0]),d_send_out__msg[0]);
      arithmetic_checks++;'''
    return base+body
  if case=='vector_adder_combo':
    body='''carry=0;
      if(i_recv_opt__val)for(int lane=0;lane<LANES;lane++)begin
        x=(a>>(lane*LANE_W))&lane_mask;y=(b>>(lane*LANE_W))&lane_mask;z=(k>>(lane*LANE_W))&lane_mask;
        temp=0;
        case(ctrl.operation)
          51:temp=x+y;
          71:temp=x+y+carry;
          53:temp=x-y;
          73:temp=x-y-carry;
          52,72:temp=x+z;
          54:temp=x-z;
          74:temp=x-z-carry;
          default:begin end
        endcase
        expected[0]|=(temp&lane_mask)<<(lane*LANE_W);
        carry=1'((temp>>LANE_W)&1);
      end
'''
  elif case=='vector_mul_combo':
    body='''if(i_recv_opt__val)begin
        // Independent lane product sum using the frozen RTLIR shift-width rule.
        if(ctrl.operation==55||ctrl.operation==75)for(int lane=0;lane<4;lane++)begin
          ix0=(ctrl.operation==55)?lane:lane/2;
          ix1=(ctrl.operation==55)?lane:lane%2;
          ix2=(ctrl.operation==55)?lane:(lane==3?2:(lane==0?0:1));
          ix2=(ix2*LANE_W)% (1<< (($clog2(LANE_W+1)>2)?$clog2(LANE_W+1):2));
          expected[0]+=(((a>>(ix0*LANE_W))&lane_mask)*((b>>(ix1*LANE_W))&lane_mask))<<ix2;
        end
      end
'''
  elif case=='vector_all_reduce':
    body='''x=0;y=1;
      for(int lane=0;lane<LANES;lane++)begin x=DATA_W'(x+((a>>(lane*LANE_W))&lane_mask));y=DATA_W'(y*((a>>(lane*LANE_W))&lane_mask));end
      case(ctrl.operation)
        56:expected[0]=x;
        68:expected[0]=x+b;
        57:expected[0]=y;
        69:expected[0]=y*b;
        76,77:expected[0]=response.data.payload;
        78:expected[0]=response.data.payload+b;
        79:expected[0]=response.data.payload*b;
        default:begin end
      endcase
      if(dut.already_sent_to_controller!==model_sent)$fatal(1,"independent controller state cycle=%0d",cycle);
      if(d_send_to_ctrl_mem__val&&(ctrl.operation==77||ctrl.operation==79))begin
        if(sent_payload.data.payload!==0)$fatal(1,"ac96 global MUL uses zero add reduction");
        legacy_defect_checks++;
      end
      if(i_reset)model_sent=0;
      else if(i_recv_opt__val&&(ctrl.operation>=76&&ctrl.operation<=79)&&!model_sent&&d_send_to_ctrl_mem__val&&i_send_to_ctrl_mem__rdy)model_sent=1;
      else if(i_recv_opt__val&&(ctrl.operation>=76&&ctrl.operation<=79)&&model_sent&&d_recv_opt__rdy)model_sent=0;
'''
  elif case=='seq_mul_adder':
    body='''if(i_recv_opt__val)case(ctrl.operation)
        18:expected[0]=DATA_W'(a*b)+c;
        19:expected[0]=DATA_W'(a*b)-c;
        30:expected[0]=DATA_W'(a*k)+c;
        29:expected[0]=DATA_W'(a*k);
        default:begin end
      endcase
'''
  elif case=='seq_mul_shifter':
    body='''if(i_recv_opt__val)case(ctrl.operation)
        20:expected[0]=(c>=DATA_W)?0:(DATA_W'(a*b)<<c);
        21:expected[0]=(c>=DATA_W)?0:(DATA_W'(a*b)>>c);
        default:begin end
      endcase
'''
  elif case=='prl_mul_adder':
    body='''if(i_recv_opt__val&&(ctrl.operation==18||ctrl.operation==19))begin
        expected[0]=a*b;expected[1]=(ctrl.operation==18)?c+d:c-d;
      end
'''
  elif case=='three_mul_adder_shifter':
    body='''if(i_recv_opt__val&&(ctrl.operation==22||ctrl.operation==23||ctrl.operation==24))begin
        x=DATA_W'(a*b);y=DATA_W'((ctrl.operation==22)?c+d:c-d);
        expected[0]=(y>=DATA_W)?0:((ctrl.operation==24)?x>>y:x<<y);
        expected[1]=expected[0];
      end
'''
  elif case=='four_inc_cmp_not_grant':
    body='''if(i_recv_opt__val&&ctrl.operation==82)begin
        expected[0]=(DATA_W'(a+1)==DATA_W'(k));expected[1]=DATA_W'(a+1);
      end
'''
  elif case=='alu_gen_mac':
    body='''if(!i_send_out__rdy[0])begin ix0=0;ix1=0;ix2=0;end
      ip_op=0;
      case(ctrl.operation)
        2:ip_op=0;4:ip_op=1;60:ip_op=3;61:ip_op=7;
        62:ip_op=10;63:ip_op=14;7:ip_op=16;18:ip_op=48;
        default:begin end
      endcase
      if(i_recv_opt__val&&supported)begin
        held_a=16'(i_recv_in__msg[ix0]>>3);held_b=16'(i_recv_in__msg[ix1]>>3);held_c=16'(i_recv_in__msg[ix2]>>3);
      end
      if(i_recv_opt__val)expected[0]=ip_value(held_a,held_b,held_c,ip_op);
'''
  else:raise ValueError(case)
  body+='''if(d_send_out__msg[0][DATA_BITS-1:3] !== DATA_W'(expected[0]))
        $fatal(1,"independent arithmetic cycle=%0d op=%0d expected=%h got=%h",cycle,ctrl.operation,DATA_W'(expected[0]),d_send_out__msg[0][DATA_BITS-1:3]);
      arithmetic_checks++;
'''
  if case in ('prl_mul_adder','three_mul_adder_shifter','four_inc_cmp_not_grant'):
    body+='''if(d_send_out__msg[1][DATA_BITS-1:3] !== DATA_W'(expected[1]))$fatal(1,"independent second result cycle=%0d",cycle);
'''
  if case in ('seq_mul_adder','seq_mul_shifter','prl_mul_adder','four_inc_cmp_not_grant','alu_gen_mac'):
    state='dut.vector_factor_counter' if case=='alu_gen_mac' else 'dut.Fu0.vector_factor_counter'
    body+=f'''if({state}!==model_counter)$fatal(1,"independent vector counter cycle=%0d expected=%0d got=%0d",cycle,model_counter,{state});
      if(i_reset)model_counter=0;
      else if(i_recv_opt__val&&ctrl.is_last_ctrl)begin
        if(8'(model_counter+1)<(8'd1<<ctrl.vector_factor_power))model_counter=8'(model_counter+1);
        else model_counter=0;
      end
'''
  return base+body


def main():
  p=argparse.ArgumentParser();p.add_argument('--label');a=p.parse_args()
  refs=[REF/a.label] if a.label else sorted(REF.iterdir())
  for ref in refs:
    if not (ref/'manifest.json').exists():continue
    info=json.loads((ref/'manifest.json').read_text())
    if info['status']!='exported':continue
    case=next(c for c in sorted(OPS,key=len,reverse=True) if info['label'].startswith(c+'_w'))
    ps=ports(info,ref); width=info['parameters']['DATA_W']; lanes=info['parameters']['LANES']
    lane=info['parameters']['LANE_W'] if case in ['vector_adder','vector_mul'] else width//lanes
    leaf=case in ('vector_adder','vector_mul'); wrapper=case=='alu_gen_mac_wrapper'
    legacy=info.get('control_fu_inputs',4)==2
    out=ROOT/'sv/tests/phase3/vector_combo'/info['label'];out.mkdir(parents=True,exist_ok=True)
    code=['`timescale 1ns/1ps','`include "cgra_profile_defs.svh"','module tb_phase3_vector;',
      f'  localparam int DATA_W={width}, LANES={lanes}, LANE_W={lane}, DATA_BITS=DATA_W+3;',
      '  localparam int REG_ADDR_W=4, GLOBAL_ADDR_W=7, CTRL_ADDR_W=3, TILE_ID_W=3, MEM_PORT_W=2, BANK_PORT_W=2, ROUTING_OUTPUTS=8, ROUTING_SEL_W=4;',
      '  `include "cgra_profile.svh"',f'  localparam int RESULT_W={lane+1 if case=="vector_adder" else 2*lane if leaf else width};',
      '  logic clock=0;always #5 clock=~clock;',
      '  logic [31:0] rng=32\'h3b123456;',
      '  function automatic logic [31:0] next_word();rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return rng;endfunction',
      '  function automatic logic [255:0] random_bits();return {next_word(),next_word(),next_word(),next_word(),next_word(),next_word(),next_word(),next_word()};endfunction',
      '  function automatic logic [15:0] ip_value(input logic[15:0]aa,bb,cc,input logic[5:0]mode);',
      '    logic [15:0] tmp;tmp=mode[4]?(aa*bb+(mode[5]?cc:16\'d0)):((mode[3]?~aa:aa)+(mode[0]?~bb:bb));',
      '    tmp=tmp+16\'(mode[0]|mode[3]);return mode[1]?{15\'d0,(mode[2]^tmp[15])}:tmp;endfunction',
      f'  int operations[0:{len(OPS[case])-1}]=\'{{'+','.join(map(str,OPS[case]))+'};',
      f'  int op_hits[0:{len(OPS[case])-1}];',
      '  int cycle=0,arithmetic_checks=0,stall_checks=0,valid_outputs=0,legacy_defect_checks=0;logic supported;',
      '  logic [127:0] expected[0:1],a,b,c,d,k,x,y,z,temp;logic [127:0]lane_mask=(128\'(1)<<LANE_W)-1;',
      '  int ix0,ix1,ix2;logic carry,model_sent=0;logic [7:0]model_counter=0;',
      '  logic [15:0]held_a=0,held_b=0,held_c=0;logic [5:0]ip_op;',
      '  ctrl_t ctrl;payload_t response,sent_payload;string result_path;integer fd;']
    bindings_g=[];bindings_d=[];drive=[];compare=[]
    for port in ps:
      name=port['name'];bits=port['width'];shape=port['shape'];direction=port['direction']
      if name=='clk':
        bindings_g.append('.clk(clock)');bindings_d.append('.clk(clock)');continue
      native_bits=119 if legacy and name=='recv_opt__msg' else width+138 if legacy and name in ['recv_from_ctrl_mem__msg','send_to_ctrl_mem__msg'] else bits
      if direction=='input':
        code.append(f'  logic [{native_bits-1}:0] i_{name} {shape};')
        bindings_d.append(f'.{name}(i_{name})')
        if name=='recv_opt__msg':
          code.append(f'  assign i_{name}=ctrl;')
          if legacy:
            code.append(f'  logic [{bits-1}:0] legacy_ctrl;')
            for field in info['types']['control']['fields']:
              code.append(f"  assign legacy_ctrl[{field['msb']}:{field['lsb']}]={field['nbits']}'(ctrl.{field['field']});")
            bindings_g.append('.recv_opt__msg(legacy_ctrl)')
          else:bindings_g.append(f'.{name}(i_{name})')
        else:
          bindings_g.append(f'.{name}(i_{name})')
          if shape:
            low,high=map(int,re.findall(r'\d+',shape));
            drive.extend(f'      i_{name}[{n}]={native_bits}\'(random_bits());' for n in range(low,high+1))
          else:drive.append(f'      i_{name}={native_bits}\'(random_bits());')
      else:
        code.extend([f'  logic [{native_bits-1}:0] d_{name} {shape};',f'  logic [{bits-1}:0] g_{name} {shape};'])
        bindings_d.append(f'.{name}(d_{name})');bindings_g.append(f'.{name}(g_{name})')
        suffixes=['']
        if shape:
          low,high=map(int,re.findall(r'\d+',shape));suffixes=[f'[{n}]' for n in range(low,high+1)]
        for suff in suffixes:
          compare.append(f'      if(d_{name}{suff} !== {native_bits}\'(g_{name}{suff}))$fatal(1,"P3_VECTOR_DIFF cycle=%0d port={name}{suff} native=%h gold=%h",cycle,d_{name}{suff},g_{name}{suff});')
    parameters=f'.DATA_W({width})'
    if leaf:parameters+=f',.LANE_W({lane})'
    elif case.startswith('vector_'):parameters+=f',.LANES({lanes}),.VECTOR_FACTOR_POWER({info["parameters"]["VECTOR_FACTOR_POWER"]})'
    code.append('  '+info['native_module']+(' #('+parameters+')' if not wrapper else '')+' dut ('+','.join(bindings_d)+');')
    code.append('  '+info['top']+' gold ('+','.join(bindings_g)+');')
    if not leaf and not wrapper:
      code.extend(['  assign response=i_recv_from_ctrl_mem__msg;','  assign sent_payload=d_send_to_ctrl_mem__msg;'])
    code+=['  initial begin',f'    for(int n=0;n<{len(OPS[case])};n++)op_hits[n]=0;',
      '    for(cycle=0;cycle<640;cycle++)begin','      @(negedge clock);']+drive
    code+=['      i_reset=(cycle<2)||(cycle==320)||(cycle==321);',
      '      ctrl=119\'(random_bits());',f"      ctrl.operation=(cycle%({len(OPS[case])}+1)=={len(OPS[case])})?7'd127:7'(operations[cycle%({len(OPS[case])}+1)]);",
      "      ctrl.vector_factor_power=(cycle>=128&&cycle<400)?3'd7:3'(cycle/16);",
      "      ctrl.is_last_ctrl=(cycle>=128&&cycle<400)?1'b1:1'(next_word());"]
    if wrapper:
      code+=['      i_rhs_2=6\'(cycle);','      supported=1;']
    else:
      code+=['      i_recv_opt__val=(cycle>=128&&cycle<400)?1:((cycle%5)!=0);',
        '      supported=0;',f'      for(int n=0;n<{len(OPS[case])};n++)if(ctrl.operation==operations[n])supported=1;']
      if not leaf:
        # Keep useful shifts, zero/small operands, and carry/overflow patterns.
        code+=['      if(cycle%4==0)for(int n=0;n<4;n++)i_recv_in__msg[n][DATA_BITS-1:3]=DATA_W\'(n+cycle%7);',
          '      if(cycle%16==1)for(int n=0;n<4;n++)i_recv_in__msg[n][DATA_BITS-1:3]=\'1;',
          '      if(cycle%16==2)for(int n=0;n<4;n++)i_recv_in__msg[n][DATA_BITS-1:3]=\'0;',
          '      if(cycle%4==0)i_recv_in__msg[2][DATA_BITS-1:3]=DATA_W\'(cycle%DATA_W);']
    if case=='vector_mul_combo':
      code += ["      if(cycle==1)begin i_recv_in__msg[0][DATA_BITS-1:3]=DATA_W'(1)<<LANE_W;i_recv_in__msg[1][DATA_BITS-1:3]=DATA_W'(1)<<LANE_W;end"]
    code+=['      @(posedge clock);']+compare
    if case=='vector_mul_combo':
      code += ['      if(cycle==1)$display("HDL_SHIFT_WITNESS width=%0d lanes=%0d op=%0d a=%h b=%h native=%h gold=%h shift2=%0d shift3=%0d",DATA_W,LANES,ctrl.operation,i_recv_in__msg[0]>>3,i_recv_in__msg[1]>>3,d_send_out__msg[0]>>3,g_send_out__msg[0]>>3,dut.SHIFT_TWO,dut.SHIFT_THREE);']
    if wrapper:code+=['      op_hits[int\'(i_rhs_2)]++;']
    else:
      code += [f'      for(int n=0;n<{len(OPS[case])};n++)if(ctrl.operation==operations[n]&&i_recv_opt__val)op_hits[n]++;',
        '      if(i_recv_opt__val&&!i_send_out__rdy[0])stall_checks++;',
        '      if(d_send_out__val[0])valid_outputs++;']
    code += ['      '+arithmetic(case),
      '      if($test$plusargs("EXPECT_FAILURE")&&cycle==64)$fatal(1,"intentional negative control: result checker exercised");',
      '    end',f'    for(int n=0;n<{len(OPS[case])};n++)if(op_hits[n]==0)$fatal(1,"operation not exercised op=%0d",operations[n]);',
      '    if(arithmetic_checks!=640)$fatal(1,"arithmetic coverage incomplete");']
    if not wrapper:code+=['    if(stall_checks<50||valid_outputs<10)$fatal(1,"handshake coverage incomplete");']
    report_text = '{\n  "label": "'+info['label']+'",\n  "status": "pass",\n  "cycles": 640,\n  "seed": "3b123456",\n  "raw_invalid_comparison": true,\n  "arithmetic_checks": %0d,\n  "stall_samples": %0d,\n  "valid_output_samples": %0d,\n  "legacy_defect_checks": %0d,\n  "operation_hits": ['
    code += ['    if(!$value$plusargs("RESULT=%s",result_path))result_path="result.json";',
      '    fd=$fopen(result_path,"w");if(fd==0)$fatal(1,"cannot write result JSON");',
      '    $fwrite(fd,'+json.dumps(report_text)+',arithmetic_checks,stall_checks,valid_outputs,legacy_defect_checks);',
      f'    for(int n=0;n<{len(OPS[case])};n++)$fwrite(fd,"%s%0d",n==0?"":",",op_hits[n]);',
      '    $fwrite(fd,"]\\n}\\n");$fclose(fd);',
      f'    $display("P3_VECTOR_PASS label={info["label"]} cycles=640 arithmetic=%0d stalls=%0d valid=%0d",arithmetic_checks,stall_checks,valid_outputs);',
      '    $finish;','  end','endmodule']
    (out/'tb.sv').write_text('\n'.join(code)+'\n',newline='\n')
    (out/'test.json').write_text(json.dumps(dict(label=info['label'],case=case,reference=str(ref.relative_to(ROOT/'sv')).replace('\\','/'),
      native_module=info['native_module'],parameters=info['parameters'],opcodes=OPS[case],legacy_ctrl_adapter=legacy,
      cycles=640,seed='3b123456',oracle='translated_hdl',python_equivalence=False if case=='vector_mul_combo' else 'not_claimed'),indent=2)+'\n',newline='\n')
    print('TEST '+info['label'])


if __name__=='__main__':main()
