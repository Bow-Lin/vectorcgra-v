# 补测差异的后续处理

初次 191 项补测和失败证据保留在 `RESULTS.md`、`results.json`。本轮没有把
原生数学检查、兼容模式或改写后的程序计为“原测试逐周期通过”。

本轮处理了原来的 30 项未通过记录：11 项按明确复位／有效数据契约通过，
14 项已用既有原生契约的独立功能测试复核，1 项补齐无控制环构造参数。
**GEMM、GEMV、SPMV、Ring 四个原程序仍不能标为完整通过，因此没有提交或推送。**
机器可读证据为 `followup.json`，`commit_allowed=false`。

## 11 项复位／无效消息差异

新增 `contracts.py` 和 `run.py --contract`，仅允许下表指定的用例使用。
没有修改激励、正常周期的 ready／valid 或有效消息的期望。

| 用例 ID | 复位期间采用原生约定的端口 |
| --- | --- |
| 32 Controller | `recv_from_ctrl_ring_pkt.rdy=0` |
| 39 FlexibleFu prologue | `recv_opt.rdy=0` |
| 72 ExclusiveDiv | 无复位期望改写，仅忽略 valid=0 的消息数据 |
| 128 ConstQueue | `send_const.val=0` |
| 137–143 DmaEngine | `dma_cmd.rdy=0` |

除此以外的全部握手信号仍逐位比较，**包含复位周期**；消息 valid=1 时全部
数据位仍比较。复位期望不是跳过检查，而是检查指定端口为零，错误复位期望
也必须触发失败。其他握手期望的故意篡改同样必须失败。

每项要求确实观察到有效输出；prologue 用例的原目的就是“不需要常量和数据也
能推进控制”，因此要求恰好消费一个控制且不产生有效数据。最初加上的通用
“必须产生数据”覆盖条件在这项失败，经核对原函数后改为此专用条件；不是
删除它的结果检查。11 项正向检查以及适用的错误期望反例均通过。

这些用例仍不称为包含 invalid 数据位的 raw 等价；它们是在上述明确接口约定
下通过，不使用任何 legacy 参数。

## 14 项有效行为差异

本轮没有修改这些模块的 RTL。它们的差异来自已经记录的原生语义修正，重新
运行的独立功能检查全部通过；原始严格周期差异和旧语义兼容证据继续保留。

| 用例 ID | 默认原生语义 | 本轮重新运行的检查 |
| --- | --- | --- |
| 42、43 | IEEE 浮点字段映射；旧 Python 数值解释通过显式参数兼容 | `run_native_math.sh`，16／32／64 位浮点加乘及错误期望反例 |
| 95 | InclusiveDiv 记录 START 对应的结果并排队，按 END 顺序取回 | `run_arithmetic_boundaries.sh` 的 32 位、latency=4 配置，原生边界和兼容轨迹 |
| 122 | VectorAllReduce 正确处理请求、base、predicate、返回背压及控制退役 | `run_vector_reduce.sh`，四组位宽／lane 和八种旧缺陷的反例 |
| 123 | VectorMulCombo 控制退役要求有效运算，保留规定的乘法数学含义 | `run_vector_arithmetic.sh`，数学、缺输入、背压及参数边界 |
| 134、135 | 内存地址／数据配对接收，按原生规则缓冲与复位 | `run_memory_boundaries.sh`，七组读写口／位宽／内存时序／DMA 配置 |
| 175–181 | 仲裁在阻塞时保持选择，只在实际传输后推进 | `run_noc_primitives.sh`，1／2／3／5 输入、公平性、消息保持及旧行为反例 |

浮点格式、流水线容量和仲裁时序属于真实的接口区别。如果使用者要求旧格式或
旧周期行为，仍需显式选择相应兼容参数。这组功能检查不构成“任意旧程序在
默认参数下都完全等价”的承诺，也不能用通过兼容模式替代默认实现的正确性。

## 无控制环模式：补齐构造能力，纠正原先的描述

`cgra_system` 新增末尾参数 `HAS_CTRL_RING=1`。默认保留控制环；设为 0 时
不实例化控制环，并将断开的控制输入、输出 ready 明确绑零。

这对应原 `CgraRTL(has_ctrl_ring=False)` 的实际行为。原 Python **没有另一套
直连配置接口**，其测试 `done()` 无条件返回 True。先前“缺少控制环旁路 API”
的表述不准确；本轮也没有凭空设计这样一套接口。

原 ID 3 的短轨迹现在通过，标记为 `construction_only_original_done_is_unconditional`，
不能算作无控制环下完成 FIR。默认模式的 FIR + LoopCounter、FIR 组合内存和
寄存内存三个原整机场景重新运行通过，包含输出期望负例。

