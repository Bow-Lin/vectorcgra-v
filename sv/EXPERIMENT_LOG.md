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

## M09：启动第三阶段完整 FU 与 Tile 变体迁移

- 用户授权继续第三阶段。起点为第二阶段收尾 `786b732`，仍在独立工作树 `D:/work/VectorCGRA/.worktrees/VectorCGRA`、`codex/sv-migration`；基线保持 ac96，原工作树与 master 不改。
- 复用三个既有子智能体，未新建用户任务或代理：`area_report`（Boyle）负责其余 15 个标量 FU；`noc_contract`（Bernoulli）负责向量、组合运算和既有定点 MAC IP；`synth_tools`（Socrates）负责 StreamingMem、上下文切换/流式 Tile 及局部状态机。主智能体负责浮点 IP、可配置 FU 组合、单 CGRA 集成、阶段回归、证据归档和 Git。
- 文件按各子任务隔离到 `rtl/fu/{scalar,vector,combo,float,streaming}`、`rtl/tile/variants`、`reference/phase3/` 和 `tests/phase3/`。测试入口和长期用例留在 tests；迁移取证 Python 放在 migration_tools；日常工具链直接消费 HDL。新增维护源统一 LF，外部 IP 和冻结参考保留原字节及许可证。
- 当前仅开始盘点和实施，不据模块数量宣称完成。后续逐项记录基线限制、接口选择、真实执行结果及阶段完成边界。

## M10：FU、浮点 IP 和 Tile 变体实现与参考取证

- 三位既有代理继续 M09 分工，未创建新代理。主智能体新增 `cgra_fu_catalog.svh`、`tile_flexible_fu_configurable`、`tile_programmable` 和 `cgra_programmable`；FU 顺序在构建时确定，数据、控制和内存端口保留原接口。聚合器保留原先 ready 按位 OR、最后一个有效 FU 输出优先的规则，没有引入仲裁或寄存器。共享 profile 增加 TILE_PORTS，四端口控制字仍为 119 位；原八端口 KingMesh 配置为 143 位。
- `area_report` 完成 15 个剩余标量 FU 及流水除法辅助模块。默认 32 位对照 15 项原参考 HDL，其中 13 项另与原 Python 轨迹比较；64 位对照 13 项。Gep/LoopCounter 的两参数数据构造、ExtractPredicate 的动态类型表达式及 Div 的 FloorDiv 翻译不受本机 RTLIR 支持。代理保存失败输出，使用隔离的迁移适配器；三份适配 Python 逐周期与原 Python 全输出核对，Div 保留原 Python `//` 作为数值参照。原项目 Python 不改，适配后的 HDL 不冒称直接来自未改源码。
- 标量最终运行：32 位 2,881 周期、每模块 303 位、929 项独立数学检查与 32 项流水结果检查；64 位 3,105 周期、每模块 424 位、950 项数学检查。故意扰动 oracle 和 watchdog 负控均被正常检查器拒绝。28 个参数/模块组合的 sv2v、Yosys proc/opt/check 通过；这类结构检查与完整 synth -noabc 区别记录。流水除法保留原固定 32 位和默认 2/4 周期。初期遗漏比较器常量、Ret 地址/数据位宽等原生移植错误在对照测试中修复，详见 phase3-scalar.json。
- 主智能体迁移 FP 加/减/常量加/增量与乘/常量乘封装，复用 ac96 指定 HardFloat 子模块的原始 HDL，保存许可证、revision 和文件 SHA。参考导出在 Windows 盘符根目录遇到 PyMTL PlaceholderPass 的两处无限向上查找，先后中止本次启动的挂起进程，然后只在迁移脚本内使用根目录感知的 pass 子类；未修改安装工具。参考联合编译只做可逆命名空间隔离和诊断 `line` 文件名分隔符转换。
- FP 取证确认 ac96 的 `exp_nbits+1, sig_nbits` 映射：8/23 参数实际使用 9 位指数、22 位小数，不是 IEEE binary32；4/11 参数使用 5 位指数、10 位小数。两组 FINC 常量都表示 0.5。保留 FMUL_CONST 不检查常量 val、FINC 的 ready-gated val。首轮原生连接误用 `.in`，按库原接口修为 `.in_`；独立数学 oracle 首次把负数乘零的预期写成正零，原生和参考均给负零，修正的是该预期而非 DUT。四组最终各 1,170 次全输出对照、168 项独立数值检查，四组完整 synth -noabc/check 及错误预期负控通过。
- `synth_tools` 完成 StreamingMem、ContextSwitch 状态机、两个完整 Tile 及其控制存储/crossbar/常量队列变体。Context Tile 为四端口；原 Streaming Tile 的四端口构造本身类型不匹配，按原测试采用八端口 KingMesh。ContextSwitch 和完整 Tile 的原 RTLIR 翻译有限制，采用未改 Python 的顶层原始输入/输出轨迹加独立结果检查，没有捏造 HDL 参考。Context Tile 的 210 周期覆盖 12 次输出、两次完成和 TERMINATE 清空已满通道；Streaming Tile 190 周期覆盖十次请求/响应、两次完成及中途复位；两个完整 Tile 的 synth -noabc/check 通过。
- `noc_contract` 迁移五个向量层级模块、五个组合 FU 和定点 MAC。原 PrlMulAdder 的标准 Ctrl4→子 Ctrl2 翻译不合法，用原架构合法的 Ctrl2 参照并记录显式字段映射，保留标准构造失败证据。原 DW02 乘法模型全部在 translate_off 区域，不能作为可综合 DUT；代理新增 `cgra_multp` 与 native MAC core，保留 Booth 部分积和压缩顺序，原 vendor 不改且仅作参考。九组位宽共 18,432 次对照原模型两路部分积，并独立核对 signed/unsigned 乘积，通过七组前端/结构检查。
- 向量乘法发现原 Python 仿真和翻译后 HDL 的实质差异：8 位子乘积拼接时 HDL 将位移表达式压到 4 位，16/24 变为 0/8。本阶段以冻结 HDL 的硬件行为为兼容默认，明确不声称该项与原 Python 数学结果等价。差异最小示例、失败日志、原位宽表达式和最终原生处理单独归档，不以修改参照消除差异。

## M11：可配置单 CGRA 集成与阶段回归

- 主智能体把基准四 FU、增加 Logic 的五 FU 组合及 FP 组合接入 2×2。三种完整 CGRA 都已通过 134 周期 × 489 位原 HDL 对照，基准和 Logic 同时通过未改 Python 重播；FP 使用真实原 HardFloat HDL，不声称纯 Python 仿真。基准/FP 两轮结果 28、−11，Logic 两轮为 −32、7；每轮四个 Tile、四条链路、跨 bank 读写、主机及西边界反压均实际执行。三种完整系统的错误结果和永久反压负控均按指定错误非零退出。
- 第一版系统负控 shell 在裸 MSYS bash 缺少 `/usr/bin` 而找不到 dirname；补全与其余入口相同的 PATH 后通过，不是 DUT 故障。浮点系统独立按实际基线格式编码整数计算，未借 DUT 输出构造预期。
- 复用 `area_report` 增补完整 2×2 向量程序并审查 FU/profile；复用 `synth_tools` 增补两个 Tile 变体的完整 2×2 程序与 KingMesh 对角链路；复用 `noc_contract` 只读审查 FP 源码和证据。原分工之外的补充任务均在本阶段内，没有创建新代理。
- `area_report` 审查发现组合顶层公开 VECTOR_FACTOR_POWER，但原 FlexibleFuRTL 不把该构造参数传给各子 FU，旧四 FU 也固定使用 0。主智能体增加明确的非零参数拒绝，不让不同 FU 悄悄使用不同因子；独立 FU 的参数保留。已通知其余代理冻结后的测试/哈希要求。为避免把旧输入的综合结果当成最终源码结果，中止正在执行的完整 CGRA 综合，待向量乘法位宽及参数 guard 固定后从头运行。

## M12：最终检查、Git 提交与证据收尾

