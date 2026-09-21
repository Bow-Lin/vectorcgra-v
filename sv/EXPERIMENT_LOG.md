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

## M06：启动参数化单 CGRA 迁移（2026-09-21）

- 用户确认继续下一阶段 migration，而非新一轮面积优化。沿用 `codex/sv-migration`，起点为测试目录调整提交 `741dc5d`；原 NoC 优化分支和 master 不变。
- 主智能体负责参数/类型规则、Controller/GlobalReduce、全局数据存储与 bank、原生阵列 generate、构建集成和 Git。复用 `/root/noc_contract`（Bernoulli）负责基础队列/RF/仲裁和 credit NoC，`/root/synth_tools`（Socrates）负责 FU/Tile/本地存储及静态交叉开关，`/root/area_report`（Boyle）负责独立 ac96 多参数参考和原生系统测试。没有新建子智能体或用户任务。
- 采用逐模块保留原状态更新与组合语义、重新表达类型/位宽/实例数及连接规则的路线；去除固定哈希模块名和重复生成源注释。迁移期提取工具与参考导出工具保存在 `migration_tools/`，日常构建只读维护的 HDL。
- 几何验收为 2×2、4×4、3×2；测试闭环经过所有 Tile，Tile 0 跨 bank load/store，中间执行加法/乘法并由末 Tile 多播。另增加 2×2/64 位/控制深度 16/寄存器深度 8 的组合，验证不能仅按阵列尺寸机械替换常量。
- 明确保留 ac96 的未驱动 const clear、禁用 DMA 和单 CGRA 外部 NoC 端口限制，不用补零改变语义；ring 的 VC/credit 参数在原 Python 构造中并未完整传播，本阶段明确约束为 2/2。
- 实施和集成验证进行中；后续 M07 记录实际通过项、失败修正、覆盖边界及最终结果，当前不据源码存在宣称验收通过。

## M07：模块替换、参数恢复与集成修正

- 计划提交 `c2a05a0`；独立参考提交 `a2162a5` 冻结四个参数点的 ac96 HDL、完整来源 manifest、逐字段位号、配置包及 Python 周期轨迹。参考导出器快照随各参数点保存；生成资产保留原始 CRLF/空白以维护 SHA，空白检查不改写这些取证文件，迁移脚本另外检查。
- 维护的 DUT 现由 30 个原生 SV 模块组成。普通/bypass 队列、RF、Channel、仲裁、分组交换与控制环恢复消息位宽/节点数/深度参数；FU、本地存储、静态 crossbar 和 Tile 恢复数据宽度、控制深度、寄存器深度及 ID 字段。主智能体以共享 profile 类型连接 Controller、数据存储和原生 mesh generate，`cgra_2x2` 改调 `cgra_scalar`；旧测试只更新内部链观测路径，原测试数据/判据保持。
- 用户补充“非方形仅在原架构支持时验证”。确认原 `CgraRTL(width,height)` 支持，且未修改的 ac96 3×2 已真实执行全部六 Tile 的闭环，因此保留该兼容性点，不扩展原架构范围。
- 首轮系统运行：2×2 为 134×489 位、3×2 为 158×563 位、4×4 为 286×789 位、64 位参数变体为 134×770 位，原生 HDL/独立 ac96 HDL/Python 轨迹全部一致。每轮所有 Tile 完成，所有闭环链路各接受一次，结果分别为 28/−11、12/−27、−68/−107、28/−11。原 2×2 的阶段 1 测试也通过。
- 独立测试：Tile 2000 次全输出采样；FU/RegisterCluster/两个静态 crossbar 各 1999 次；基础组件/5 节点环 500 周期；7/17 节点环各 800 周期。测试源码和复现入口均在 `tests/`，没有留在忽略的 build 中作为唯一副本。Tile 摘要在 `results/phase2-native-tile.json`；NoC 来源和有限覆盖说明在 `tests/native_noc_README.md`。
- 第一次完整综合在 xbar 报 `route_val[9] already driven`：多个过程动态写全局二维数组，sv2v 展平后形成重叠驱动。`noc_contract` 改为每个静态数组元素单独赋值，保留原 if 条件的未知值语义，重新运行 500 周期组件差分通过；之后完整 2×2 Yosys synth/check 通过。初次失败日志保留为 `build/phase2-failures/synth-route-val-initial.log`；没有关闭检查、删去功能或补零。
- NoC 独立综合入口还遇到本机 Yosys `hierarchy -chparam` 的内部 duplicate-module assertion，改用独立 `chparam` 后 `hierarchy` 的参数展开顺序；12 组 queue/channel/RF/xbar/ring 前端与结构检查均通过，全部 0 problems。
- `area_report` 只读核对阵列/Controller/数据存储/GlobalReduce，发现容量检查使用 32 位 `2**GLOBAL_ADDR_W` 会错误拒绝 31/32 位地址宽。已改为 64 位容量运算；同时对参数错误使用 `initial if ... $fatal`，避免依赖 Verilator 可选的 `--assert` 开关。代理复核该 P2 已消除，无其他未处理 P1/P2。
- 最终 RTL 冻结后，保存 `build/phase2-final-inputs.json`，失效五个生成的仿真可执行文件并重新执行 `-Task all` 与 `-Task phase2`，保证归档对应最终源码。只失效当前工作树 build 下指定的可执行文件，不改历史参考/源码/外部工具。最终结果、综合参数点及证据归档在 M08 收尾时记录。

