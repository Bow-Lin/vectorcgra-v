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