- 最终原生源冻结后，主智能体重跑 Base/Logic/FP 三种系统及其错误结果/永久反压负控；`area_report` 完成向量系统和两项负控，`synth_tools` 完成 Context/Streaming 系统与周期 20 扰动负控。六种完整系统均实际通过：前五种各 134 周期 × 489 位，Streaming 160 周期 × 513 位。向量两个结果为 `84ff0004`、`04080a7e`；Streaming 两轮五个结果分别为 10/13/16/19/22 与 −8/−5/−2/1/4，两条对角链路都实际传输。Context Tile 的独立手算序列检查覆盖首轮六输出，第二轮使用完整原 Python 轨迹与事务计数，没有将全部 12 个都表述为额外手算验证。
- 修改共享 profile 后，`-Task phase2` 完整重编并通过 2×2、3×2、4×4、64 位/CTRL16/REG8 四组参数回归，分别为 134×489、158×563、286×789、134×770 位；每点全部 Tile/闭环链路完成，3×2 两项负控也再次通过。历史 phase2 的 JSON、证据 zip 与原源码提交不改写，本次结果收入 phase3-summary。
- 最终完整 CGRA 的六个参数/FU 配置全部通过 sv2v、Yosys `synth -noabc` 和最终 `check -assert=0`。各保留 41 个原端口，四端口输入/输出 702/685 位，八端口 750/733 位。六组用时分别为 Base 334.48、Logic 232.56、FP 148.08、Vector 116.73、Context 95.00、Streaming 112.91 秒；并发编译影响墙钟时间，这些数值不是性能指标。`check_guard.ps1` 另实际验证 VECTOR_FACTOR_POWER=1 非零退出，Yosys 报错行的前一行匹配指定 guard，不能用任意工具失败替代。
- `noc_contract` 的 30 组向量/组合配置各 640 周期，共 19,200 次全输出比较及独立算术检查全部通过；部分积九形状共 18,432 样本通过。补充综合时，28 个非 MAC 参数点的早期层级 proc/opt/check 有 25 个因原未驱动子端口/字段失败，三种 VectorMul 叶模块通过。保存这些失败，再走普通 proc/flatten/opt/synth -noabc/check，28 点最终均为 0，综合前后端口名称/方向/位宽全部一致且无黑盒。未使用 setundef 或补零；最终 0 不代表原未知值获得定义。七个 MAC/乘法器参数点的前端/结构检查与上述完整综合分别登记。
- `area_report` 复核组合器参数、最后有效输出优先、ready 聚合、访存绑定；参数 guard 的 P2 已关闭。`synth_tools` 复核 CGRA 与 KingMesh 连线、最终综合位宽算法及来源；49 个 manifest 的 3,352 条原始源 SHA 和 100 个明确产物 SHA 均一致。`noc_contract` 只读审查 FP 原封装、格式与独立预期、四项综合来源，无待处理 P1/P2。标量原始导出与后来 namespace/resume 转换明确分开；向量 30 个成功参照的历史 exporter 快照与各自 manifest SHA 全部一致，不用当前演进脚本改写历史来源。复用原三位代理，没有新建代理或用户任务。
- 参照提交 **`9daf3ec`** 保存 356 个参考/向量/取证项，逐一核对暂存 blob 与原始工作文件字节一致。实现提交 **`d71a2bb69b8f0fe22fc1d1bd29562ea4ed9df9c1`** 保存原生模块、IP 来源、profile 与文件列表；同时移除四个与 `original.v` SHA 完全相同的 `__pickled.v` 临时副本，并局部忽略此类重复导出物，冻结原参考内容保留。
- 验证提交 **`17aaefab8bfceb245874dfd28aaa28b4f0c08808`** 保存所有 tests/phase3 用例、日常 Make/PowerShell 入口与组件结果。提交前发现两个 PowerShell 生成的综合 JSON 会被 Git 从 CRLF 转成 LF，给 `tests/phase3/**/*.json` 设置 `-text` 并重新暂存，112 项暂存文件与原字节逐一核对通过。没有改动已测 RTL。Make 目标展开和所有 shell 语法检查通过；各实际运行命令分别完成，不把 Make dry-run 记作仿真通过。
- 主智能体生成 `results/phase3-summary.json` 与证据归档，记录 baseline、实现/验证提交、三位代理分工、六系统、四参数回归、源码哈希及限制。`phase3-evidence.zip` 含 503 个条目，10,893,363 字节，SHA256 为 `cb8d254ccd58609e0eed0a284246c690e80f82755d2f06b31b1643d171bfe5c0`；逐条从 zip 读回核验，清单独立保存。未测标准单元面积/Fmax，未修改原 Python，未推送或合并 master。第四阶段的多 CGRA、跨 CGRA 迁移、DMA/im2col 仍待执行。

- 最后复用 `area_report` 独立审查整体汇总、源码与归档。503 个条目、六系统、四参数回归和对应源码 SHA 均匹配，89 条 RTL SHA 同时匹配实现提交。代理发现机器 JSON 顶层 flow 标签可能把七项 MAC 结构检查混同为完整综合的 P2；提交 `930c178` 将其拆为 extended_profiles_flow 与 mac_flow，并同步生成脚本。逐字段核对仅标签变化，脚本实际运行命令与 `17aaefa` 完全相同，因此不重复硬件测试；随后重新收集汇总和 zip，以上尺寸/SHA 已更新为最终版本。主智能体另核对七份结果中 421 条运行源码 SHA，与当前工作树全部一致；参数负控和六系统综合使用相同转换输入。

## M13：第四、第五阶段启动（2026-09-22）

- 用户授权继续完成后面的迁移任务。本轮同时推进阶段 4 系统扩展和阶段 5 独立交付；起点为 `1a5585a`，继续使用 `codex/sv-migration` 工作树，原 Python 基线、原工作树 NoC 优化和 master 不改。
- 复用三位既有子智能体，没有创建新代理或新用户任务：`noc_contract`（Bernoulli）负责跨 CGRA Mesh/Ring NoC；`synth_tools`（Socrates）负责 DMA 与 im2col 引擎；`area_report`（Boyle）负责源码覆盖审计和非 Python 配置工具。主智能体负责公共字段参数、Controller/存储、CGRA 集成、系统验证和 Git。
- 子任务分别隔离到 `rtl/noc/inter_cgra`、`rtl/peripheral`、`tools`，测试位于 `tests/phase4` 和 `tests/phase5`。各代理的 WORK_LOG 记录具体命令、失败及修正，本文件记录跨任务决策和最终结果。
- 先以原生可配置 RTL 恢复多 CGRA ID/坐标/地址映射和 DMA 端口，默认单 CGRA 参数保持既有编码；再验证多阵列路由、远程访存、迁移/归约、外设和异构拓扑。配置工具必须能够构造新程序，不能仅依赖冻结参考向量。最终在仅包含 SV 工程的目录运行测试/综合；EDA 内部调用 Python 仍按用户澄清允许。

## M14：公共类型、多 CGRA 与外设集成实施

- 主智能体恢复多 CGRA ID/坐标位宽、地址 owner LUT 和坐标 LUT；增加 MAX_COLS/MAX_ROWS/MAX_MEM_PORTS 以共用异构消息布局。DMA 的本地 crossbar source/destination 宽与 NoC remote_src_port 宽分别推导，避免新增 master 后字段错位。Controller 中原有 DMA/im2col 分支改为可选择参数，补连原先禁用的 im2col queue 输入；默认参数保持阶段 1 字段布局。
- 恢复 DataMemWrapper 的原有可选一周期读/写请求 channel，默认仍为组合模式；没有改动 RAM 的无 reset 语义。普通 Tile 的物理端口、routing crossbar 和 ctrl memory 原先仍有四端口展开常量，本轮改为可维护的 4/8 端口 generate，供 CgraTemplate 使用。Context/Streaming 的 CGRA ID 端口同步拓宽。
- `cgra_system` 接入外部 NoC/local bypass、DMA 和 im2col，并提供每 Tile FU 列表及静态 LinkList/存储连接表；`cgra_multi` 接入原 host-at-CGRA0 的 Mesh/Ring 与物理边界；异构封装正在集成。这些新增系统尚在验证，不以 lint 通过声称完成。
- 默认 2×2 `tests/phase3/system/run_base.sh` 在公共位宽扩展后、普通 Tile 改写后分别实际通过：134 个原 HDL/Python 周期样本，每样本 489 位；正负两轮结果 28/-11，四条 Tile 链路和背压检查通过。普通八端口系统、DMA+多 CGRA 参数均通过 Verilator elaboration；完整新系统回归与最终重新综合后续记录。
- 未修改 ac96 参考导出得到 Mesh 四 CGRA、每个 2×2 Tiles 的远程访存程序：两轮各 189 周期（另加 3 reset 周期），每轮 16 个 Tile 完成、8 次主机查询，四个地址 owner 返回与独立算术值一致，冻结原始 HDL 和 Python trace。原生差分正在编译。
- `synth_tools` 发现 DMA 原 Python 与导出 HDL 的切片宽度差异：128 位数据第三个 32 位 word 的下界表达式按 6 位截断，使 64 变为 0。沿用阶段 3 VectorMulCombo 的合同，要求默认保留导出硬件；Python 语义必须显式选择并分别取证，不能静默更换参考或隐藏非重复数据反例。
- `area_report` 配置工具已通过默认/64 位/八端口三个配置及越界负控，继续补 LoopController 与确认可用的旧存储/选择器/寄存器组件。`noc_contract` 完成多种 Mesh/Ring 原参考和差分，随后负责跨阵列边界、全局归约与真实任务迁移程序。