## Ring：原程序问题与完整计算链分开验证

原 ID 166 的程序有可直接检查的问题：

- 四份程序合计 24 个配置包、4 个启动包全部发给 tile 0，循环变量没有参与目标编号。
- 首条 INC 选取输入 0，但指向 FU 操作数的四个路由选择全部为 0，四个寄存器
  读取方向也全部为 0，因而没有提供首条指令的操作数。
- 原测试的 `done()` 只等待配置发送完，源码以 FIXME 注释掉完成 sink 检查。

原配置补上完成条件后的超时证据仍保留；仅凭两边都超时不算通过。

新增 `ring_completion_reference.py`，复用原测试构造的消息类型和原 Ring
架构参数，在**未改动的原 Python RTL**上执行独立补充程序：

1. 主机向 CGRA3 地址 24 写入 3，并初始化地址 25。
2. 配置 CGRA0 的 tile 0：远程加载、两次 INC、两次自加、远程存储。
3. 等待完整完成包，再由主机读取地址 25，核对 `4 × (3 + 2) = 20`。
4. 继续观察，拒绝重复输出。

Python 参考完成于 69 个总采样周期；SV 原生事务重放通过，增加周期性输出
背压也通过（台架活动计数分别为 64、66，计数起点与 Python 总周期不同）。
完整包、数量、顺序和错误期望反例均检查。冻结在 `followup_fixtures/166/`，
标记为 `supplemental_ring_remote_program`，运行器强制将它与原用例验收分开。

这个补充验证证明选定 Ring 架构的远程访存、计算与完成路径能工作；它不是
对原来那份没有完整算法定义的配置直接改期望，也不把原 ID 166 改为通过。

## GEMM、GEMV、SPMV

原固定 Python 参考的状态继续保留：GEMM/GEMV 只有未完成前缀，SPMV 配置
生成器缺少 `ICMP_ULT`。本轮没有重新声称原 Python 全程序已经运行结束。

对 GEMM/GEMV 增加可复现的配置反例，同一个当前 SV 内核台架得到：

| 程序 | 配置 | 实际结果 |
| --- | --- | --- |
| GEMM | 原配置 | 12,000 周期限制内无完成、无结果回读 |
| GEMM | 修正配置，仅撤销寄存器 token 保留 | 同样无完成 |
| GEMM | 修正配置，仅撤销 stride=4 | 数学检查失败：地址 36 得到 0，期望 40 |
| GEMV | 原配置 | 12,000 周期限制内无完成、无结果回读 |
| GEMV | 修正配置，仅撤销寄存器 token 保留 | 同样无完成 |

这些是 **SV 上的配置反例**，用于定位程序对 token／stride 的依赖，不冒充
原 Python 长时间运行的结果，也不单凭有界超时证明无限期死锁。

原有修正程序的 GEMM／GEMV／SPMV 完整数学检查重新通过：1657／405／964
周期，分别回读 16／4／32 字。SPMV 另外重跑 nnz=0…8、背压、五种撤销修正
的反例。使用原有迁移工具重新生成三项程序的 12 个输入文件，与既有修正
程序逐字节一致，未改变期望以迎合本次运行结果。

SPMV 的独立转换已有无符号比较及 PHI／完成依赖的原生修正；它需要原生
扩展语义。因此“修正后的 SV 程序算对了”不能替代“原 Python SPMV 通过”。

## 提交状态与复现

原始 274 个 Python 文件的哈希保持不变，原 YAML 和初次补测冻结数据未改。
运行器的损坏轨迹、失败参考、漏测、补充程序隔离以及未经核实用例不能使用
`--contract` 的检查均通过。

四项原程序仍缺少可通过的完整参考；没有删除这些记录、将它们设为 skip，
或让补充程序覆盖原失败。因此本轮 **不提交、不推送**。

```sh
# 14 项差异涉及的独立原生检查
python3 sv/tests/original/review_native.py --output work/native-review

# 已冻结的 Ring 补充参考；无需 PyMTL
python3 sv/tests/original/run.py --ids 166 --replay-only --transactions \
  --fixtures sv/tests/original/followup_fixtures --output work/ring-supplement

# 构建修正矩阵内核及其数学／负例检查，再运行原配置反例
JOBS=1 bash sv/tests/current/run_native_kernels.sh gemm gemv spmv
python3 sv/tests/original/matrix_counterexamples.py --output work/matrix-counterexamples
```

若需要重新生成 Ring 的原 Python 参考，用原 PyMTL 环境执行
`sv/migration_tools/ring_completion_reference.py --output <目录>/166/capture`，
再把 `<目录>` 作为重放输出目录。完整逐项日志及哈希见 `followup.json`。
