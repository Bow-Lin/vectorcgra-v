# 4×4 VectorCGRA 修改前后频率统计

2026-09-18。本次补齐了原始 A0 与最终 B+C2 的**整机寄存器间组合延迟及其倒数**。采用同一 Yosys 配套 ABC、Nangate45 typical 库和计时模型，未改 RTL、重新映射或覆盖历史面积结果。

| 指标 | 原始 A0 | 优化 B+C2 | 变化 |
|---|---:|---:|---:|
| 完整 CGRA 标准单元面积 | 3,272,792.978 | 2,049,466.692 | −37.38% |
| FF→FF 结构延迟，含统一 BUF_X1 驱动模型 | 5.94483 ns | 5.86488 ns | −1.34% |
| 组合延迟倒数，频率参考值 | 约 168.2 MHz | 约 170.5 MHz | **+1.36%** |

频率按 `1,000,000 / delay_ps` 计算。这里的频率参考值不是完成时钟约束和布局布线后的 Fmax；它不含寄存器 clock-to-Q、setup、时钟偏差或连线延迟，也未证明关键路径在合法控制下可敏化。当前未定义侧输入仍然存在，因此不能把这份统计当作原 RTL 所有语义问题已解决的证明。

## 版本和测量条件

- 原始硬件：`41cb0c0e94d9373dbb967cb69baa38990d0f402e`，冻结映射网表 `build/baseline/hierarchical/mapped.json`。
- 最终硬件：`e91686f7b6133f615bec76eb5bba6edbda1e5f1c`，冻结映射网表 `build/C2-final/hierarchical/mapped.json`。
- Yosys 0.69+62 / 配套 ABC 1.01，ABC 二进制 SHA256：`8168052e89cbb3120acf8b7ef9846a1204f1eb320e25c135326ab089a8c32e12`。
- Nangate45 typical，1.1 V、25 °C，时间单位 ns、电容单位 fF；库 SHA256：`8d540a4d4cf6d09d27c87ad067857a9c0c2eeb023ab7a56e058cd3113db4e9b1`。
- 每个发起点采用绝对 BUF_X1 延迟、零输入转换时间；每个真实终点独立加载 5 fF。重复终点的负载累加。两版统一使用这一模型。
- 不启用 wire-load、重定时、优化、重新映射或基于工作负载的常量传播。FF 的 Q/QN 是独立发起点，D 是终点；全部真实边界端口仍保留。

旧脚本的 ABC global driver 使用 `delay(load) − delay(0)`。本次改为显式绝对 BUF_X1 模型，不能与旧局部筛选延迟混算；两版整机从同一模型重新计时。

## 为什么这次能够得到数值

旧 `mapped_timing.py` 在发现 X 输入时主动停止，尚未调用完整网表的 `stime`。本次保留该严格检查，并另加显式披露假设的结构计时入口。

1. 逐层合并连线别名，保留每个映射组合单元。A0 有 1,914,356 个组合单元，C2 有 1,010,838 个；两版均有 149,369 个 DFF。Kahn 排序只改变门的顺序，两版均无组合环。
2. 每个 X 输入引脚单独成为虚拟发起点，共 8,800 个；没有绑零或删除其门、弧。三项完全为 X 的停用 inter-CGRA 输出共 205 位，仍按固定 `is_multi_cgra=False` 的原规则显式排除。实际数据边界没有排除。
3. stock ABC 会拒绝没有 fanout 的门，而 `topo` 会删除悬空逻辑。为保留上游负载，对原本没有下游的门输出加诊断终点；这种终点不能成为报告的有效终点。
4. stock ABC `stime` 不使用 BLIF 的逐输入 arrival。计时脚本因此添加仅供分析的源/终点标记：目标源类和目标终点类各加固定延迟 K，保持原门的电容与转换时间计算不变。ABC 最大延迟减去 2K 后得到所选类别的延迟。标记不进入 RTL、不计入设计面积，也不增加硬件周期或延迟。
5. 每次检查获胜路径的起终点类别、ABC 门数，以及 `write_blif` 回读的全部单元类型计数。原门不能丢失；未连接发起点和悬空门的诊断终点不能获胜。

