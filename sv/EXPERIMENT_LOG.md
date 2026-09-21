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
