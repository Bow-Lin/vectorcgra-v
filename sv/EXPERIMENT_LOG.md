# SystemVerilog 迁移实验日志

## M00：建立阶段与独立工作树（2026-09-21）

- 用户授权开始迁移，将第一阶段调整为单 CGRA、2×2 Tiles；允许 EDA 工具内部调用 Python。日常工程不得依赖 PyMTL 或项目 Python RTL 生成器。
- 基线：`ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。执行 `git worktree add -b codex/sv-migration D:/work/VectorCGRA/.worktrees/VectorCGRA ac96a7af930c9d6f814ab10e7bb61a10d6eaa33b`。首次因 `.git` 写权限受限失败，在工具授权范围内重试成功。
- 三个子模块从本机已有副本初始化，未修改原工作树：PyOCN `d8ffacc64fb8dd24ce26e944d501016880302bbe`，HardFloat `aea69e416e079178df4bb5697795ef653f55df58`，dp_fpfma `42f72d60ae37d6c33e81951ca87e7769d6fc4879`。
- 在主仓库本地 `.git/info/exclude` 排除 `/.worktrees/`，避免原分支误暂存嵌套工作树；未修改全局 Git 配置。
- 第一阶段采用原生 SV 顶层/测试平台加冻结固定 HDL 核心的路线，后续阶段逐层恢复原生参数化。附件缺失的 4×4 未提交资产不作为本次已有证据。
- 新建 `MIGRATION_PLAN.md`，列出五个阶段及完成条件；无源 Python RTL 修改，旧缺陷暂保持行为。

### 子智能体分工

本阶段复用此前三个子智能体，没有创建新的用户任务：

| 代理 | 本次负责范围 |
|---|---|
| `/root/area_report`（Boyle） | ac96 的 2×2 固定参考、迁移期生成脚本、manifest、参考周期数据 |
| `/root/noc_contract`（Bernoulli） | 独立 SV 自检测试、四 Tile 运算/通信配置及预期结果 |
| `/root/synth_tools`（Socrates） | 本机工具小样、独立编译/仿真/综合入口、工具版本和运行结果 |
| 主智能体 | 原生 SV 接口及顶层、分阶段计划、统一日志、集成验证、Git 提交 |

### 初步工具核查

- 可用 MSYS2 Verilator 5.050、G++ 16.1.0、GNU Make 4.4.1，以及 OSS CAD Suite 的 Yosys 0.69+62、Icarus/vvp 14.0。实际 SV 编译/运行小样由 synth_tools 继续验证，尚不据版本查询声称通过。

## M01：冻结 2×2 参考及独立 HDL 核心

- 首个计划提交：`02b838c`。`area_report` 从新工作树导入 ac96 源码；脚本检查基线 Python 未修改、三个子模块 SHA 一致，记录完整参数、字段位号、导入文件及工具版本。
- 参考 `reference/VectorCGRA2x2Reference.v` 包含 106 个模块、13 个 packed struct；SHA256 `f7d4479abe7b2305f21875a4ba82d685cb20d61275abbf4114786c57185487aa`。实测 Data/Ctrl/Payload/Host/NoC 位宽为 35/119/170/191/194。
- 主智能体编写 `migration_tools/freeze_core.py`，仅为模块和类型标识符加命名空间，保存直接编译的 `rtl/fixed/cgra_2x2_core.sv`，SHA256 `6be4c3471c14ea66bf14dea87c15c11fe7d5c327bcb741a4ca949e23ab1bf780`。逆向替换后与参考文件逐字节一致；没有修改任何 RTL 逻辑。两份 HDL 可在同一 TB 中并行实例化。
- 新增原生 `cgra_2x2` 顶层，全部原端口保持，内部直连固定核心；新增 `cgra_types_pkg` 公共类型/标量编码。三项外部 inter-CGRA 未驱动输出原样保留，不能因新封装随意补零。
- `core.autocrlf=true`，因此新增 `sv/.gitattributes` 对参考、向量、固定核心和迁移脚本关闭文本换行转换，防止 Git checkout 改变已记录字节哈希；Make/脚本及新 SV 保持 LF。
- `area_report` 用原 Python 模型完成两轮，每轮 3 个复位周期加 64 个运行周期，共 134 快照。输入 7 → 28；复位重配置后 −6 → −11。四 Tile 完成次序为 3/1/0/2，四段链路各传一次；地址 15 输入保持、地址 16 sentinel 被结果覆盖；西边界首 8 个有效周期和 CPU 首 6 个有效周期施加反压。
- 保存完整输入/输出 JSONL，并派生 505 位输入/489 位输出重播文件。此时只证明 Python 参考运行通过，尚不声称 HDL 重播通过。
- 首次向量导出因 Python int 列表不能由定制 bitstruct 打包而失败，改为迁移脚本内显式 Bits 类型后通过；没有改基线 RTL。参考 manifest 的封装说明曾误写为绑常量/隐藏端口，审查后改为保留全部端口，并记录仅说明维护、原始 RTL 未重生成。
- 非零类型样本由原 PyMTL packer生成，代理另按 manifest 的叶字段偏移重建并核对，无重叠/漏位；134 行重播解包也逐字段核对。主智能体新增独立 `tb_cgra_types.sv` 对公共 SV 类型进行黄金值检查，等待执行。

## M02：原生工具链和自检测试集成

- `synth_tools` 发现本机 UCRT G++ 16.1 编译后链接缺少 std::string 移动构造符号；static-libstdc++ 未解决。Icarus 对初始小样的命名 assignment pattern 也未通过。没有安装或改写工具。
- 改用现有 UCRT Verilator 5.050 与匹配的 clang64 Clang++ 22.1.8。构建参数消除不存在的 `-latomic`，链接命令通过 `env -u LINK` 避免 Windows LINK 环境变量被 lld 解释为参数。SV 类型/数组/参数/寄存握手与反压小样运行至 70ns，通过；sv2v → Yosys 综合检查也通过。完整 CGRA 尚待集成验证。
- `noc_contract` 编写独立 SV 配置构造和 TB：完整包/结果检查、两轮复位配置、四条内部链路、489 位活动输出与冻结 HDL 逐周期对照，以及故意错误和永久反压超时控制。对比不按 val 屏蔽其他活动消息。
- 参考资产代理完成后继续承担独立只读审查，检查测试判据、重播覆盖、打包样本及日常工具入口；主智能体负责集成结果复核与文档收尾。

### 完整验证结果

- 第二个提交 `7a1608d` 保存固定参考、核心、公共接口、参考数据及来源。主智能体用 Git blob hash 核对参考 RTL、核心和三个重播关键文件，提交后的字节与工作文件完全一致。
- 首次完整 Verilator 因 352 条警告的默认 fatal 策略退出；确认无语法错误后为完整 DUT 使用 `-Wno-fatal`，保留所有警告及完整运行检查，没有修改核心。最终测试版本记录 354 条警告，详情见 `results/verilator-warnings.json`；类型和工具小样仍采用默认警告退出策略。
- 独立审查提出缺少最终覆盖数硬断言和日常类型/超时入口。已补每轮 64 周期、HDL 与 Python 各 134 次对照断言，并将 `types` 与 `timeout-negative` 纳入 `all`。首次正例后重新编译并运行最终断言版本，成功标记为 `CGRA_2X2_PASS scenarios=2 compared_cycles=134 pymtl_cycles=134 compared_bits_per_cycle=489`。
- 两轮各 26 个主机输入包全部由独立 SV 构造并与黄金 hex 一致；各有 4 个 Tile 完成、2 个读回、1 个西边界输出；四条相邻链路每轮各传一次。输入/输出分别为 7/28 与 −6/−11。统计的 CPU 总反压为每轮 8 周期（初始 6 周期加后续周期模式），West 为每轮 8 周期。
- 所有 134 快照的 505 位输入和 489 位活动输出与原 Python 记录逐位相同；SV DUT 与冻结 HDL 也逐位相同，包含 val=0 时的消息。只排除基线原本未驱动的 3 个外部 inter-CGRA 输出，未新增位掩码。此结论是所选 Verilator 二态语义下的有限程序验证，不是任意四态 X 或所有参数/程序的证明。
- 公共类型的 5 个位宽及 4 个独立黄金样本通过，标记 `CGRA_TYPES_PASS`。故意错误结果触发指定 `$fatal`；永久 West 反压在第 200 周期超时，此时 24 输入、3 完成、0 回读、0 West 接受。两个 Make 负测都要求模拟器非零退出并匹配指定错误文本，均通过。
- `sv2v → Yosys` 通用综合、层级与最终结构检查通过。当前 Nangate45 typical 映射流程从同一通用 JSON 继续映射，最终 `check -mapped -assert` 为 0。标准单元面积 773,152.408、标准单元数 474,566（已排除层次实例）、DFF_X1 49,228。未执行频率测量或与不同配置的旧 4×4 数值比较。
- 优化前 Yosys 报出 642 个去重后的模块/位未驱动警告，分 25 组，包括未启用的 DMA/Im2col、元素控制接口、单 CGRA 外部 NoC 和 Tile const clear；这不是整机逐实例的未知位计数。最终检查为 0 不代表源 RTL 没有未定义值。脚本没有 `setundef`、补零或其他语义修复。
- 工具、源文件、参数和结果分别归档于 `results/probe-summary.json`、`simulation-summary.json`、`synthesis-summary.json` 及警告摘要。日志保留在 `build/`。

## M03：脱离 Python 项目的独立构建验收

- 主智能体将 `rtl/`、`tb/`、`reference/`、`vectors/`、`scripts/`、`filelists/`、Makefile 和许可证复制到全新 `sv/build/standalone-phase1`。没有复制原 Python 目录、迁移脚本或旧编译/综合缓存。
- 在该目录执行 `scripts/run.ps1 -Task all -OssCadSuite D:/work/VectorCGRA/sys_lib/tools/oss-cad-suite -Sv2v D:/work/VectorCGRA/sys_lib/tools/sv2v-v0.0.13/sv2v-Windows/sv2v.exe -Jobs 2`。从头完成类型测试、系统编译/仿真、两项负测和通用综合，进程退出码 0；未重复标准单元映射。
- 两轮结果及 134/134/489 比较计数与主工程一致。独立目录 Python 文件数为 0，运行文件哈希全部与主工程相同；工具内部依赖保持允许。`results/standalone-summary.json` 保存命令、运行文件及日志 SHA256。
- 复制根项目、PyOCN 和实际安装的定制 PyMTL 许可证，随独立 HDL 目录保留来源声明。
- 第一阶段完成，后续参数化、向量/浮点、其他 Tile、多 CGRA 和全项目配置替代仍按阶段计划执行。未修改 ac96 的 Python RTL 或引入 B/C2；未推送或合并 master。

## M04：独立审查与结果归档

- `area_report` 对最终源码、运行日志和综合统计做只读复核。发现一项 P2：摘要将 `stat.design.num_cells` 再减 1，误报为 474,565。该 Yosys 版本的总数已排除层次，而类型分项仍有 1 个层次标记；代理按 `mapped.json` 的实际实例递归到 Liberty 叶单元，得到 **474,566**，DFF_X1 **49,228**，按 Liberty 精确面积加总 **773,152.408000**。已修摘要与文档；原始 stat、网表和测量不变。
- 全部已记录的源码 SHA 与当前文件相符；最终日志确认 134/134/489、类型通过、指定错误非零、200 周期超时和最终综合 0 problems。除统计修正外未发现待处理 P1/P2。
- 补充统一原始日志哈希和压缩证据归档，防止后续重跑覆盖 `build/` 日志而丢失本阶段证据。运行源码和当前测试结果未因此变化。

## M05：将测试用例统一放到 sv/tests（2026-09-21）

- 根据用户要求，在迁移工作树 `D:/work/VectorCGRA/.worktrees/VectorCGRA`、分支 `codex/sv-migration` 上，将 `sv/tb/` 整体移到 `sv/tests/`。移动前提交为 `ff09971`；四个文件为 README、`scalar_workload_pkg.sv`、`tb_cgra_2x2_scalar.sv` 和 `tb_cgra_types.sv`，移动前后 SHA256 全部一致。
- 主智能体更新 Makefile 的测试依赖和类型测试编译参数、`filelists/sim.f`、`.gitattributes` 及工程目录说明。模块名称、测试逻辑、RTL、参考 HDL 和向量内容均未修改；后续功能测试放入 `tests/`，向量继续保存在 `vectors/`，工具小样仍在 `scripts/probes/`。
- 复用 `/root/area_report`（Boyle）完成只读审查，没有新建子智能体或用户任务。代理用 Git blob 独立确认四个移动文件与 HEAD 旧路径完全一致，并检查全部活动引用，无待处理 P1/P2。
- M03 的旧独立构建副本、第一阶段摘要和 `phase1-evidence.zip` 保留 `tb/` 路径及原始哈希，作为 `ff09971` 的历史证据；不改写旧验证记录。
- 从新路径执行 `scripts/run.ps1 -Task all`（工具路径和 Jobs=2 同 M03），进程退出码 0。Makefile 更新触发类型和系统测试重新编译；类型检查通过，两轮结果为 28 和 −11，HDL 对照及冻结 Python 数据重播均为 134 周期 × 489 位，错误预期和永久反压超时两项负测均按要求非零退出。RTL 和 RTL 文件列表未变，通用综合使用已有目标，没有重新综合或映射。
- 当前路径、运行源码与日志 SHA256、执行命令和结果保存在 `results/tests-layout-summary.json`，与第一阶段历史摘要分开记录。