## M15：系统差分、源功能补漏与失败处理

- 继续复用原三位代理，没有新增代理。`noc_contract` 扩展到动态 FIR 迁移、全局 ADD 归约与独立读写端口内存；`synth_tools` 扩展到 DMA/im2col 完整 CGRA 集成和模板只读审查；`area_report` 扩展到独立 LoopController、可用旧模块及源功能清单。具体组件证据在各 tests/phase4、tests/phase5 的 WORK_LOG 与 JSON。
- 主智能体完成 `cgra_multi_template`：共享最大消息几何，局部 CGRA 为 2×2/3×3/2×2/2×2，逐 Tile 有序 FU 列表，静态定向 LinkList、停用对角链路、独立读写 Tile 连接表，以及相邻不同大小 CGRA 的重叠边界连接。原始异构参考首次因迁移 harness 漏调原 `configure_boundary_ports` 而报 NoWriter；保存失败目录和快照，补调用原 helper 后未改原 Python 即成功。原生/参考 HDL/原 Python 三方在 206 周期 × 221 位全部一致，21 完成、8 次回读、24 个 host 反压周期；后续公共参数追加需要在最终源码再验证。
- 同构 Mesh4×Tiles2 初次三方对照通过 384 周期 × 195 位，32 完成、16 回读、40 远程请求与 20 远程响应。Ring 的原生和两个参考一致，但独立检查器错误要求不同 owner 的响应全局有序；原 Ring 允许跨目的响应交错。修正为每 owner 内顺序与唯一性，保留全原始位周期比较，四个参数点正在统一重跑。
- 全局 ADD 未改 Python 参照与原生 SV 在 91 周期 × 1779 位通过，局部 10/26 归约为 36，最终独立结果 53/31、六个完成包和故意错误负控均通过。原动态 FIR 参照 165 周期得到 2215，包含 126 配置包、保存/恢复和跨 CGRA 物理链接；原生核对仍在执行。两个集成 bench 首次漏计原 FlexibleFuRTL 自动附加 Nah，正确被原生 FU guard 拒绝；修的是测试 profile 的有效 FU 顺序，未改原程序或参考。
- DMA 六组组件 profile（两种宽度、两种语义和两个 im2col 配置）均完成差分、独立事务检查和负控。DMA 完整系统初次通过 86 周期与原 HDL 对照，2 done/tag、5 CPU 回读、2 DRAM 读和 2 写 beat；默认保留两个已知错误 MVIN word，不将其描述为正确搬运全部数据。im2col 系统正在编译。
- NoC 九配置共 18,729 周期、4,736 个独立计分数据包通过；Mesh 四配置及 Ring2 完整综合通过。Ring2 的完整 JSON 约 466 MB，PowerShell对象化时占约 6.8 GB，拖慢主机；代理核对 PID 22172 确为自己启动的脚本后仅终止该解析，保留综合日志，改为 Yosys 紧凑统计。其余 Ring 改做前端结构检查，并明确区分验证级别，未把它们算成完整映射。
- 源功能盘点发现 DataMemController 的读写端口数独立。主智能体增加 MEM_WRITE_PORTS、独立 write request 类型、write crossbar/source 位宽、bank 写通道和系统连接表；默认等于 MEM_PORTS，原有配置保持不变。r1w3 的原 HDL 可生成；r3w1 在原 RTLIR 中因将 1 位 write source 截断到 2 位 remote source 而失败，保存失败证据，不修原 Python 来伪造原支持范围。
- 只读审查指出 host-only 多 CGRA 封装未暴露外设端口，新增 HAS_DMA/HAS_IM2COL 的明确拒绝，外设由 cgra_system/integrated wrappers 接入。旧标量/可配置单 CGRA 入口也拒绝误用多 CGRA/外设和非对称存储配置。
- 运行环境中的两次裸 bash 调用分别遇到 login shell 改目录和缺少 /usr/bin，补显式 PATH 并使用非 login shell 后恢复。一次正在执行的 template run.sh 被更新，导致 bash 文件偏移错误；已编译可执行文件独立运行通过，最终从稳定脚本重跑。工具 apply_patch 对 worktree reparse point 曾返回错误但部分文件已落盘，主智能体逐文件确认实际修改后补齐，没有盲目重复应用。
- 新增统一 phase4/phase5/regression 入口，以及不覆盖已有目标、逐文件 SHA 校验的 export_standalone.ps1。此时独立交付和最终综合尚未完成，后续记录实际结果；不把入口存在当成执行通过。

## M16：最终实现冻结、独立程序和取证范围

- 实现分为 `0277704`（共享字段、独立读写存储口、Mesh/Ring、系统与异构模板）及 `4927d87`（DMA/im2col、LoopController、旧模块、SV 配置工具和完整 DUT 清单）两次提交。继续复用三位既有代理，没有新建子智能体或用户任务。日常编译不调用 `migration_tools`；这些 Python 仅用于本轮参考导出、来源审计和结果收集。
- `noc_contract` 完成九种 NoC、动态 FIR、全局 ADD 和 r1w3 非对称存储；原读 3/写 1 的 RTLIR 失败另存证据。FIR 最终为 165 周期 × 3844 位、126 配置输入、五次跨 CGRA 物理传输、Tile0/3 非零状态保存/恢复及清空，结果 2215。全局 ADD 为 91 周期 × 1779 位、局部 10/26 归约为 36 后得到 53/31。r1w3 为 464 周期 × 669 位、24 写/25 读、83 个反压采样，均实际通过错误预期负控。
- `synth_tools` 完成六组件与两个集成系统的正测、负控和最终综合。DMA 集成为 86 周期，默认硬件语义保留两项已知错误 MVIN word；im2col 集成为 202 周期、16 次窗口像素写入/回读、45 个 CPU 门控周期。最终两个完整系统的 `synth -noabc/check -assert` 通过并保留原端口；generic 统计不当作标准单元面积。组件和系统各自 source SHA 复核未发生测后编辑。
- `area_report` 完成 94 项源码映射、49 个原 kernel 入口盘点、16 个旧模块配置与两个 LoopController 配置。49 是原测试入口清单，不是 49 项已迁移/重跑的宣称。最终正测 5227 个逐周期样本，四种配置编码 profile 共 473 项检查，18 项破坏 oracle 和 12 项越界配置负控通过。18 项结构检查中 15 项无问题；旧 DataMem/ScalableDataMem/RingMultiCtrlMem 分别保留与原 HDL 一样的 46/46/4 个未驱动位告警，不冒称这三项严格零告警综合通过。
- 主智能体新增 `tb_program_execute.sv` 与 `run_program.sh`，直接调用原生 SV CLI 构建此前参考中没有的程序：输入 11，依次加 9、乘 2、减 3，地址为 4/20。测试独立写出预期 37，运行 72 周期、26 配置包、4 个唯一完成、2 次回读及西侧多播，host/West 各经历六个反压采样。错误预期与永久反压两项负控均按指定错误非零退出。`synth_tools` 独立只读核对数学预期独立性、源 val/msg 保持和负控，未发现待处理 P1/P2。
- 64 Tile 的原 Python 仿真在成功导出原 HDL 后长期未结束首个场景。核对 PID 5900 及父进程命令确为本次 `phase4_multi_export.py --tiles 4` 后，仅停止这一仿真：已耗时 4178.015 秒，原 HDL/source manifest/exporter snapshot 不改，raw HDL SHA 为 `1ac181e58a771dcc6d77f04d1b5a17ffbe6615fb7549d23559d6054b71bcf32b`。`python-trace-status.json` 记录中止，不把部分 program0.hex 当完成轨迹。该配置保留原 HDL 的逐周期全 raw 输出比较、独立数学/事务检查和两项负控；其余三个同构 16 Tile 配置及异构系统继续三方比较。当前导出脚本增加显式 `--hdl-only`，历史快照不重写。
- 为减少仿真器主机编译开销，最终后续测试允许 `MAKEFLAGS='OPT_FAST=-O0 OPT_SLOW=-O0'`；这是生成 C++ 模型的编译优化选项，不改变 RTL 周期、硬件或 oracle。源文件和 frozen asset 使用 SHA 校验；阶段2/3公共默认 profile 回归也记录相同主机编译选项。
- 寄存器存储模式一次旧编译较慢，尝试停止已核实的本次 bash PID13912 被操作系统拒绝访问；这不是自动审批审查拒绝。随后 PowerShell 路径误重复为 sv/sv，且当时未启用 Stop-on-error，路径解析失败后仍启动第二次构建，短暂共用同一忽略目录。旧任务因 PCH 时间戳变化失败（mtime 1790040670→1790041634），未计作最终证据。源码/参考未受影响。新批离开该目录后交给 `synth_tools` 独占，保留重叠构建目录并在空目录重编；后续文件操作统一先用原生 PowerShell 解析并验证绝对路径边界，启用 `$ErrorActionPreference='Stop'`。
- 独立工程首次导出 884 个文件，目录内 Python 文件数为 0；该验证快照在最终报告编写前生成。主智能体从空构建目录执行 all、phase5、phase4-noc、phase4-migration 四组入口。快照范围和完成结果另记最终收尾；不把仅存在导出目录或旧构建日志当作独立验证通过。

