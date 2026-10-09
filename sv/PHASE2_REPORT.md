# 第二阶段：原生参数化单 CGRA

源码基线为 `ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`，迁移分支为 `codex/sv-migration`。本阶段将固定展开核心替换为直接维护的参数化 SystemVerilog，保持标量单 CGRA 的命令、握手和寄存器边界。

## 实现范围

- `rtl/common/`：参数化消息/配置类型、寄存器文件、normal/bypass 队列、Channel 和轮转仲裁。
- `rtl/fu/`：Adder、Multiplier、Memory、Nah 及四 FU 组合。
- `rtl/mem/`：常量队列、动态控制存储、寄存器 bank/cluster、全局数据存储控制与 bank。
- `rtl/noc/`：分组交叉开关、credit 适配、路由器和控制环。
- `rtl/tile/`：静态交叉开关、完成信号合并及 Tile 控制步协议。
- `rtl/controller/`：主机/控制环/存储包派发和原有 GlobalReduce 状态机。
- `rtl/cgra/cgra_scalar.sv`：Tile/bank 复制、mesh 邻接、边界和存储端口的原生 generate；`cgra_2x2.sv` 保持原外部接口。

正常 `filelists/rtl.f` 不实例化固定生成核心。`rtl/fixed/` 和 `reference/` 只提供历史/测试参照。恢复参数时参考原 Python 构造规则及已展开 RTL；迁移期工具保留在 `migration_tools/`，日常构建不调用项目 Python 或 PyMTL。EDA 工具内部 Python 仍允许。

## 参数合同

| 参数 | 默认值 | 当前约束 |
|---|---:|---|
| `COLS` / `ROWS` | 2 / 2 | 各至少 2；四邻接 mesh |
| `DATA_W` | 32 | 至少 11，且不小于 `GLOBAL_ADDR_W`；predicate/bypass/delay 各 1 位 |
| `CTRL_DEPTH` | 8 | 至少 2；软件控制地址必须在范围内 |
| `REG_DEPTH` | 16 | 至少 2；软件寄存器索引必须在范围内 |
| `BANK_DEPTH` / `NUM_BANKS` | 16 / 2 | bank 深度至少 2、bank 数至少 1，均为 2 的幂 |
| `GLOBAL_ADDR_W` | 7 | 1..32；本地容量不超过全局地址空间 |
| `NUM_CTRL` | 8 | 1..CTRL_DEPTH；初始配置计数，可由命令更新 |
| `TOTAL_STEPS` | 8 | 0..2047，保留原 11 位步数计数器 |

运行时单 CGRA ID 为 0；已验证地址映射为本地 0..31，调用者按容量驱动 `address_lower/upper`。尚未扩展多 CGRA 地址映射。控制环显式支持 2 个 VC、每 VC 2 个 credit；原构造函数没有在所有子层传播其他值，本阶段不宣称这些组合已支持。

DATA、CTRL、payload、Tile ID、主机包、NoC 包和存储路由字段分别推导；package 不冒充可参数化模块，实例相关类型在模块作用域内声明。存储中未初始化或越界读取保持原未定义域。上述构造约束不表示所有组合或全部程序均已动态验证。

## 系统测试与独立证据

原 2×2 回归继续保留。新增 `tests/phase2_tb_cgra_scalar.sv` 独立构造配置，通过主机写入，沿闭环经过全部 Tile：Tile 0 从地址 15 load，首计算 Tile 加 5，第二个乘 3，后续每个加 −8，末 Tile 向西边界多播并返回 Tile 0，写地址 16。主机收齐所有完成包后回读结果及原输入。

每个参数点都有自己的未修改 ac96 Python 模型、导出 HDL、配置包和输入/输出轨迹。两轮输入为 7 和 −6，中间复位并重新配置；检查所有 Tile 完成、每段内部链恰好一次、主机/边界反压及结果不丢失或重复。比对包括无效周期消息，仅排除原本未驱动的三个外部 inter-CGRA 输出。