该方法依赖 ABC 在传播最大 arrival 时独立计算每个节点的最大 rise/fall slew。实现依据为官方 [sclLib.h](https://github.com/berkeley-abc/abc/blob/master/src/map/scl/sclLib.h)、[sclSize.c](https://github.com/berkeley-abc/abc/blob/master/src/map/scl/sclSize.c) 和 [sclLoad.c](https://github.com/berkeley-abc/abc/blob/master/src/map/scl/sclLoad.c)。本地实际二进制通过下面的探针和独立计算校验。

## 数值复核和其他路径

| FF→FF 测量 | A0 / ps | B+C2 / ps |
|---|---:|---:|
| stock ABC，K=100 ns | 5944.83 | 5864.88 |
| stock ABC，K=200 ns | 5944.91 | 5865.00 |
| 独立 NLDM，未加偏置 | 5944.841608 | 5864.907587 |

两次 ABC 偏置结果最大相差 0.12 ps，远小于约 79.95 ps 的版本差异。独立计算用于复核；上方主表使用 stock ABC 的 K=100 ns 结果。小型网表覆盖驱动、重复终点、反相、条件弧与重汇合，独立计算与 ABC 最大差异小于 0.005 ps。

下表为独立 NLDM 的全图分类诊断，保留所有门，使用与本次 ABC 相同的绝对 BUF_X1/5 fF 模型；不是另一组 ABC 输出。

| 路径类别 | A0 / ns | B+C2 / ns |
|---|---:|---:|
| FF→FF | 5.944842 | 5.864908 |
| FF→边界输出 | 4.292702 | 4.234779 |
| 边界输入→FF | 13.131692 | 13.052897 |
| 边界输入→边界输出 | 11.479552 | 11.422768 |
| 虚拟 X 输入→FF | 2.474667 | 2.476897 |
| 虚拟 X 输入→边界输出 | 2.202688 | 2.222650 |

全图最长路径的起点是 `reset`。stock ABC 的对应全图值为 A0 13.13125 ns、C2 13.05245 ns；与独立计算相差不足 0.45 ps。不能将复位输入到寄存器的倒数当作寄存器间时钟频率。虚拟 X 类没有在上述模型中成为全图最慢类别，但它们的功能语义仍需另行修复/验证。

两种计算均保留 ABC 的条件时序弧处理和库表外推规则，不能视为签核 STA。尤其复位负载很大，外推与浮点量化使全图数字的精度低于表中打印位数。报告频率仅给约 0.1 MHz 精度。

## 关键路径与改善幅度

ABC 两版的 FF→FF 关键路径均从 Tile 0 的控制存储器寄存器到 Tile 8 的寄存器堆。独立 NLDM 的代表路径经源码归属核实为：

`Tile 0 控制地址 → 寄存器读有效/路由选择 → MemUnit 地址 → 共享内存请求仲裁与响应路由 → Tile 8 MemUnit/FU ready → ctrl_proceed → 寄存器写译码`

该跨 Tile 路径经过共享内存的控制交叉开关，没有经过 Tile mesh Channel、LinkOr 或控制环，也没有穿过内存数据阵列。因此，本次控制环的大幅面积节省不会按相同比例转化为频率提升。

Tile 8 后段包含同一 opcode 下互斥的 MemUnit/Adder 分支，是功能假路径候选。本次没有添加 false-path 约束或删除这条结构路径。独立计算在近似并列终点中选到 bank 3，而 ABC 选到 bank 0；完整证据分别保留，未将两条路径混称为完全相同的逐门路径。

## 复现

在已按 README 生成/综合的 A0 和 C2 目录上分别执行，输出目录必须是新的：

```powershell
sys_lib/.venv/Scripts/python.exe sys_lib/structural_cutpoints.py --input sys_lib/build/baseline/hierarchical/mapped.json --manifest sys_lib/build/baseline/manifest.json --output sys_lib/build/A0-frequency --liberty sys_lib/lib/NangateOpenCellLibrary_typical.lib
sys_lib/.venv/Scripts/python.exe sys_lib/abc_path_groups.py --source sys_lib/build/A0-frequency/all_ordered.blif --cutpoints sys_lib/build/A0-frequency/cutpoints.json --output sys_lib/build/A0-frequency/RR-100
sys_lib/.venv/Scripts/python.exe sys_lib/abc_path_groups.py --source sys_lib/build/A0-frequency/all_ordered.blif --cutpoints sys_lib/build/A0-frequency/cutpoints.json --output sys_lib/build/A0-frequency/RR-200 --offset-ns 200
sys_lib/.venv/Scripts/python.exe sys_lib/class_nldm.py --blif sys_lib/build/A0-frequency/all_ordered.blif --cutpoints sys_lib/build/A0-frequency/cutpoints.json --output sys_lib/build/A0-frequency/independent.json --absolute-driver
```

C2 将输入替换为 `build/C2-final/`，使用独立输出目录。计时入口默认 FF→FF；使用 `--source-kind all --endpoint-kind all` 可复现全图诊断。`abc_path_groups.py --help` 可查看独立工具路径参数。

机器可读汇总为 `results/frequency-comparison.json`，完整实验与子智能体活动见 `EXPERIMENT_LOG.md` 的 E06。旧严格时序诊断仍保留，原始网表及各轮日志位于 `build/timing-method-v2/`，本次没有对生产 RTL 作补连修改。