## M17：独立复核与最终测试的证据绑定

- 冻结参照以 `792ea50` 提交，共 216 个参考资产逐项比较暂存 blob 与工作文件，字节完全一致。`reference/phase5` 中保留的原始 `__pickled.v` 是 manifest 指定的未改翻译产物，属于有来源的参考资产，不进入 DUT 文件列表；它们不是日常编译输出。历史 exporter snapshot 随各参照保存。
- `noc_contract` 独立完成来源审计：46 份 manifest 的 2966 条声明 SHA 全部匹配，unresolved/failures 均为 0；三次原导出失败及四份纯 Python trace 的 HDL 校验明确不适用。九个未声明 checksum 的附件单列，未计为校验通过。155 个原 Python 路径均与导出清单匹配，其中 115 个与基线 Git blob 原字节一致，40 个子模块文件仅因 Windows CRLF/LF 不同，逐项归一化一致且子模块 clean，保留两种原 SHA。两份 DMA pytrace 的刺激路径从历史调用/快照明确解析，并将实际刺激原字节新增归档，没有改写原 manifest。
- 五种完整系统的最终通用综合全部通过，源码输入 100 条 SHA 与当前一致：Mesh16、Ring16、寄存器存储 Mesh16、Mesh64、21Tile 异构。均保留八个主机端口，输入/输出总位宽分别为 197/195、199/197、197/195、201/199、223/221；最终 `check -assert` 为零。墙钟时间约 714.05、647.65、373.05、519.83、1697.75 秒，仅用于记录本机执行，不当作硬件性能指标。
- `synth_tools` 独占空目录完成寄存器存储配置，374 周期 ×195 位、32 完成、16 回读、40 远程请求和 20 响应；正测及两项负控全部通过。第一次外层 SHA 收尾因 bash 未继承内部 PATH 找不到 sha256sum，单独以绝对工具路径补校验；这不是 DUT 或差分失败。随后新的 hashed replay 完整退出成功，94 条显式源码 SHA、103 个 Verilator 输入和六个运行文件均校验通过，旧混合构建单独保留。详情见 clean-rebuild-result.json。
- `noc_contract` 对最终收集器进行只读审查，指出初稿缺少 `$readmemh` 运行文件哈希、外设 288 条源码/日志哈希的二级检查，以及 phase5 结构检查的 `completed` 状态须与 `passed` 区分。主智能体增加 `system/replay.sh`：检查已编译源码，记录实际 `.hex/.txt/results.json` 的运行前后 SHA，再跑正测和指定负控；64Tile 显式注明这些部分 Python 文件未被使用。收集器分别核验各 schema、配置数量、18项结构告警的 46/46/4 白名单；不更改旧 JSON 状态迎合统一判断。
- NoC 的负控范围修正为九种正测配置与 `mesh_2x2_l1_w32` 的错误包/永久反压两项负控，不声称九种各做两项负控。运行脚本要求指定失败标记和非零退出，随机崩溃不计为负控通过。异构样本已验证 101 个实际编译来源与五个运行文件；只读复查无剩余 P1/P2。
- `synth_tools` 核对 `filelists/native.f`：102 个唯一 DUT 文件、三条 include 目录，全部存在且位于 rtl，无 reference/tests/fixed DUT；实际声明数 116 不当作功能数。`area_report` 复核第五阶段报告数字与范围，补齐示例的 EDA 路径参数。三位代理均为原有代理复用，没有新建用户任务。

- 验证入口与迁移取证工具以 `eba17d8` 分批提交，168 项暂存 blob 与工作字节一致。公共旧系统回归在该次提交期间报告失败，失败 JSON 也如实以 failed 状态保存：阶段2四配置与阶段3 Base/Logic/Float/Vector 已过，Context 编译遇到手写测试 profile 缺少新增的五个位宽别名，不能用旧 run.log 代替本轮通过。
- `synth_tools` 独立核对默认单 CGRA ABI：四端口 DATA/CTRL/PAYLOAD/HOST/NOC/MEM 为 35/119/170/191/194/52 位，八端口为 35/143/194/215/218/52 位，41 个端口的总输入/输出仍为 702/685 和 750/733。新增别名没有改变默认字段布局。`area_report` 扫描全部测试，发现 35 份手写 profile（两完整 Tile 变体系统、StreamingMem 组件、两标量配置、30 向量/组合配置），仅补 ID/X/Y=1 与读写 crossbar source=2 的别名，不修改刺激、预期、参考或 DUT，并重跑受影响入口。既已通过且源未改的八系统结果保留，失败记录和修正前后 SHA 单独记录。

## M18：按用户要求将交付范围收至第四阶段

