"""Draw the delivered phase 1-4 architecture. Diagram tooling only; never used by RTL builds."""
from pathlib import Path
from html import escape
import json

OUT=Path(__file__).resolve().parent
W,H=2400,1370
C=dict(ink='#17232d',muted='#667585',border='#bac7d1',blue='#2563eb',teal='#0e8b78',orange='#ce7a16',zoom='#94a3b8',greenfill='#e6f3e7',bluefill='#eaf2ff',amberfill='#fff0db',pinkfill='#fbe5e5',purplefill='#f1edff')
background=[];edges=[];nodes=[];labels=[]
boxmap={};textchecks=[]

def txt(x,y,text,size=23,fill=None,anchor='middle',weight=400,target=None,max_width=None):
    labels.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}" font-weight="{weight}" fill="{fill or C["ink"]}">{escape(text)}</text>')
    if max_width:textchecks.append(dict(text=text,size=size,max_width=max_width,target=target))

def rect(dest,id,x,y,w,h,fill='#ffffff',stroke=None,role='node',dash=None,sw=1.8,rx=7):
    dashattr=f' stroke-dasharray="{dash}"' if dash else ''
    dest.append(f'<rect id="{id}" data-graph-role="{role}" data-node-id="{id}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke or C["border"]}" stroke-width="{sw}"{dashattr}/>')
    if role=='node':boxmap[id]=(x,y,w,h)

def card(id,x,y,w,h,title,sub=None,fill='#ffffff',stroke=None,size=25,sw=1.8):
    rect(nodes,id,x,y,w,h,fill,stroke,sw=sw)
    if sub:
        txt(x+w/2,y+h/2-5,title,size,weight=600,target=id,max_width=w-22)
        txt(x+w/2,y+h/2+25,sub,19,fill=C['muted'],target=id,max_width=w-22)
    else:txt(x+w/2,y+h/2+8,title,size,weight=600,target=id,max_width=w-22)

def edge(id,points,source=None,target=None,color='blue',both=False,dash=False,sw=2.5,arrows=True):
    points=' '.join(f'{x},{y}' for x,y in points)
    markers=f' marker-end="url(#arrow-{color})"' if arrows else ''
    if both:markers+=f' marker-start="url(#arrow-{color})"'
    dashattr=' stroke-dasharray="8 6"' if dash else ''
    edges.append(f'<polyline id="{id}" data-graph-role="edge" data-edge-id="{id}" data-source="{source or ""}" data-target="{target or ""}" points="{points}" fill="none" stroke="{C[color]}" stroke-width="{sw}" stroke-linejoin="round"{markers}{dashattr}/>')

def zoom(id,p1,p2):
    background.append(f'<path id="{id}" data-graph-role="decoration" d="M {p1[0]} {p1[1]} L {p2[0]} {p2[1]}" fill="none" stroke="{C["zoom"]}" stroke-width="1.8" stroke-dasharray="7 7"/>')

# Title and quiet section headers.
txt(60,74,'VectorCGRA 原生 SystemVerilog 架构',43,anchor='start',weight=600)
txt(60,119,'已迁移功能：阶段 1–4  |  系统组织 → 单 CGRA → 标准 Tile',24,C['muted'],anchor='start')
for x,num,title in [(60,'01','主机与多 CGRA'),(680,'02','单 CGRA · 4×4 Tiles 示例'),(1490,'03','标准 Tile 内部结构')]:
    txt(x,195,num,25,C['teal'],anchor='start',weight=600)
    txt(x+55,195,title,29,anchor='start',weight=600)
    background.append(f'<line data-graph-role="decoration" x1="{x}" y1="213" x2="{x+(500 if x==60 else 690 if x==680 else 850)}" y2="213" stroke="#d7e0e6" stroke-width="1.5"/>')

# 01 — Host-only multi-CGRA view.
card('host',100,245,405,78,'CPU / Host','配置、启动、查询与完成响应',C['amberfill'])
for i,(x,y) in enumerate([(100,420),(335,420),(100,770),(335,770)]):
    card(f'cgra{i}',x,y,170,110,f'CGRA {i}','Host 入口' if i==0 else '控制器 + Tiles',C['greenfill'],C['teal'] if i==1 else '#a9cbb3',24,sw=2.7 if i==1 else 1.8)
