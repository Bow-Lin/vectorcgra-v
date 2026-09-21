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

## M02：原生工具链和自检测试集成（进行中）

- `synth_tools` 发现本机 UCRT G++ 16.1 编译后链接缺少 std::string 移动构造符号；static-libstdc++ 未解决。Icarus 对初始小样的命名 assignment pattern 也未通过。没有安装或改写工具。
- 改用现有 UCRT Verilator 5.050 与匹配的 clang64 Clang++ 22.1.8。构建参数消除不存在的 `-latomic`，链接命令通过 `env -u LINK` 避免 Windows LINK 环境变量被 lld 解释为参数。SV 类型/数组/参数/寄存握手与反压小样运行至 70ns，通过；sv2v → Yosys 综合检查也通过。完整 CGRA 尚待集成验证。
- `noc_contract` 编写独立 SV 配置构造和 TB：完整包/结果检查、两轮复位配置、四条内部链路、489 位活动输出与冻结 HDL 逐周期对照，以及故意错误和永久反压超时控制。对比不按 val 屏蔽其他活动消息。
- 参考资产代理完成后继续承担独立只读审查，检查测试判据、重播覆盖、打包样本及日常工具入口；主智能体负责集成结果复核与文档收尾。