- 用户明确要求“完成第四阶段即可，等我指令再开始第五阶段”。收到后停止新增第五阶段工作，只完成第四阶段共享参数影响的旧阶段兼容回归，以及第四阶段 Git/报告收尾。此前根据“继续后面的迁移任务”已经执行的第五阶段探索保留，不删除历史，也不将其作为本次正式交付。
- 复用原三位代理，没有新建子智能体：`area_report` 完成必要的旧标量/向量/Tile 兼容回归；`synth_tools` 复核第四阶段证据和入口范围；`noc_contract` 审计阶段4/5文件依赖及来源。主智能体整理独立第四阶段分支与证据归档。
- 文件审计确认第四阶段 RTL 与测试不依赖第五阶段独立 LoopController、七个 legacy 文件和配置工具。完整 DUT 列表从 102 项精确排除八项后为 94 项；第三阶段已有 scalar_loop_control/counter FU 保留。共享多 CGRA/独立写口/外设 profile 扩展及 35 个旧测试平台的一行别名适配属于第四阶段，须保留。
- 为避免混合历史被当作第四阶段交付，将完整现场保存为 `codex/sv-phase5-draft`，从第三阶段完成点 `1a5585a` 创建 `codex/sv-migration-phase4`，只导入第四阶段实现/证据。Makefile、run.ps1 和 native.f 删除第五阶段入口；旧阶段与第四阶段命令不变。原 `codex/sv-migration` 历史、原工作树和 master 不重写。
- 兼容性回归首次修复后，w32 已实际通过，但采集器将本地 DateTime 与 UTC 文件时间比较，误报 STALE_RUN_LOG。将比较双方显式转换为 UTC 后复用该次真实成功结果，继续 w64、30 个向量/组合与 Tile 组件。原始失败及恢复记录保存，不以旧 run.log 冒充本轮通过。
- 分支拆分只改变交付文件范围与入口；已测 DUT、刺激、参考字节不变。原始宽范围采集报告保留在草稿分支并原字节复制到第四阶段 compatibility 历史记录，另派生限定索引，明确列出未使用的第五阶段文件和入口移除，不改写历史哈希或假称重新仿真。
- 第五阶段完整现场已保存为 `codex/sv-phase5-draft@b31dea343eefd41fcb01b9286a0e121067ce024d`。第四阶段原生实现提交为 `c56d0c6`；32 项暂存文件逐一与实测工作字节比较一致。原 `codex/sv-migration` 保持在 `eba17d8`，没有重写已有提交。
- 最终兼容回归实际通过 10 个完整系统与 34 个组件配置：阶段2四个参数点；阶段3 Base/Logic/Float/Vector/Context/Streaming；两标量 2881/3105 周期；30 个向量/组合各 640 周期；Context/StreamingMem 组件 360/358 周期。相关错误预期和超时负控通过。原始当前源码快照共 181 项；不将这些计数解释为全部原 kernel 已移植。
- 第四阶段兼容索引复核 170 个保留源码、195 项实际日志、47 份编译输入元数据；11 项范围变化明确为八个未实例化的第五阶段 RTL，以及三个只移除第五阶段声明的入口文件。五份原始兼容报告原字节保留，源 sha 与 `b31dea3` 一致。完整编译记录确认没有实例化被排除的第五阶段模块。
- 第四阶段验证提交为 `2fafbb9`，258 项参考/测试/取证文件的暂存 blob 与工作字节逐一一致。阶段4来源限定复核覆盖 28 份 manifest、2827 项声明 SHA，全部匹配；147 项原 Python 路径中 107 项与 Git 原字节一致，40 项仅换行差异，均单独登记。7 项不适用字段和9个未声明 checksum 的附件不算作通过项。
- `area_report` 独立复核 compatibility 派生索引：10系统、34组件、170源码、195日志/产物、47编译元数据及5份历史报告全部匹配，11项范围排除理由成立，无剩余 P1/P2。`synth_tools` 检查94 DUT/3 include、100个保留HDL/头文件、41个runner；阶段1–4 Make dry-run的9333字节命令输出与草稿完全相同，27个Shell与14个PowerShell入口语法通过，736条RTL SHA断言一致。上述都是只读核验，不重复宣称新硬件仿真。
- 第四阶段汇总 `results/phase4-summary.json` 实际校验 2275 条当前源码、运行文件及日志哈希。五系统共2254个逐周期样本、449354个原始输出位比较通过；五项完整系统通用综合最终 `check -assert` 为0。组件完整综合和前端检查分开记录；未测标准单元面积/Fmax，64Tile未完成的Python轨迹仍明确排除。
- 第四阶段证据 ZIP 为 `results/phase4-evidence.zip`，共674条目、9,721,698字节，SHA256 `971a7a022b3b84e1200c9f0e14eb121dbd7412fed3d0e201679904d2dc7a1699`。生成器逐条读回核验，并归档兼容回归日志、实际编译输入记录、已保留的失败、Git暂存字节证明及范围审计。原始阶段1–3结果和旧证据ZIP没有覆盖。
- 最终Git检查发现原工作树在2026-09-22 10:06:33已有从NoC优化分支到master的checkout记录，早于本次交付范围切分；如实记录原工作树当前为master@41cb0c0且tracked clean。master提交未变化，NoC优化分支仍为e3caf69，本轮仅操作迁移工作树的新分支，没有推送、合并或改写已有分支。
- 第四阶段完成后停止。第五阶段的已有探索与未交付报告仅保留在 `codex/sv-phase5-draft@b31dea3`；等待用户再次指令后才继续。
- 最后由 `noc_contract` 独立逐条读取ZIP验收：674项长度与SHA全部匹配，195份兼容日志/产物与47份编译记录无遗漏，2275条当前来源校验可独立重算；107个汇总源码SHA和组件报告指纹均匹配，没有第五阶段运行代码/入口混入，无剩余P1/P2。

## M19：迁移进度与代码规模整理（2026-09-22）

- 用户要求整理当前进度、文件数、行数及实现功能。本轮只新增成果文档和统计索引，不继续第五阶段，不改 RTL，不运行新的硬件测试。
- 固定统计第四阶段交付提交 `c3184dc`，所有计数文件先与 Git blob 字节核对。`native.f` 的94个直接输入为16,624物理行，递归实际include的7个头文件为410行，合计101个现用HDL、17,034行。其中直接维护SV及头文件90个、15,563行，复用HardFloat 11个、1,471行。包含空行/注释，不将其称为全部独立自研代码。
- `sv/tests` HDL共77个、16,249行；Shell/PowerShell及Makefile脚本42个、1,821行；文件列表8个、343行。`migration_tools` 的68个Python工具、8,240行单列为迁移取证辅助，不冒称日常构建已经删除所有Python。
- 该快照sv目录共937个Git跟踪文件，包含409个reference资产和66个vectors资产；3个历史/参考专用RTL文件共17,029行没有计入现用实现。快照总数不包含本轮新增的汇总文档与统计JSON。
- 复用原子智能体 `area_report` 独立读取Git原始blob，现用HDL、include头文件及测试源码数量/行数完全一致；没有创建新子智能体。特别纳入HardFloat的RISCV子目录头文件，未将只作参照的原MAC vendor源码重复计入DUT。
- 新增 `MIGRATION_PROGRESS.md` 与 `results/migration-progress-stats.json`，按模块列出规模和功能，区分已完成的前四阶段、暂停的第五阶段，以及有限验证、基线已知问题和没有新的PPA测量等边界；README增加入口。

## M20：阶段1–4架构示意图（2026-09-22）

- 用户要求按参考图片制作当前迁移功能的结构示意图。本轮使用 fireworks-tech-graph 技能，采用浅色模块、系统→单CGRA→Tile三级展开，生成可编辑SVG与3600×2055 PNG；只修改图像、绘图脚本和文档，不修改RTL，不继续第五阶段。
- 继续复用原子智能体 `noc_contract`（Bernoulli），没有创建新子智能体或用户任务。代理逐项只读复核多CGRA主机入口、报文NoC/物理边界直连、4×4的七个直达访存口、双Crossbar、LinkOr、常量队列、原有输入FIFO及单CGRA可选外设边界。
- 主智能体基于 `ab26148` 的源码绘图。图示同构64 Tiles及异构21 Tiles验证实例；中心4×4是结构示例，并非固定唯一尺寸。右侧以Base Tile为例，注明Streaming没有Reg→Routing回读；底部DMA/im2col单列为独立可选集成入口。图不表示物理布局或完整网表。
- 代理指出初稿将DMA直接连SPM会掩盖Controller转发。已修正为DRAM↔DMA↔Controller↔SPM，另从Controller连接im2col，明确配置与写回路径。自动字体测量发现局部标签过宽，缩短标签并适当减小字号，没有缩放挤压整个图。
- 初次通过Playwright/Edge直接截取SVG在字体加载后超时；改用本机Sharp/librsvg导出成功。字体缓存目录不可写只产生工具告警，最终PNG中文显示已目视确认；没有安装额外依赖或终止用户浏览器。
- 最终SVG的XML、marker、碰撞、几何、排版五类检查均通过；55项节点文本宽度检查通过，最终PNG目视检查通过（visual_review: passed）。`manifest.json` 固定十项RTL来源SHA与两项图像SHA，`validation.json`保留检查结果。绘图Python仅用于文档资产，不进入日常HDL构建。
- `sv/README.md` 增加图像入口。本轮没有运行新的硬件仿真或综合，图像审查不计入迁移测试覆盖。
- Git落盘复核发现文本会按仓库规则归一化LF；绘图脚本已显式输出UTF-8/LF，更新SVG SHA并再次通过五类检查，确保检出后的SVG与清单一致。PNG字节未变化。

## M21：当前 Python 同步与单 PE 验收（2026-10-09）

