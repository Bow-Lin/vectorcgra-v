# 第四阶段：多 CGRA 与系统扩展

基线为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。本阶段继续在 `codex/sv-migration-phase4` 交付，原 Python 源码与此前 NoC 优化分支不变。最终汇总由 `results/phase4-summary.json` 记录；本文件和实验日志说明验证范围，不把有限程序测试称为形式等价证明。

## 直接维护的硬件

- `cgra_system`：四/八端口 Tile、外部 NoC 或单 CGRA 回环、Context/Streaming 变体、可选 DMA/im2col Controller 接口；保留存储器原有组合/寄存器请求模式。
- `cgra_multi`：同构 Mesh/Ring 多 CGRA；主机接 CGRA 0，保持原物理边界连接和远程访存协议。
- `cgra_multi_template`：不同大小的矩形 CGRA、每 Tile 有序 FU 列表、定向 LinkList、禁用链路、独立读写 Tile 连接表。共同最大几何决定包格式和控制环大小，局部实际 Tile 数决定 Controller 的连接位置。
- `cgra_inter_mesh` / `cgra_inter_ring`：原 Y 优先路由、仲裁、队列、credit 和 VC 行为。Ring 的 channel latency 构造参数按原实现保留其既有实际效果。
- `cgra_dma_engine`、`cgra_im2col_engine` 与两个 `cgra_integrated_*`：可独立使用的引擎，以及 Controller/SPM 集成。

本阶段完整 DUT 文件列表包含 94 个文件，为 `filelists/native.f`；阶段 4 核心为 `filelists/phase4.f`，外设列表为 `filelists/phase4_peripheral.f`。正常文件列表不使用冻结参考实现构建 DUT。

## 验证方法与当前证据

三个 16 Tile 同构配置和异构配置同时比较原生 SV、冻结 ac96 HDL 和未修改 Python 的原始周期输出；64 Tile 配置比较冻结原 HDL，并执行独立数学/通信计分，不声称 Python 三方比较。有效位为 0 时的消息也比较。独立计分器另外检查算术、地址 owner、结果顺序、重复/遗漏、完成包和反压。原设计无法直接翻译的任务迁移使用未改 Python 的完整原始周期轨迹，并检查保存/恢复状态与独立数学结果。

| 场景 | 证据与检查 |
|---|---|
| 四 CGRA，每 CGRA 2×2 Tiles，Mesh | 两轮 384 周期 × 195 位；32 完成、16 回读；四个 owner 远程访存；负输入、复位、主机反压 |
| 四 CGRA，每 CGRA 2×2 Tiles，Ring | 两轮 346 周期 × 197 位；32 完成、16 回读；不同 owner 响应允许交错，各 owner 内有序 |
| 四 CGRA，每 CGRA 2×2 Tiles，寄存器存储 | 两轮 374 周期 × 195 位；干净重建及三方比较；32 完成、16 回读、40 远程请求/20 响应 |
| 四 CGRA，每 CGRA 4×4 Tiles，共 64 Tiles | 两轮 944 周期 × 199 位原 HDL 对照及独立数学；128 完成、16 回读、40 远程请求/20 响应；不含 Python 周期比较 |
| 异构 2×2/3×3/2×2/2×2，八端口 | 206 周期 × 221 位；21 完成、8 回读；不同 FU 目录、停用对角边、共享包宽与不同大小控制环 |
| 全局 ADD | 91 周期 × 1,779 位；10+26=36，最终 53/31；6 完成及主机反压 |
| 动态 FIR 任务迁移 | 165 周期 × 3,844 位；126 配置输入，5 次跨 CGRA 物理传输；Tile 0/3 状态保存、恢复、清空；结果 2215 |
| 跨 CGRA NoC 组件 | 九配置，18,729 周期和 4,736 个独立计分包；路由、顺序、背压、Ring VC/credit |
| DMA 集成 | 86 周期；5 次 CPU 回读，2 done/tag，2 DRAM 读及 2 写 beat；默认硬件兼容模式 |
| im2col 集成 | 202 周期；16 个窗口像素写入 SPM 并读回；引擎运行时 CPU 阻塞 45 周期 |
| 非对称存储端口 | 原合法读 1 / 写 3；464 周期；25 本地读、24 写、双向远程访存、83 个反压周期 |

五种完整系统的最终仿真、运行输入哈希重放及对应负控全部通过；五个系统配置的通用综合也已完成。五组共 2254 个逐周期样本、449354 个原始输出位比较，结果见 `results/phase4-system-simulation.json`。组件与系统分别执行故意破坏预期的负控；NoC 的九种正测配置共用 mesh_2x2_l1_w32 的错误包与超时负控，没有声称九种各自执行负控。四种同构系统还各含永久反压超时负控，具体入口与适用范围见对应测试脚本。