edge('host_command',[(150,323),(150,420)],'host','cgra0',color='orange')
edge('host_response',[(220,420),(220,323)],'cgra0','host')
txt(112,374,'命令',19,C['orange']);txt(263,374,'响应',19,C['blue'])
card('inter_noc',100,600,405,88,'跨 CGRA 报文 NoC','Mesh / Ring · 控制包与远程访存',C['bluefill'],size=27)
for i,x in [(0,185),(1,420)]:edge(f'noc_top_{i}',[(x,530),(x,600)],f'cgra{i}','inter_noc',both=True)
for i,x in [(2,185),(3,420)]:edge(f'noc_bottom_{i}',[(x,688),(x,770)],'inter_noc',f'cgra{i}',both=True)
edge('boundary_top',[(270,475),(335,475)],'cgra0','cgra1','teal',both=True)
edge('boundary_bottom',[(270,825),(335,825)],'cgra2','cgra3','teal',both=True)
txt(302,925,'相邻 Tile 边界另有直接数据连接',21,C['teal'])
txt(302,959,'图中仅示出水平方向边界连接',19,C['muted'])
txt(302,1019,'同构 / 异构阵列',25,weight=600)
txt(302,1056,'已验证：4×(4×4) = 64 Tiles',22,C['muted'])
txt(302,1087,'异构实例：2×2 / 3×3 / 2×2 / 2×2',18,C['muted'])
zoom('expand_cgra_top',(505,420),(680,242));zoom('expand_cgra_bottom',(505,530),(680,1100))

# 02 — Shared memory is one logical banked store, independent of tile count.
rect(background,'cgra_frame',680,235,690,870,'#fbfdfb','#bdd2c2','container',rx=10)
card('controller',800,250,455,85,'Controller','命令派发 · 地址映射 · 全局归约',C['amberfill'],size=27)
rect(background,'control_ring',745,405,560,460,'#fffdf8','#dba95f','container',dash='8 6',rx=10)
txt(1025,385,'控制环：配置 / 启动 / 完成',22,C['orange'])
edge('controller_ring',[(800,290),(720,290),(720,440),(745,440)],'controller','control_ring','orange',dash=True)
# A small marker makes the control-ring attachment explicit.
background.append('<circle data-graph-role="decoration" cx="745" cy="440" r="4" fill="#ce7a16"/>')
for row in range(4):
    for col in range(4):
        t=(3-row)*4+col;x=785+col*130;y=445+row*105
        card(f'tile{t}',x,y,90,60,f'Tile {t}',fill='#edf7ee',stroke=C['teal'] if t==15 else '#bfd4c4',size=20,sw=2.7 if t==15 else 1.5)
        if col<3:edge(f'tile_h_{row}_{col}',[(x+90,y+30),(x+130,y+30)],f'tile{t}',f'tile{t+1}',both=True,sw=1.8)
        if row<3:edge(f'tile_v_{row}_{col}',[(x+45,y+60),(x+45,y+105)],f'tile{t}',f'tile{t-4}',both=True,sw=1.8)
rect(background,'spm_group',755,930,580,125,'#fff8ec','#e1bd83','container',rx=8)
card('mem_controller',775,942,540,42,'数据存储控制器 / 读写互连',fill=C['amberfill'],size=23)
card('bank0',775,1010,250,34,'Bank 0',fill='#fffaf0',size=20)
card('bankn',1065,1010,250,34,'Bank 1 …',fill='#fffaf0',size=20)
edge('memory_port_example',[(830,820),(830,942)],'tile0','mem_controller',both=True)
txt(1065,897,'共享多 Bank SPM',23,weight=600)
txt(1065,922,'图中示意一个 Tile 访存口',18,C['muted'])
edge('bank0_port',[(900,984),(900,1010)],'mem_controller','bank0',both=True,sw=1.8)
edge('bankn_port',[(1190,984),(1190,1010)],'mem_controller','bankn',both=True,sw=1.8)
txt(1025,1083,'标准 4×4：西列 + 南行共 7 个直达访存口',19,C['muted'])
zoom('expand_tile_top',(1265,445),(1490,235));zoom('expand_tile_bottom',(1265,505),(1490,1105))