## M08：最终回归、综合与证据提交（2026-09-21）

- 最终 `-Task all` 和 `-Task phase2` 均退出 0。重新编译后的四个参数点仍分别通过 134×489、158×563、286×789、134×770 位周期对照；每点两轮，独立算术结果和每个 Tile 的完成/内部链路检查通过。旧 2×2 回归为 134×489，类型样本通过。旧 2×2 与新增 3×2 各做故意错误和永久反压负测，均验证非零退出及指定文本；超时上限分别 200 和 300 周期。
- `synth_tools` 追加完整原生 DUT 的 4×4、64 位/CTRL=16/REG=8 综合入口 `tests/check_phase2_synthesis.ps1`。`sv2v → Yosys synth -noabc → check -assert` 两项分别用时 253.69 和 126.88 秒，全部 41 个外部端口保留，最终均为 0 problems；默认 2×2 的同类完整综合也通过。原有未驱动警告仍存在，最终结构检查不能解释为源 RTL 全部已定义。12 项 common/NoC 检查只包含前端及结构处理，与上述完整综合分开统计。
- 非法 `TOTAL_STEPS=2048` 负控由 Yosys 以 exit 1 拒绝，工具输出 `$finish executed`；入口核对报错文件/行号及紧邻的指定 TOTAL_STEPS fatal 文本，确认拒绝原因正确。结果保存为 `results/phase2-profile-synthesis.json`。本阶段没有执行标准单元映射或 Fmax 测量，generic cell 统计不作为面积结果。
- `area_report` 再次只读审查最终参数、构建依赖、测试和综合证据，发现取证 P2：部分已测 CRLF 文件若按原 Git 属性转成 LF，会与记录 SHA 不一致。主智能体仅调整 `.gitattributes`，对 12 个原生 Tile/FU/存储文件、3 个已测 TB 及 phase2 结果 JSON 保留原始字节；未修改已测 RTL/TB 内容。代理复核来源 SHA、综合日志/统计、负测位置和日常入口；没有其他待处理 P1/P2。已测文件中的普通行尾空格保持，空白检查允许这些非功能空格及 CRLF，不为格式修改已测字节。
- 原生实现提交为 **`614dc8bd0806c8ae9f99734c7535e2d602f96eaa`**，共 51 个文件；提交前逐一核对 44 项已测源码/入口的原始 Git blob 与暂存 blob 一致。此次没有创建新子智能体；仍为 M06 中三位代理，主智能体负责集成和提交。
- 新增 `results/phase2-summary.json`，记录基线/实现版本、工具、命令、四点结果、组件检查、完整综合范围和源码 SHA。归档 67 项运行、编译、综合日志/统计及摘要到 `results/phase2-evidence.zip`，大小 2,643,517 字节，SHA256 为 `975357845a1eb673df99fea14b461d9ea43c7375d65399741471d633633318b1`。每个条目的 SHA 在 `phase2-evidence-manifest.json`；从压缩包逐条读取核验，避免只记录工作目录文件哈希。
- 第二阶段完成。`PHASE2_REPORT.md` 明确有限程序、二态比较及参数覆盖边界；向量/浮点、其他 Tile、多 CGRA 与 DMA/im2col 留待后续阶段。原 ac96 Python 源码、第一阶段参考/证据、原工作树的 NoC 优化分支和 master 未修改；没有推送或合并。
