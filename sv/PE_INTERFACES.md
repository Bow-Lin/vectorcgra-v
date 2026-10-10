# PE 公共接口与参数

`rtl/tile/cgra_pe.sv` 是单个可配置 PE 的公开入口；`VARIANT=0/1/2`
分别选择 Base、Context、Streaming。`COLS/ROWS` 在单 PE 中只影响所属
系统的地址／包类型，不会实例化固定 2×2 阵列。

## 共享边界

- `cgra_profile_defs.svh` 定义配置参数和绑定；`cgra_profile.svh` 定义
  data、control、host、NoC 等包类型及字段布局。
- `cgra_pe_ports.svh` 是五个 PE 模块共用的 28 项端口声明，保留原来的
  位宽、方向、顺序和 unpacked 数组范围。它是模块内部 include，不加
  include guard；接口变更只在这里维护。
- `cgra_fu_catalog.svh` 的 `CGRA_FU_BIND_OPTIONS` 统一向量、浮点和兼容
  参数的透传。常规 `CGRA_FU_BIND` 另绑定 FU_COUNT／FU_KINDS；异构系统
  为每个 Tile 单独绑定这两项，然后复用公共 options。
- `cgra_pe_memory.svh` 只包含静态连线：选择唯一内存 FU，未连接的 FU
  输入绑零，无内存 FU 时公共内存输出绑零。Base／Context 连接 MEM，
  Streaming 连接 STREAMING_MEM。超过一个同类内存 FU 明确报错。

此前 `cgra_system` 的异构 Tile 实例遗漏 `FP_LEGACY_PYTHON`，导致系统
顶层即使设为 1，实际浮点 FU 仍采用原生 IEEE 格式。本次修复该透传。
独立系统用例通过 CPU 配置 Tile 0，然后从西边界输入并回收结果：
两个 `0x3fc00000` 相加，原生结果为 `0x40400000`，Python 兼容结果为
`0x40000000`。其余 Tile 使用不同 FU 列表／数量，结果带背压检查。

## 保留的变体语义

Base 与 Context／Streaming 的控制状态机继续分别维护；Context 和
Streaming 复用 `tile_variant_core`。各变体的命令接受列表、控制步退役、
Context 的任务清理和寄存器恢复、Streaming 重放及无寄存器到路由路径
均保留。PHI／RET／GRANT 的 Context clear 连线位于共享内存接线之外。
Streaming 原模型的透明控制包保持逻辑也保留，不能把它当作无意锁存器
直接删除；该重构不声明消除了所有变体内部锁存。选定 Streaming 网表
保留 13 位此类锁存（命令 6 位及 data.payload 低 7 位），Verilator 的
对应 13 条 LATCH 警告记录在验收中，没有全局屏蔽。

当前支持 Base／Context 的 4 或 8 端口，Streaming 的 8 端口；
CTRL_DEPTH／REG_DEPTH 至少为 2，1 ≤ NUM_CTRL ≤ CTRL_DEPTH。
FU 列表有序且恰含一个 Nah，多个有效 FU 仍沿用 last-valid 优先级。
本次没有扩展为任意 FU 操作数／输出口数。

## 验收

```bash
make -C sv current-pe-interfaces
make -C sv current-pe-interfaces-synth
```

RTL 覆盖 Base 32/4、32/8、64/4，Context 32/4、32/8，Streaming 32/8，
以及 Streaming 连续读取；检查 Grant、常量随整步退役、独立路由背压、
Context 切换和 GEP 配置。另有四组实际 MEM 读写：Base 首槽／末槽、
Context 首槽／64 位末槽；背压写入、延迟返回和输出计数独立检查。

选定 Base、Context 8 端口、Streaming 连续读取、Base 末槽 MEM、
Context 64 位末槽 MEM 运行 sv2v → Yosys 综合 → 导出网表 → 重新读入
检查／SCC → 同一公开接口测试。导出前 splitnets；不关闭 Verilator RTL
优化，也不靠放宽收敛次数消除循环。Context 64 位网表的两路 C++
编译曾触发本环境 16 GiB 内存限制；该配置使用单任务编译，网表及验证
条件不变，首次失败记录保留在证据中。

证据记录于 `reference/current/pe_interfaces/validation.json`。这些是
指定配置的仿真和结构检查，不是任意参数组合的形式等价证明。原始
274 个 Python 文件及历史参考保持不变。