# 03 — Base Tile paths. Existing input queue only; no invented output pipeline.
rect(background,'tile_frame',1490,235,850,870,'#ffffff','#bcc8d1','container',rx=10)
card('ctrl_mem',1530,255,770,105,'配置存储 Ctrl Memory','控制 FU、寄存器簇、两路 Crossbar；ctrl-step 握手推进',C['pinkfill'],'#d9aaaa',size=27)
rect(background,'datapath',1510,415,810,620,'#fbfcfe','#d7e1eb','container',rx=10)
txt(1530,401,'来自邻接 Tiles',21,C['muted'],anchor='start')
edge('ctrl_datapath',[(2230,360),(2230,415)],'ctrl_mem','datapath','orange',dash=True)
card('input_fifo',1530,460,220,70,'输入 FIFO','原有 depth = 2',C['bluefill'],size=25)
card('routing_xbar',1810,460,245,70,'Routing Crossbar','输入路由 / 旁路',C['bluefill'],size=23)
card('reg_cluster',1810,610,245,70,'寄存器簇 / 旁路','Register Cluster',C['purplefill'],size=25)
rect(nodes,'fu_cluster',1810,760,245,95,C['greenfill'],'#a9cbb3')
txt(1932.5,790,'可配置 FU 簇',26,weight=600,target='fu_cluster',max_width=220)
txt(1932.5,817,'标量 / 向量 / 浮点',19,C['muted'],target='fu_cluster',max_width=220)
txt(1932.5,841,'组合 / MAC / 访存',19,C['muted'],target='fu_cluster',max_width=220)
card('fu_xbar',1530,760,220,70,'FU Crossbar','结果路由 / 写回',C['bluefill'],size=24)
card('const_queue',1810,905,245,65,'常量队列','Const Queue',C['amberfill'],size=25)
card('link_or',1530,940,220,70,'LinkOr 合并','逐位 OR，非仲裁器',fill='#edf1f5',size=25)
edge('tile_input',[(1630,422),(1630,460)],None,'input_fifo')
edge('fifo_route',[(1750,495),(1810,495)],'input_fifo','routing_xbar')
edge('route_register',[(1880,530),(1880,610)],'routing_xbar','reg_cluster')
edge('register_route',[(1985,610),(1985,530)],'reg_cluster','routing_xbar')
txt(1838,578,'写入',18,C['blue']);txt(2024,578,'回读',18,C['blue'])
edge('register_fu',[(1930,680),(1930,760)],'reg_cluster','fu_cluster')
edge('fu_result',[(1810,798),(1750,798)],'fu_cluster','fu_xbar')
edge('fu_writeback',[(1640,760),(1640,648),(1810,648)],'fu_xbar','reg_cluster')
txt(1718,628,'结果写回',19,C['blue'])
edge('const_fu',[(1990,905),(1990,855)],'const_queue','fu_cluster')
txt(1920,889,'常量输入',18,C['blue'])
edge('fu_output',[(1640,830),(1640,940)],'fu_xbar','link_or')
edge('route_output',[(2055,500),(2110,500),(2110,980),(1750,980)],'routing_xbar','link_or')
txt(2211,595,'路由直通',21,C['blue'])
txt(2211,772,'Mem 类 FU',20,C['muted'])
txt(2211,805,'另接 SPM 端口',19,C['muted'])
edge('tile_output',[(1640,1010),(1640,1060)],'link_or',None)
txt(1640,1090,'至邻接 Tiles',22,C['muted'])
txt(2060,1068,'31 种 FU 可选 · 每 Tile 按需组合',19,C['muted'])
txt(2060,1094,'Base / ContextSwitch / StreamingLoad',18,C['muted'])

