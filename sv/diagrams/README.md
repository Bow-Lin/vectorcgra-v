# VectorCGRA 架构示意图

- `vectorcgra-architecture.png`：3600 × 2055 像素，可直接插入文档。
- `vectorcgra-architecture.svg`：保留文本与矢量图形，适合缩放及编辑。
- `generate_architecture.py`：标准库绘图脚本，只生成示意图，不参与 HDL 构建。
- `render_architecture.cjs`：通过 Sharp/librsvg 从 SVG 导出 PNG，环境需提供 `sharp` 或设置 `SHARP_MODULE`。
- `manifest.json`：对应源码版本与图像 SHA；`validation.json`：XML、marker、碰撞、几何、排版及目视检查。

图的范围是已交付的阶段1–4；左侧为系统组织，中间为单CGRA的4×4例子，右侧为标准Base Tile。采用用户参考图的浅色模块与逐层展开方式；灰色虚线是放大关系，不是硬件连接。

多CGRA封装的主机只连接CGRA0。蓝色报文NoC与绿色Tile边界直连是两套连接；绿色仅画水平方向。底部DMA/im2col是单CGRA的可选独立集成入口，不表示当前host-only多CGRA顶层带有这些外设。DMA的SPM请求/响应经Controller转发；im2col的配置和写回同样经过Controller。

中间SPM为逻辑共享的多bank存储，bank数与Tile数独立。只示意Tile0的一个直接访存口；标准4×4中西列与南行共七个Tile有直达访存口。省略其他访存口、Controller↔SPM等重复连线，不能将图当完整网表或物理布局。

右侧Input FIFO是原有每输入depth-2队列；Crossbar后没有新增寄存器或流水级。两路Crossbar各自输出通过LinkOr逐位OR合并，常量队列直接送FU；配置存储控制FU、寄存器簇和两路Crossbar。Streaming变体省略寄存器向Routing Crossbar的反馈。图中未展示每个val/rdy信号及所有旁路细节。

重绘：运行 `python generate_architecture.py`，再用配置好 Sharp 的 Node 执行 `node render_architecture.cjs`。SVG保持文本可编辑，PNG已检查中文显示。此绘图工具不意味着继续第五阶段迁移。
