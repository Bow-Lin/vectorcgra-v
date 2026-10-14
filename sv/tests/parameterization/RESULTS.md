# 跨架构与跨程序验收结果

本表只表示本轮预先列出的九种配置；参数支持范围见 `../../PARAMETERIZATION.md`。
原 Python、原 YAML、历史参考和本轮开始时的 SV RTL 均未修改。
每架构正向 12 次、硬件/程序负例 3 次、Python 原模型完整程序对照 2 次。

| 架构 | 展开后结构 | 独立数学/完整结束 | 负例检出 | Python/SV 完整包 |
|---|---|---|---|---|
| base_2x2 | passed | 12/12 | 3/3 | 2/2 |
| rect_3x2_comb | passed | 12/12 | 3/3 | 2/2 |
| rect_3x2_registered | passed | 12/12 | 3/3 | 2/2 |
| wide_2x3 | passed | 12/12 | 3/3 | 2/2 |
| custom_3x3 | passed | 12/12 | 3/3 | 2/2 |
| context_2x3 | passed | 12/12 | 3/3 | 2/2 |
| streaming_3x2 | passed | 12/12 | 3/3 | 2/2 |
| ring_3 | passed | 12/12 | 3/3 | 2/2 |
| heterogeneous_mesh | passed | 12/12 | 3/3 | 2/2 |

全矩阵通过：**True**。18 项配置/输出/参考复用验收保护通过；
独立重新生成并逐字节核对 577 个输入文件。全部运行的程序哈希与二进制哈希见机器记录。
逐架构保留 Verilator 实际展开后的 `structure.xml.gz`，导出时再次解析并核对 PE 参数和 FU 实例。
add=`x+17`，affine=`3*x+11`，按位宽截断；同位宽、同输入跨架构/背压结果另作一致检查。
3×2 组合/寄存内存使用逐字节相同的程序。Python 比较允许独立 Tile 完成消息交错，
读请求串行、完整读回包逐项比较；不宣称逐周期等价。

## 未通过项

本轮上述有限矩阵没有未通过项。

## 重跑记录

- `heterogeneous_mesh/permanent_stall`：首次达到 120 秒进程上限，不能计为负例检出；保持程序、RTL 和 20,000 周期上限，进程预算改为 600 秒后重跑，检出=True。首轮失败记录与日志保留在 `previous_attempts`。
- `heterogeneous_mesh/register_index_alias`：首次达到 120 秒进程上限，不能计为负例检出；保持程序、RTL 和 20,000 周期上限，进程预算改为 600 秒后重跑，检出=True。首轮失败记录与日志保留在 `previous_attempts`。

另有一次异构 Mesh add 参考进程在调度调整时中断，未产生完成结果；之后从头重新运行。中断不计通过，调度记录单独保留。

## 保留的范围缺口

- HAS_CTRL_RING 尚未暴露到 JSON 工具；关闭控制环仅构造能力，不是另一套可运行配置通路。
- 稀疏删 Tile、逐 CGRA 控制深度、任意坐标映射和任意 FU/消息位宽参数仍未完整对应。
- 本轮未新增向量、浮点、DMA/im2col 或 Context 迁移、STREAM_LD 专项证明。
- 原补测的 GEMM/GEMV/SPMV/Ring 四项未完成结论保持，不以这些新程序替代。
- 因整体验收仍有未解决项，本轮不提交、不推送。

复现：`python3 -B sv/tests/parameterization/run.py --output work/parameterization --python <原PyMTL解释器>`。
生成报告前运行 `guards.py --output <同目录>`，再运行 `report.py --work <同目录>`。
测试台仅驱动公开接口，不写 DUT 内部状态。每次程序运行从复位开始。