# Optional system integration is a separate view, not an interface on cgra_multi.
rect(background,'optional_group',60,1140,1310,162,'#fafcff','#a9b7c6','container',dash='8 6',rx=10)
txt(85,1174,'可选外设集成 · 单 CGRA 独立入口',24,anchor='start',weight=600)
card('dram',85,1203,180,65,'外部 DRAM',fill='#f0f3f6',size=23)
card('dma',325,1203,150,65,'DMA',fill=C['bluefill'],size=26)
card('optional_spm',835,1203,180,65,'SPM',fill=C['amberfill'],size=26)
card('optional_controller',535,1203,240,65,'Controller',fill=C['amberfill'],size=26)
card('im2col',1075,1203,260,65,'im2col',fill=C['bluefill'],size=26)
for id,a,b,x1,x2 in [('dram_dma','dram','dma',265,325),('dma_controller','dma','optional_controller',475,535),('controller_spm','optional_controller','optional_spm',775,835)]:
    edge(id,[(x1,1235),(x2,1235)],a,b,both=True)
edge('controller_im2col',[(715,1203),(715,1189),(1205,1189),(1205,1203)],'optional_controller','im2col',both=True)
txt(1020,1177,'配置 / 写回',18,C['blue'])
txt(85,1289,'DMA 命令与 SPM 访问均经 Controller；im2col 配置与写回也经 Controller。',18,C['muted'],anchor='start')
txt(60,1334,'可选外设支路不接入上方 host-only 多 CGRA 封装；本图为逻辑结构，非物理版图。',19,C['muted'],anchor='start')

# Legend has no business edges and never enters a node corridor.
for x,y,color,dash,label in [(1510,1180,'blue',False,'数据 / 报文（val/rdy）'),(1930,1180,'teal',False,'相邻 CGRA 边界直连'),(1510,1230,'orange',True,'控制 / 配置'),(1930,1230,'zoom',True,'层级展开，非数据连接')]:
    da=' stroke-dasharray="7 6"' if dash else ''
    labels.append(f'<line data-graph-role="legend" x1="{x}" y1="{y}" x2="{x+45}" y2="{y}" stroke="{C[color]}" stroke-width="2.5"{da}/>')
    txt(x+60,y+7,label,20,C['muted'],anchor='start')
txt(1510,1290,'Tile 详图以 Base 为例；Streaming 不含 Reg → Routing 回读。',18,C['muted'],anchor='start')
txt(1510,1322,'只示意主要连接；未添加 FIFO、寄存器或流水级。',18,C['muted'],anchor='start')

# Python list emission keeps every SVG element complete and XML escaped.
lines=[]
lines.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" data-generator="fireworks-tech-graph" data-quality-profile="standard">')
lines.append('<title>VectorCGRA 原生 SystemVerilog 架构：阶段1–4</title>')
lines.append('<desc>主机和多CGRA组织、4×4单CGRA展开、标准Tile数据通路，以及单CGRA可选DMA与im2col支路。</desc>')
lines.append('<style>text{font-family:"Microsoft YaHei","PingFang SC",Arial,sans-serif} rect,path,line,polyline{vector-effect:non-scaling-stroke}</style>')
lines.append('<defs>')
for key in ['blue','teal','orange']:
    lines.append(f'<marker id="arrow-{key}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M 1 1 L 9 5 L 1 9 Z" fill="{C[key]}"/></marker>')
lines.append('</defs>')
lines.append(f'<rect data-graph-role="background" width="{W}" height="{H}" fill="#ffffff"/>')
lines.extend(background);lines.extend(edges);lines.extend(nodes);lines.extend(labels);lines.append('</svg>')
(OUT/'vectorcgra-architecture.svg').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
(OUT/'architecture-layout.json').write_text(json.dumps(dict(canvas=[W,H],nodes=boxmap,text_fit_checks=textchecks,profile='standard',scope='Delivered stages 1-4; Base Tile view; peripherals shown only in separate single-CGRA integration view'),indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
print('SVG created',OUT/'vectorcgra-architecture.svg')