## 系统综合结果

最终冻结源码经 sv2v 转换，五个配置均完成 `hierarchy -check; synth -noabc; check -assert`，最终问题数为 0。保留八个原主机端口，输入/输出总位宽分别为 Mesh16 的 197/195、Ring16 的 199/197、寄存器存储 Mesh16 的 197/195、Mesh64 的 201/199、异构系统的 223/221。原结构展开阶段的未驱动诊断保留在日志中；最终零问题不等于为原未知值定义了新语义。

外设两个完整系统也通过相同级别的通用综合；NoC 的五项完整综合、四项前端检查、六项外设组件综合和非对称存储前端检查分别记录，不能混成同一个统计口径。结果见 `results/phase4-system-synthesis.json` 和各组件 JSON。本轮没有标准单元库映射面积或 Fmax 测量。

## 使用和参数边界

```powershell
& ./sv/scripts/run.ps1 -Task phase4 `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

可单独选择 `phase4-noc`、`phase4-system`、`phase4-template`、`phase4-migration`、`phase4-peripheral`、`phase4-memory`。系统综合入口为 `tests/phase4/system/check_synthesis.ps1`；组件脚本分别记录完整综合或前端结构检查，不混为同一验证级别。此阶段不宣称标准单元面积或 Fmax 结果。

- Mesh 顶层使用原可展开的多行、多列配置；Ring 顶层沿用一行多 CGRA 的合法包几何。原 Controller 要求列数不少于行数，地址映射调用方须提供合法的容量与映射。NoC 组件自身的节点数覆盖不等于任意系统配置都已验证。
- `COLS/ROWS` 是局部几何，`MAX_COLS/MAX_ROWS` 是共享包几何；`MEM_PORTS` 为读口数量，`MEM_WRITE_PORTS` 独立指定写口数量，默认与读口相同。配置表下标采用低位对应编号 0。
- `TILE_FU_COUNTS/TILE_FU_KINDS` 显式规定顺序，末项包含 Nah。原 Python 的集合去重顺序不稳定，迁移参照记录实际展开顺序，不依赖重新运行集合得到相同顺序。
- host-only 多 CGRA 封装不暴露外设端口，会拒绝 HAS_DMA/HAS_IM2COL；外设通过 `cgra_system` 或集成 wrapper 使用。集成 wrapper 需明确启用对应 HAS 参数。
- 自定义结构覆盖完整矩形 TileList、定向/禁用链路和逐 Tile FU；不宣称原实现的稀疏 Tile 删除正常。稀疏 Tile 删除不属于本阶段已验证能力；此前探索证据留在单独的第五阶段草稿分支。

## 已知基线差异

DMA 默认 `BASELINE_TRANSLATED_SLICES=1` 保留原翻译后 HDL 的切片截断行为：128 位 beat 的第三/第四个 32 位 word 可能重复读取前两个 word。独立事务检查明确计数这类已知错误，未把错误结果当正确搬运。`=0` 是显式选择原 Python 搬运语义；两种模式分别测试，不能互称周期硬件等价。小于一 word 的 DMA 长度以及非 word 整数倍的截断规则属于原限制。

原读 3 / 写 1 的内存 Controller 在 RTLIR 中会尝试将 1 位 write source 截断到更宽 remote source，翻译失败；失败保留在参考目录，不使用改过的 Python 宣称原架构支持。im2col 保留原私有 preload 存储与终止/复位语义，没有新增原本不存在的图像写端口。

第三阶段记录的浮点格式、向量乘法 Python/HDL 差异和原未驱动值限制继续适用。验证基于所用 Verilator 的二态语义，不证明四态 X 行为或所有程序/参数组合。

## 旧配置回归与交付边界

共享 profile 增加了多 CGRA 和独立读写存储口的位宽别名。默认单 CGRA 的配置编码、41 个外部端口及总位宽不变。35 个旧测试平台自行定义 profile，因此补入原默认宽度常量；DUT、刺激、预期和冻结参照未因此改变。实际重跑通过第二阶段四配置、第三阶段六系统和34个组件配置。回归结果及初次编译失败、收集器 UTC 时间修复的记录见 `tests/phase4/compatibility/`。

按用户最新指令，本次到第四阶段结束。第五阶段内容已单独保留在 `codex/sv-phase5-draft`，不在当前文件列表、构建入口和交付分支中；等待用户下一次指令。

实现提交为 `c56d0c6`，参考/测试提交为 `2fafbb9`。第四阶段证据归档包含674项记录，清单和逐项SHA见 `results/phase4-evidence-manifest.json`；所有条目已从ZIP读回核验。