- 用户授权继续迁移；由主智能体执行，未创建子智能体。起始 HEAD 为 `cd7aad878915e389cecf8cc01ff6987d156bd019`，工作分支 `work`。当前 Python 内容来自父提交 `e3caf6928a4e8c97e6be36574af2520ec92083b9`，原迁移基线 `ac96a7af` 继续保留；274 个原项目 Python 文件的 SHA 固定在 `reference/current/target.json`，本批未改原文件及历史参考。
- 新增 `cgra_pe` 统一 Base/Context/Streaming；阵列入口复用单 PE；opcode 集中管理。同步 Grant/LLS_CONST/GEP/STR、常量退役、寄存器槽背压与 Crossbar prologue；修复 VectorMul 翻译位移截断及 DMA beat 拆装。DMA 默认改为 Python 正确切片，原翻译缺陷只能显式选择；独立 32/96/128/256 位 DRAM 及 128/256 位集成测试通过。
- 未修改 Python 即复现 Streaming 标量控制步同周期完成丢失造成的死锁；反例保存在 `reference/current/streaming_defect.json`。SV 修正同周期完成记录，另用 Streaming Load 验证多次输出没有被提前截断。原 SUB_CONST/FP 共有问题仍登记为待修复，未更换参考掩盖差异。
- 本地执行入口：`make -C sv current`、`make -C sv current-synth`、`make -C sv current-kernels`、`make -C sv current-prefixes`、`bash sv/scripts/run_baseline.sh all`。工具：Verilator 5.029 devel v5.028-104-ge2041f745、sv2v 0.0.13、Yosys 0.45+139 4d581a97d、G++ Debian 14.2.0-19；使用显式工具环境变量。具体 marker、工具和输入目标保存在 `reference/current/validation.json`，日志位于 `build/current/`。
- 当前组件验收：8 FU × 539 周期全部输出位比较、控制步状态和多播背压、五组 PE 参数、流式加载、四种 DMA 宽度和两种集成宽度；故意错误 oracle 和非法 PE 参数负控通过。默认单 PE 通过 sv2v、Yosys synth/check，不声称 PPA 改善。历史 all 在归档的原始 RTL 上通过，未用旧错误切片和旧 opcode 约束当前实现。
- 原 YAML 程序完整对照：AXPY 290、FIR4x4 350、Histogram 240、ReLU4x4 345、SAD 190 周期，原 Sink 断言继续生效。GEMM/GEMV 的原 Python 在 30 分钟内尚未完成，停止后保留 2258/2689 周期；这些前缀与 SV 全部顶层输出逐位匹配，不能算完整程序通过。SPMV 配置生成在 `ICMP_ULT` 映射处失败，早于 RTL 仿真。配置包、失败信息、逐周期文件和 manifest 均保存。
- 一次运行中的 shell runner 被编辑，导致该次读取偏移出错；固定脚本后完整重新运行通过，失败运行不作为证据。当前参考生成器增加墙钟限制和进度输出；不完整记录与完整 kernel 的验证入口及结果标记分开。
- Linux/MSYS 工具路径统一；新增 CI 工作流尚未在远端运行。本批的后续事项包含完整多 CGRA 当前语义验收、旧独立 API 补齐和剩余原模型缺陷，详见 `CURRENT_MIGRATION.md`；未宣称全项目迁移完成。

## M22：结构修复、数学回读与当前系统重新验收（2026-10-09）

- 继续用户授权流程，未创建子智能体，未提交或推送。274 个原项目 Python 文件的 SHA-256 未变，99 个原 opcode 定义保持一致；历史跟踪的 reference/vectors 未改。
- 将默认 PE 综合中的 497 个未驱动位定位到窄有符号循环边界和未使用接口。删除 CtrlMem/Crossbar 的 19 个边界转换，显式驱动空闲 raw-packet/存储接口。优化前及综合后都运行 `check -assert`；五组 Base/Context/Streaming 参数的真实综合网表完成公共接口程序，均通过。
- GEMM/GEMV 的原配置延长到 12,000 周期仍停顿。独立配置修复保留再次读取前仍活跃的寄存器 token，并将冲突目标重分配到空闲 bank。GEMM 另外补 stride=4 配置和 Controller 的命令 43 转发。GEMV 405 周期、4 个输出；GEMM 1657 周期、16 个输出，全部数学回读正确，错误期望与永久背压负向检查有效。这不是原 Python 程序的等价完成。
- 实现原生 ULT/ULT_CONST（102/103）和现有编码的常量 AND/OR（100/101），32/64 位独立数值/握手检查通过。原 SPMV YAML 在 opcode/liveness 修复后可返回，但地址 2 的首个错误为 2 而非 6；额外运行 2000 周期后仍有五个错误输出。三输入 PHI、共享数组基址及其控制/数据依赖尚未完成修复。隔离实验修改 PHI 首次握手状态没有改善该结果，因此未合入这一实验 RTL。
- 新增独立 COO 程序，使用不重叠数组、重复行、负权重及串行读改写依赖；206 周期回读 481、2、123、274，错误结果与永久背压检查通过。原 4×4 YAML 仍单列失败，未以这个独立程序替代原测试的状态。
- 当前五个完整 YAML 轨迹重新逐位通过，GEMM/GEMV 的两个原始前缀仍按 incomplete 验证。当前 Python 的 global_add 91 周期 × 1779 位、dynamic_fir 165 周期 × 3844 位均与 SV 逐位匹配，结果分别 53/31、2215；动态用例覆盖 5 次物理边界传输和 2 次恢复。
- 当前 RTL 的 Mesh、Ring、注册存储、64 Tile 和 21 Tile 异构数学/协议验收通过，均验证错误结果与永久背压失败。上述独立验收不声称新的完整 Python 等价。
- SUB_CONST 默认改为消耗 const.ready，不再错误地驱动无关第二输入 ready；旧缺陷仅在冻结 FU 轨迹中通过显式叶参数复核。浮点默认采用 IEEE 字段/HardFloat 位宽映射，FINC 加 1.0，常量操作检查有效性及谓词。FP16/32/64 独立算术及负向测试通过；`FP_LEGACY_PYTHON=1` 的四组旧格式各 1170 个样本与冻结 HDL 匹配。
- Verilator 5.029 对文件循环计数器有错误常量折叠，最小反例已保存。`-O0` 可修复最小反例，但在完整设计触发另一处生成 C++ 错误，因此未作为最终方案。仅将测试台计数器/覆盖位声明为 `public_flat_rw` 后，保留 RTL 优化、全部比较及覆盖检查，正负向用例均通过。
- 完成旧独立模块接口盘点，未将 LoopController、静态 CtrlMem/ConstQueue、DataMem 系列、RingMultiCtrlMem、OrLink/Selector/PipeQueue 等未验收 API 标为完成。结果、明确边界和入口见 CURRENT_MIGRATION.md；`reference/current/validation.json` 固定 36 个正向配置的结果及源码/测试 SHA，原 SPMV 失败证据位于 `reference/native/kernels/spmv/`。
- Make/PowerShell/CI 加入新验收入口；远端 CI 尚未运行。没有新的 PPA 或全项目迁移完成声明。

## M23：原 4×4 SPMV 控制依赖收尾（2026-10-10）