| 参数点 | 全阵列运算结果 | 两轮采样周期 | 每周期比较输出位 |
|---|---|---:|---:|
| 2×2，32 位，CTRL=8，REG=16 | 28 / −11 | 134 | 489 |
| 3×2，同上 | 12 / −27 | 158 | 563 |
| 4×4，同上 | −68 / −107 | 286 | 789 |
| 2×2，64 位，CTRL=16，REG=8 | 28 / −11 | 134 | 770 |

四点在最终源码冻结、重新编译后全部通过；兼容 2×2 回归、类型样本、故意错误结果和永久反压超时检查也通过。两项负测同时要求非零退出及指定错误文本，避免把任意构建或运行失败算作成功。最终状态与源码哈希见 [`results/phase2-summary.json`](results/phase2-summary.json)。3×2 是原 `CgraRTL(width,height)` 支持的配置，未为迁移新增架构能力。64 位变体证明了字段尺寸及数据路径变化，未覆盖高控制地址或所有寄存器索引。

独立组件对照进一步覆盖：完整 Tile 2000 次采样；FU、寄存器簇和两种静态交叉开关各 1999 次采样；基础队列/RF/仲裁/分组交叉开关/5 节点环 500 周期；7 和 17 节点环各 800 周期。原始 HDL 参照与独立算术/流量检查分别保留，具体种子、限制及入口见 `tests/native_tile_README.md` 和 `tests/native_noc_README.md`。

## 综合检查

仅综合原生 DUT：默认 2×2、4×4 和 64 位/CTRL=16/REG=8 变体均完成 `sv2v → Yosys synth -noabc → check -assert`，最终检查均为 0 problems。后两项保留全部 41 个顶层端口，结果及源码/日志哈希见 [`results/phase2-profile-synthesis.json`](results/phase2-profile-synthesis.json)。另对基础模块/NoC 的 12 个配置运行前端与结构检查；这 12 项没有执行完整 CGRA 综合。

`TOTAL_STEPS=2048` 的非法参数测试也按预期拒绝展开。本机 Yosys 将 `$fatal` 报为 `$finish executed`，测试进一步核对报错文件、行号及对应的 TOTAL_STEPS 错误文本，不把其他失败视为该项通过。源 RTL 中的既有未驱动警告仍被保留，最终结构检查通过不等于全部信号均有定义。

本次没有标准单元映射或频率测量；generic 逻辑统计不能解释为标准单元面积。原始运行/编译/综合日志和统计已存入 [`results/phase2-evidence.zip`](results/phase2-evidence.zip)，逐文件与归档 SHA256 见 [`results/phase2-evidence-manifest.json`](results/phase2-evidence-manifest.json)。

## 运行入口

从迁移工作树根目录运行：

```powershell
& ./sv/scripts/run.ps1 -Task phase2 `
  -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite `
  -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe
```

`-Task all` 运行兼容 2×2 回归、类型检查、两项负测及默认综合；`-Task phase2-4x4` 单独运行 4×4。测试全部位于 `tests/`，输出和完整日志在忽略的 `build/`。

额外两个参数点的完整综合运行 `./sv/tests/check_phase2_synthesis.ps1`；基础组件入口见相应测试说明。Git 使用 `codex/sv-migration`，计划、参考资产、原生实现和最终证据分开提交；原 Python RTL、NoC 优化分支及 master 保持不变。

阶段起点为 `741dc5d`，计划提交 `c2a05a0`，独立参考提交 `a2162a5`，原生实现提交 **`614dc8b`**。本报告及结果归档在其后的独立文档提交中保存，方便单独查看实现差异或回到第一阶段。

## 限制与后续

本阶段保持 Adder/Mul/Mem/Nah 的原有行为，包括 SUB_CONST 常量 ready 缺陷、未驱动 const clear、禁用 DMA 输入和单 CGRA 外部 NoC 限制。没有补零或 `setundef`，没有新增流水级。GlobalReduce 保留原状态机，但当前系统算法未构成其全部功能验证。

这里的证据是有限程序和有限随机序列、Verilator 二态语义下的比较，不是所有程序/参数或四态 X 传播的形式证明。向量/浮点、其他 Tile 变体、多 CGRA、DMA/im2col 仍属后续阶段。本阶段做迁移与综合兼容检查，不把第一阶段面积或以前 4×4 NoC 优化数值冒充新的面积/频率测量。
