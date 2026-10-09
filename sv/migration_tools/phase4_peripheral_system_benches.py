"""Retained full-system SV benches with original HDL and independent memory checks."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];TEST=ROOT/'sv/tests/phase4/peripheral'
def packed32(values):return f"{len(values)*32}'h"+''.join(f'{v&0xffffffff:08x}' for v in reversed(values))
def main(kind):
  m=json.loads((ROOT/'sv/reference/phase4/peripheral'/kind/'manifest.json').read_text());p=dict(m['parameters']);dma=kind=='dma-system'
  # Original FlexibleFuRTL appends Nah to configured lists that omit it.
  if 3 not in p['FU_KINDS']:
    p['FU_KINDS']=p['FU_KINDS']+[3];p['FU_COUNT']=len(p['FU_KINDS'])
  host=m['types']['host']['nbits'];ctrl=m['types']['ctrl']['nbits'];top='tb_'+kind.replace('-','_')
  lines=['`timescale 1ns/1ps',f'module {top};',f'  localparam int HOST_BITS={host},CTRL_BITS={ctrl},PAYLOAD_BITS=6+35+6+CTRL_BITS+3;',
    '  int cycles=0,done_count=0,load_count=0,blocked_cycles=0;']
  ports=[]
  for decl in m['top_port_declarations']:
    match=re.match(r'\s*(input|output)\s+(\w+)(?:\s*\[(\d+):(\d+)\])?\s+(\w+)(?:\s*\[0:(\d+)\])?',decl)
    if not match:raise ValueError(decl)
    direction,typ,hi,lo,name,count=match.groups();count=int(count)+1 if count else 0
    width=(int(hi)-int(lo)+1) if hi else (35 if typ.startswith('CgraData') else 208 if typ.startswith('DmaDram') else host)
    dims=f' [0:{count-1}]' if count else '';ports.append((direction,name,width,count))
    lines.append(f'  logic[{width-1}:0] {name}{dims}'+(';' if count or direction=='output' else '=0;'))
    if direction=='output':lines.append(f'  logic[{width-1}:0] gold_{name}{dims};')
  nativeparams=[]
  for k,v in p.items():
    if isinstance(v,int):nativeparams.append(f'.{k}({v})')
  nativeparams.append(f'.FU_KINDS({len(p["FU_KINDS"])*8}\'h'+''.join(f'{v:02x}' for v in reversed(p['FU_KINDS']))+')')
  if dma:
    links=p['links'];nativeparams += [f'.LINK_COUNT({len(links)})',f'.LINK_ENABLED({len(links)}\'h{(1<<len(links))-1:x})']
    for name,key in [('LINK_SRC_TILE','src_tile'),('LINK_SRC_PORT','src_port'),('LINK_DST_TILE','dst_tile'),('LINK_DST_PORT','dst_port')]:nativeparams.append(f'.{name}({packed32([x[key] for x in links])})')
    for name in ['READ_PORT_TILE','WRITE_PORT_TILE']:nativeparams.append(f'.{name}({packed32(p[name])})')
  else:
    image=sum(v<<(32*i) for i,v in enumerate(p['preload_image']))
    nativeparams.append(f'.PRELOAD_IMAGE({p["SCRATCH_DEPTH"]*32}\'h{image:x})')
  nativebinds=[f'.{n}({n})' for _,n,_,_ in ports]
  nativebinds+=['.recv_from_inter_cgra_noc__msg(\'0)','.recv_from_inter_cgra_noc__val(1\'b0)','.recv_from_inter_cgra_noc__rdy()',
    '.send_to_inter_cgra_noc__msg()','.send_to_inter_cgra_noc__val()','.send_to_inter_cgra_noc__rdy(1\'b0)']
  if dma:
    lines+=['  logic[34:0] zero_data[0:1];logic zero_bit[0:1];']
    for side in ['east','north','south','west']:
      nativebinds += [f'.recv_data_on_boundary_{side}__msg(zero_data)',f'.recv_data_on_boundary_{side}__val(zero_bit)',f'.recv_data_on_boundary_{side}__rdy()',
        f'.send_data_on_boundary_{side}__msg()',f'.send_data_on_boundary_{side}__val()',f'.send_data_on_boundary_{side}__rdy(zero_bit)']
  lines.append(f'  cgra_integrated_{"dma" if dma else "im2col"} #(\n    '+',\n    '.join(nativeparams)+') dut (\n    '+',\n    '.join(nativebinds)+'\n  );')
  lines.append(f'  {m["top"]} gold (\n    '+',\n    '.join(f'.{n}({n if d=="input" else "gold_"+n})' for d,n,_,_ in ports)+'\n  );')
  outs=[]
  for d,n,w,c in ports:
    if d=='output':outs.extend([f'{n}[{i}]' for i in range(c)] if c else [n])
  lines += ['  task automatic compare_outputs;',
    '    if({'+','.join(outs)+'}!==({'+','.join('gold_'+x for x in outs)+'} ^ (($test$plusargs("EXPECT_FAILURE") && cycles==20)?1:0)))begin',
    *[f'      if({x}!==gold_{x})$display("{x}: native=%h gold=%h",{x},gold_{x});' for x in outs],
    f'      $fatal(1,"{kind} mismatch cycle=%0d",cycles);end',
    '  endtask',r'''
  function automatic logic[HOST_BITS-1:0] packet(input int cmd,input logic[31:0] value,input int addr);
    logic[HOST_BITS-1:0] p;p=0;p[3+CTRL_BITS+:6]=6'(addr);
    p[3+CTRL_BITS+6+:35]={value,3'b100};p[PAYLOAD_BITS-6+:6]=6'(cmd);return p;
  endfunction
  function automatic logic[31:0] word_pattern(input int i);return 32'h12340011+32'(i)*32'h10023;endfunction
  logic[31:0] expected_load[0:63];int expected_loads=0;int expected_tag=0;
  task automatic sample_cpu;
    if(!reset && !recv_from_cpu_pkt__rdy)blocked_cycles++;
    if(!reset && send_to_cpu_pkt__val && send_to_cpu_pkt__rdy)begin
      if(send_to_cpu_pkt__msg[PAYLOAD_BITS-6+:6]==51)begin
        if(send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]!==32'(expected_tag) || send_to_cpu_pkt__msg[PAYLOAD_BITS+1+:8]!==8'(expected_tag))
          $fatal(1,"Integrated DMA done tag");done_count++;
      end else if(send_to_cpu_pkt__msg[PAYLOAD_BITS-6+:6]==11)begin
        if(load_count>=expected_loads || send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]!==expected_load[load_count])
          $fatal(1,"Integrated load %0d expected=%h got=%h",load_count,expected_load[load_count],send_to_cpu_pkt__msg[3+CTRL_BITS+6+3+:32]);
        load_count++;
      end else $fatal(1,"Unexpected CPU response command");
    end
  endtask
''']
  if dma:lines.append(r'''
  bit read_pending=0,ack_pending=0;int read_due,ack_due,read_beats=0,write_beats=0;logic[127:0] read_data;
  task automatic step;
    send_to_cpu_pkt__rdy=cycles%7<4;send_to_dram_rd_req__rdy=cycles%5<3;send_to_dram_wr_req__rdy=cycles%6<3;
    recv_from_dram_rd_resp__val=read_pending && cycles>=read_due;recv_from_dram_rd_resp__msg=read_data;
    recv_from_dram_wr_resp__val=ack_pending && cycles>=ack_due;
    #3;compare_outputs();sample_cpu();
    if(recv_from_dram_rd_resp__val && recv_from_dram_rd_resp__rdy)read_pending=0;
    if(recv_from_dram_wr_resp__val && recv_from_dram_wr_resp__rdy)ack_pending=0;
    if(!reset && send_to_dram_rd_req__val && send_to_dram_rd_req__rdy)begin
      if(send_to_dram_rd_req__msg!==64'h123400000100+64'(16*read_beats) || read_pending)$fatal(1,"Integrated DRAM read address");
      for(int j=0;j<4;j++)read_data[j*32+:32]=word_pattern(read_beats*4+j);
      read_pending=1;read_due=cycles+3;read_beats++;
    end
    if(!reset && send_to_dram_wr_req__val && send_to_dram_wr_req__rdy)begin
      logic[127:0] data_expected;logic[15:0] mask_expected;
      if(write_beats==0)begin data_expected={word_pattern(1),word_pattern(0),word_pattern(1),word_pattern(0)};mask_expected=16'hffff;end
      else begin data_expected={96'b0,word_pattern(4)};mask_expected=16'h000f;end
      if(send_to_dram_wr_req__msg!=={64'h123400000200+64'(16*write_beats),data_expected,mask_expected} || ack_pending)
        $fatal(1,"Integrated DRAM write baseline beat %0d",write_beats);
      ack_pending=1;ack_due=cycles+4;write_beats++;
    end
    #2;clk=1;#5;clk=0;cycles++;if(cycles>2500)$fatal(1,"Integrated DMA TIMEOUT");
  endtask
''')
  else:lines.append(r'''
  task automatic step;
    send_to_cpu_pkt__rdy=cycles%7<4;
    #3;compare_outputs();sample_cpu();#2;clk=1;#5;clk=0;cycles++;
    if(cycles>2500)$fatal(1,"Integrated Im2col TIMEOUT");
  endtask
''')
  lines.append(r'''
  task automatic command(input int cmd,input logic[31:0] data,input int addr);
    bit accepted;accepted=0;recv_from_cpu_pkt__val=1;recv_from_cpu_pkt__msg=packet(cmd,data,addr);
    while(!accepted)begin #1;accepted=recv_from_cpu_pkt__rdy;step();end
    recv_from_cpu_pkt__val=0;
  endtask
''')
  if dma:lines.append(r'''
  task automatic dma_command(input int cmd,input int lowaddr,input int tag);
    expected_tag=tag;command(44,32'(lowaddr),0);command(45,32'h1234,0);command(46,0,4);
    command(47,20,0);command(48,32'(tag),0);command(cmd,0,0);
  endtask
  initial begin
    for(int i=0;i<2;i++)begin zero_data[i]=0;zero_bit[i]=0;end
    address_lower=0;address_upper=15;reset=1;repeat(3)step();reset=0;step();
    dma_command(49,'h100,'h5a);while(done_count<1)step();
    expected_loads=5;
    for(int i=0;i<5;i++)expected_load[i]=word_pattern(i==2?0:i==3?1:i);
    for(int i=0;i<5;i++)command(10,0,4+i);
    while(load_count<5)step();
    dma_command(50,'h200,'ha5);while(done_count<2)step();repeat(12)step();
    if(read_beats!=2 || write_beats!=2 || done_count!=2 || load_count!=5)$fatal(1,"Integrated DMA coverage");
    $display("DMA_SYSTEM_PASS cycles=%0d done=%0d loads=%0d read_beats=%0d write_beats=%0d preserved_wrong_mvin_words=2",cycles,done_count,load_count,read_beats,write_beats);$finish;
  end
endmodule
''')
  else:
    lines.append('  initial begin')
    for d,n,w,c in ports:
      if d=='input' and c:lines.append(f'    for(int i=0;i<{c};i++){n}[i]=0;')
    lines.append(r'''
    address_lower=0;address_upper=63;reset=1;repeat(3)step();reset=0;step();
    command(53,3,0);command(54,3,0);command(55,2,0);command(56,2,0);command(57,0,0);command(58,0,8);command(52,0,0);
    repeat(140)step();
    expected_loads=16;
    begin:int_expected
      int i;i=0;
      for(int ky=0;ky<2;ky++)for(int kx=0;kx<2;kx++)for(int oy=0;oy<2;oy++)for(int ox=0;ox<2;ox++)begin
        expected_load[i]=32'(3+17*((oy+ky)*3+ox+kx));i++;
      end
    end
    for(int i=0;i<16;i++)command(10,0,8+i);
    while(load_count<16)step();repeat(12)step();
    if(done_count!=0 || blocked_cycles<16)$fatal(1,"Integrated Im2col gate/response coverage");
    $display("IM2COL_SYSTEM_PASS cycles=%0d loads=%0d CPU_blocked_cycles=%0d",cycles,load_count,blocked_cycles);$finish;
  end
endmodule
''')
  (TEST/(top+'.sv')).write_text('\n'.join(lines)+'\n',newline='\n')
if __name__=='__main__':
  for k in ['dma-system','im2col-system']:main(k)