- 用户授权开始上一轮尚未执行的 SPMV 修复。保留原 Python/YAML 和 M22 失败证据；未创建子智能体、提交或推送。
- 重现原候选的五个错误回读。定位 M22 工具把 tile 9 的寄存器从 `$0` 移到 `$24` 时，没有把路由 prologue 的物理输入 5 改成 8；修正后地址 2 恢复，仍缺少后半组结果。
- 原 YAML 的“余数为零”路径没有等待主循环退出。对编译期正的四倍数 nnz，将已有退出 token 经 tile 4 `$24` 接到 slot 7 的返回条件。继续执行后暴露旧 PHI_START 强制真谓词会启动本应关闭的尾循环。
- 保留旧 opcode 行为，新增原生 PHI_START_PRED=105 与 PHI_N=104，分别保留初始入口谓词和支持配置的多输入合并。首次状态及原生 vector factor 只在实际接受时推进；三输入返回合并不再漏掉第三条分支。
- 加入“返回前实际存储次数/地址必须匹配”的检查，发现 nnz=1/4/5 的返回可以早于存储，原先只读结果甚至会漏掉 nnz=1 的零值缺写。通过既有路由通道传递 STORE 后的控制 token，并在 Ret 的输入交叉开关合并两条完成链。无新增存储/返回 opcode。
- 返回移到 tile 4 slot 14，位于原循环退出输入之后，避免把退出 token 当作存储确认消费。GEP 移至 slot 11，地址临时寄存器为 `$25`。保持 4×4 映射和 II=15。
- 原始 nnz=8 的前八字为 0/2/6/12/20/30/42/56，全部 32 字回读正确，普通/主机背压及配置间隔模式为 964/3086 周期。nnz=0…8 共 18 组运行，检查唯一写入地址、写次数、返回前存储握手和返回后不得继续写入。
- 五组故障注入分别检出错误 prologue、旧启动 PHI、缺失第三 PHI 输入、移除循环退出依赖、丢失存储确认。错误 oracle 和永久背压检查仍保留。M22 的旧失败文件归档到 `reference/native/kernels/spmv/failure_m22/`。
- 新 PHI 的 32/64 位 RTL 及实际综合网表各通过 395 项检查，覆盖缺失操作数、谓词优先级、长期背压、独立控制槽、clear、vector factor，以及旧 PHI/PHI_START 语义；错误期望必须失败。sv2v 将数组端口展平，测试台通过显式拼接连接综合网表。
- `native-kernels` 默认纳入修复后的原 4×4 SPMV，并自动运行长度/故障矩阵；`native-math` 纳入 PHI 单元，`current-post-synth` 纳入 PHI 网表。构建不依赖项目 Python；`native_kernels.py spmv --spmv-matrix` 仅用于重新生成冻结配置。
- 本批完整检查清单、代码/测试及日志 SHA 见 `reference/current/validation.json`；M22 元数据另存 `validation_m22.json`。原项目 274 个 Python 文件和 99 个原 opcode 定义保持不变。
- 收尾回归全部通过：当前组件、五组 PE 综合网表、五个完整 Python 内核轨迹、原生 GEMM/GEMV/SPMV/COO、原生算术和四组旧浮点格式。配置重新生成得到的 70 个文件逐字节一致；当前证据记录包含 42 条正向日志记录。M22 原 SPMV 归档在当前兼容 RTL 上仍复现地址 2 得到 2 而不是 6。
- 完成的是原生修复配置在局部 32 字、恒等行列索引、nnz=0…8 的验收。原 Python 配置仍因 ICMP_ULT 映射缺失失败；任意地址别名、更多长度、重复行并行读改写和旧独立 API 等仍不在本批完成声明中。

## M24：独立 LoopController API（2026-10-10）

- 从已提交并推送的 `620122e7aebb6bd5b9bee89b6f129d05d613f105` 继续；本批不修改原项目 Python 和历史参考，没有创建子智能体。范围为旧独立 API 清单中的第一项，不是全部遗留模块或系统调度集成。
- 移植五个 payload val/rdy 端口、多 CCU、配置/启动、阈值计数、直接父通知、子重启、最低索引派发与本地/远程 reset/shadow 消息。CTRL_BITS 默认 107 对应原测试，119 位当前 PE 格式另有参数点。
- 源码检查并在未修改 Python 中复现：目标数填满 4／8 个槽时，窄索引加一先回绕为零，无法结束派发。原生模式以 4 位后继值判断完成后再缩窄，显式 LEGACY_DISPATCH_WRAP 参数保留旧行为。
- 原 Python 四个测试继续执行 Source/Sink 断言；补充混合事件、并发、背压、relaunch 和边界轨迹。四组共 2080 个采样周期（12 个场景 reset 不比较），2068 个周期全部接口输出逐位匹配；12 个参考文件在独立目录重新生成后完全一致。
- 原生四组分别通过 279／254／81／379 项独立检查；派发次数分别 16／14／3／24。覆盖满目标、非二次幂、单 CCU、64 位高位 shadow、父子层次、两个 root 仲裁、屏障、背压、终止和 reset。
- 四参数点 × 原生/兼容模式的 8 份实际综合网表均重跑同一台架，通过优化前后 check -assert。16 次错误期望、4 次旧回绕注入、6 次非法配置运行均检出预期错误；非法配置检查为仿真断言，不声称综合网表提供硬件错误响应。
- 新模块未接入系统，也没有增加 NoC 路由头。保留并记录 Python 的广播/匹配规则、同拍计数覆盖、未配置子 CCU 重启、非递归父通知、未锁定派发仲裁与 all_loops_complete 只观察 root 等边界，不将这些行为称作任意 DAG 调度正确性。
- 新 Make/PowerShell/CI 和完整 regression 入口已接入；native 文件列表对已有 PE 测试台的 lint/elaboration 通过。没有重跑 M23 全系统或 PPA 验收；M23 记录保留，本批证据在 reference/current/loop_controller/validation.json。
- 原项目 274 个 Python SHA 未变。验收记录生成时尚未提交或推送，也没有本批远端 CI 结果；实际提交与推送状态以 Git 为准。下一项：旧静态 CtrlMem/ConstQueue 接口与其 Python 缺陷边界。

## M25：独立静态 CtrlMem / ConstQueue API（2026-10-10）

- 从已提交并推送的 `008c2ecf5970c6b0ad0d1a3284e10a3f0707bbab` 继续；未创建子智能体，未修改原项目 Python 或历史参考。实现两个独立 API，没有替换 PE 内动态存储。
- 原 CtrlMem 使用 `.ctrl`，直接配当前 `.operation` 类型会失败；冻结工具仅创建同位布局的旧字段名类型。复现 total_steps=0、单槽控制存储、空常量表的 Bits0 失败，以及缺省常量列表的 TypeError。检查自定义 PyMTL 的 zext 后确认 depth=8／period=2 可执行，未把初步疑点误记为缺陷。
- 原静态 ConstQueue 测试原样运行并保留 Source/Sink 断言，结果通过；两个废弃 CtrlMem 测试依赖旧接口，没有宣称其通过。7 组直接模型轨迹共 1305 周期，包含 84 个 reset 周期；RTL 和网表均比较全部 104102 个输出位，无 valid 或 reset 掩码。
- 原生 CtrlMem 同步复位程序、PC 和预算；仅实际握手推进；配置写入成对接受，保护背压中的当前字，同时允许其它槽写入及消费当拍替换。覆盖深度 1／3／4／8、有限和无限预算、107／119 位消息及自定义 opcode 位置。
- 原生 ConstQueue 提供静态 ROM、按握手循环读取和复位回到首项；支持空表、单项、3／4 项以及 16／32／64 位 payload，所有 metadata 位一同验证。兼容模式以 initial 零初始化模拟 PyMTL 初始状态并忽略运行中 reset，不代表 ASIC 上电保证。
- RTL 与真实 sv2v→Yosys 网表的 18 个配置分别通过；每种实现有 2635 项原生检查。18 份网表均通过优化前／综合后 check -assert。36 个错误期望、8 个旧行为缺陷、5 个非法地址／参数负向运行通过；相同缺陷输入在原生模式有 8 次通过记录。Verilator 计数器继续使用已记录的 public_flat_rw workaround，不移除比较或覆盖检查。
- 收尾审查发现 Verilator 对生成网表的不同位别名／拼接报 UNOPTFLAT；没有将功能通过写成零告警。逐份重新读入 18 份实际网表并运行 check -assert、scc -expect 0，均为零问题、零位级组合环；检查已接入综合网表 runner，证据保留每份日志及告警计数。
- 23 个冻结文件在独立目录重新生成后逐字节一致，274 个原项目 Python SHA 未变。新增 Make、PowerShell、regression 与 CI 仿真入口；native 文件列表对既有 PE 测试台 lint/elaboration 通过。Shell 语法与 Make 入口检查通过；PowerShell 未在本 Linux 环境执行。
- 验收摘要、源码／参考／网表与日志 SHA 独立保存为 `reference/current/static_memory/validation.json`；M23／M24 证据保持不变。本批未重跑系统内核，不声明新系统集成、PPA 或全迁移完成。验收时未提交／推送，也无本批远端 CI 结果；下一项为 RingMultiCtrlMem 独立接口。

## M26：独立 RingMultiCtrlMem 动态控制环（2026-10-10）

