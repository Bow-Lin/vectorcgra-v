# 当前源码整机与综合网表验收

本批在内核完成顺序修复之后，重新编译完整系统，18 次正向运行、27 次负向检查通过。原 Python 的 274 个源文件、
历史 HDL、冻结周期轨迹及历史验证记录保持不变；本批证据单独记录。

## 综合中发现的结构问题

`HAS_IM2COL=0` 时，Controller 的 `recv_from_im2col_pkt__rdy` 原本没有驱动。
整机的综合前严格检查检出这一问题；现在禁用分支显式驱动 0，启用分支保留队列 ready。
失败日志、当时源码 SHA 和实际参数保存在 `reference/current/system_acceptance/disabled_im2col_ready/`。
修复后重新编译本批全部整机测试，不沿用修复前的可执行文件。

## 原生整机

| 参数点 | 验证内容 |
|---|---|
| 2×2 Mesh CGRA，各 2×2 PE | 16 PE；跨 CGRA 读写、逐 owner 顺序、完成去重、主机背压 |
| 4 节点 Ring，各 2×2 PE | 16 PE；同一公共接口数学程序 |
| 注册存储 Mesh | 同上，MEM_COMBINATIONAL=0 |
| 2×2 Mesh CGRA，各 4×4 PE | 64 PE；长算术链及远程内存 |
| 异构模板 | 21 PE，异构阵列形状／FU 配置和边界连接 |

普通整机保留内部网络计数；四种同构配置各执行两个独立数学场景，异构配置执行其完整主机程序；均通过错误结果和永久背压反例。

## 实际整机综合网表

选定 **4 节点 Mesh × 4 PE** 和 **2 节点 Ring × 4 PE**，每个 PE 控制存储深度 2、
寄存器深度 2，32 位数据；每个 CGRA 的存储窗口仍为 32 字。这是完整 `cgra_multi`：
所有 Controller、NoC、控制环、PE、SPM 均参与综合，并非只综合网络或单个 PE。
两个参数点分别先跑 RTL，然后使用相同主机程序运行生成网表。

sv2v 定义 SYNTHESIS；Yosys 在 proc／opt 后检查，在扁平化综合后 splitnets／check／SCC，
写出带门级原语的 Verilog，再从磁盘重新读取并重复 check／SCC。Verilator 使用 Yosys
simcells 仿真实际生成网表，保留 RTL 优化，分拆生成 C++ 函数以控制编译内存。

网表不保留原层次信号，因此仅关闭不可访问的内部网络计数器，并明确输出
`NATIVE_MULTI_INTERNAL_MONITORS enabled=0`。公共端口的独立计算、地址和 owner、
响应次序、重复／缺失完成、主机背压、错误结果和超时检查继续运行。
零 SCC 只描述这两个实际参数点，不推出任意参数组合均无组合环。

## Python 原始周期兼容

旧轨迹现在显式选择 NOC／MEMORY／ARITH／VECTOR／FP／REDUCE 六种兼容参数。
这些测试检查当前 RTL 对冻结 Python 的兼容行为；原生默认的数学和握手修复由另一组验收覆盖。
参数放在重放 runner 或当前迁移 bench 中，未重写参考输出。bench 生成器保留相同选择。

- AXPY、FIR4×4、histogram、ReLU4×4、SAD：五个已完成的 Python 内核轨迹。
- GEMM、GEMV：原 Python 未完成的轨迹前缀，不能写成原 Python 内核通过。
- global_add、dynamic_fir：完整多 CGRA 周期重放、数学结果，以及后者的保存／恢复状态检查。
- 原 Python SPMV 未能生成有效轨迹；原生 SPMV／COO 的数学证据见 KERNEL_BOUNDARIES.md。

每个重放有错误期望负向检查。编译记录包含参与源码及公共头文件的 SHA；migration 的 run
模式检查编译来源，拒绝源码变化后使用旧可执行文件。旧批次验证 JSON 保留其原时间点和哈希。

```bash
make -C sv current-systems
make -C sv current-system-synth
```

完整 Mesh 网表重新读取阶段实测峰值约 11.4 GiB，建议独占 16 GiB 内存主机；
C++ 拆分只控制编译资源，并不减少 Yosys 的网表解析内存。

最终运行结果、工具版本、原始参考和当前源码哈希保存在
`reference/current/system_acceptance/validation.json`。完整统一回归和 CI 编排在下一批交付。