- 从已提交并推送的 `6ea3eb9948948b12cd2f33abfbffd13248caa95f` 继续；未创建子智能体，未修改原项目 Python 或旧参考。新增独立顶层、控制字适配层及专用类型，复用已有控制存储状态机，没有增加 PE／阵列集成。
- 未修改 Python 即复现 dummy FU 输入持续 valid=1 导致 cmd=0 返回优先、COMPLETE 饥饿，以及返回 VC 仲裁在背压时切换的问题。原测试原样运行通过；取证版本仅改 runner 采样，保留原 Source/Sink 断言。原生关闭虚假输入、增加单项返回队列；显式兼容模式保留原行为。
- 原测试加四组扩展轨迹共 1816 周期／744012 个输出位，每种实现全部逐位对照，包括 27 个 reset 周期及无效消息。15 个冻结文件再生成后逐字节一致；274 个原 Python SHA 未变。四组原生每种实现共 4470 项检查，覆盖完整字段、窗口、prologue、有限／无限执行、COMPLETE、终止恢复、START、复位与 credit／VC 背压。
- 初次完整环综合发现 sv2v 动态数组写入与读取生成大量宽选择逻辑；停止耗时的平坦化试验，层次化试验在展开时被系统终止（exit 137），这些运行不计入通过证据。将共享 ring route 和 switch 改为静态逐端口连接／选择后重新验收，保留所有仲裁、无效消息及原参考。
- 四参数点 × 原生／兼容模式的 RTL 与 8 份真实综合网表全部通过；完整 synth、优化前后 check 及实际网表重读后的 check／零 SCC 均通过。18 个错误期望、8 个旧 dummy 缺陷、3 个非法地址／目的／参数负控均检出预期错误。编译告警计数保留；CXXFLAGS=-O0 仅加速部分生成 C++ 的编译，Verilator RTL 优化和全部比较仍启用。
- 共享 NoC 500 周期、7／17 节点环各 800 周期重新逐位匹配旧 HDL，包括 invalid 消息；361／786／800 包分别全部收发守恒。native 文件列表对既有 PE 台架 lint/elaboration 通过。未重跑系统内核，不声称新的系统级验收或 PPA。
- 明确参数范围：FU 输入 1…4、输出固定 2、Tile 输入／输出各 1…8；实际验收四组参数，不声称覆盖任意 Python 类型。动态存储 reset 保留程序，运行中配置没有隔离；Context／Streaming 和其它 FU sideband 未暴露。返回队列最低增加一拍、峰值每两拍一条。
- Make、PowerShell、regression 和 CI 仿真入口已加入；shell 语法和 Make 入口检查通过，PowerShell 未在 Linux 执行。证据独立存入 `reference/current/ring_ctrl_memory/validation.json`，旧批次记录保留。验收记录生成时尚未提交／推送，也没有本批远端 CI 结果；实际 Git 状态为准。下一项是独立 DataMem／DataMemScalable API。

## 独立 DataMem API（2026-10-10）

新增 `cgra_data_mem`，支持参数化读写口、完整消息位宽及预加载映像。
默认原生模式成对接收写地址／数据，按写口编号处理同址冲突；读端背压时保存
读前写后边界上的完整结果，不阻塞写口；同步复位恢复预加载或零映像。
兼容模式保留原 Python 的无效读触发预加载写、写使能锁存、假写握手和忽略复位，
原 Python 274 个文件不变。接口与限制见 [DATA_MEMORY_API.md](DATA_MEMORY_API.md)。

- 原测试 Source/Sink 断言及两组扩展轨迹共 509 周期、64531 个输出位，
  包含 23 个 reset 周期；RTL 和实际综合网表均逐位匹配，10 个冻结文件再生成一致。
- 4 组原生参数、3 组兼容参数均通过 RTL 与网表；每种实现有 12810 项原生检查。
  14 个错误期望、8 个旧缺陷复现、3 个非法参数／地址负控均检出预期错误，
  同输入的原生缺陷检查均通过。
- 7 份网表均通过完整综合、优化前后 check，以及实际网表重读后的 check 和零 SCC；
  Verilator 网表位别名告警保留。首次网表编译的数组展平连接问题已在台架修复。
- Make、PowerShell、regression、CI 仿真入口及当前 native 文件列表已接入；
  既有 PE 台架 lint/elaboration 通过。PowerShell 与远端 CI 尚无本批运行结果。
- 未替换 PE／阵列已有存储控制器，未重跑系统内核或 PPA。
  独立证据为 `reference/current/data_memory/validation.json`。
  按 [MIGRATION_TASKS.md](MIGRATION_TASKS.md) 顺序，下一项为 DataMemScalable API。

验收记录在提交前生成；提交和推送状态以 Git 为准。

## 独立 DataMemScalable API（2026-10-10）

新增 `cgra_data_mem_scalable`，复用已验收的独立 DataMem 核心；
原生／兼容本地契约相同。未修改的 Python 将 NoC 输出固定为零，
因此新包装层同样不接收 NoC 数据、不产生远程请求；本批没有新增远程访存。
接口与限制见 [DATA_MEMORY_API.md](DATA_MEMORY_API.md)。

- 单独执行 Scalable 原测试和扩展轨迹，509 周期／91092 输出位（23 个 reset 周期）
  在 RTL 与实际综合网表全部匹配；10 个冻结文件再生成一致，274 个原 Python SHA 未变。
- 4 个原生／3 个兼容参数点各通过 RTL 和网表；每种实现 14279 项独立检查，
  包括 NoC 输入持续变化下的零输出和本地存储正确性。23 次负控检出预期错误。
- 7 份真实网表全部通过完整综合、优化前后 check、网表重读 check／零 SCC。
  共享台架和 runner 扩展后，普通 DataMem 的多口及单词配置在 RTL／网表重跑通过。
- Make、PowerShell、regression、CI 仿真和 native 文件列表已接入；既有 PE 台架
  lint/elaboration 通过。没有新的系统内核、远程访问、PPA 或远端 CI 验收结论。
- 独立证据 `reference/current/data_memory_scalable/validation.json`；
  下一项按 [MIGRATION_TASKS.md](MIGRATION_TASKS.md) 补齐 N 输入 OrLink。

提交前记录；实际提交／推送状态以 Git 为准。

## 独立 N 输入 OrLink API（2026-10-10）

新增 `cgra_or_link`，保留原 N 输入 OR 语义：valid 求 OR，所有输入的 payload／predicate
均参与 OR（包含无效输入），无有效输入时输出消息为零，bypass／delay 始终为零，
ready 广播。未替换已有双来源 `tile_link_or`，详细契约见 [LINK_APIS.md](LINK_APIS.md)。

- 原 Python Source/Sink 测试原样通过；3／5／8 输入、16／32／64 位 payload 的
  960 周期、44800 个输出位在 RTL／网表全部匹配，包含 21 个 reset 周期。
- 四组原生配置（含 1 位／单输入）穷举所有 valid 掩码、ready 与 reset 组合，
  每种实现 12516 项独立检查；15 次错误期望／非法宽度负控检出预期错误。
- 4 份实际网表完整综合、优化前后 check、实际网表重读 check／零 SCC 全通过；
  8 个参考文件再生成一致，274 个原 Python SHA 未变。接口提供单输入退化情况，
  原 Python 的未使用 Bits0 声明在该参数下失败，已明确登记。
- Make、PowerShell、regression、CI 与 native 文件列表接入；既有 PE 台架 lint 通过。
  组合链接不缓存独立流，不承诺输入字段变化下的背压保持；未新增系统或 PPA 验收。
- 独立证据 `reference/current/or_link/validation.json`；下一项是 Selector 的未选口 ready 修正。

## 独立 Selector API 与未选口 ready 修正（2026-10-10）

新增 `cgra_selector`，原生模式只有当前选择口可收到输出 ready，其余明确为零；
保留完整选中消息（包括无效字段）。兼容模式显式保留原 Python 的未选 ready 锁存。
它是组合路由，选择信号须由上游保持到握手完成；契约见 [LINK_APIS.md](LINK_APIS.md)。

- 原固定选择 Source/Sink 测试原样通过；动态切换选择轨迹直接复现残留 ready。
  19／35／67 位、3／5／8 输入共 960 周期／44800 输出位，含 21 个 reset 周期，
  在 RTL 和实际网表逐位匹配；8 个参考文件再生成一致，274 个原 Python SHA 未变。
- 原生增加 8 位／单输入，四组配置穷举选择口、valid 掩码、ready 和 reset，
  每种实现 86908 项检查；残留 ready 用例在原生通过、兼容失败。
  18 次错误期望、旧缺陷、非法选择／参数负控均检出预期错误。
- 7 份实际网表全部完成综合、优化前后 check、实际网表重读 check／零 SCC。
  默认分支无 ready 锁存，兼容分支的锁存器是原始缺陷取证的一部分。
- Make、PowerShell、regression、CI 和 native 文件列表接入；既有 PE lint 通过。
  无新系统或 PPA 验收；证据为 `reference/current/selector/validation.json`。
  下一项：PipeQueue 满队列同周期出入替换语义。
