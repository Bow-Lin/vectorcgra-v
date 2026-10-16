# 核心 RTL 与历史验证代码的目录边界

`sv/rtl/` 只存放当前维护的功能实现、独立硬件 API，以及这些实现需要的公共定义和第三方 HDL。历史顶层、固定配置类型包和冻结 golden RTL 已移出该目录。

## 当前入口

| 路径 | 职责 |
|---|---|
| `rtl/tile/cgra_pe.sv` | 参数化单 PE，选择 Base、Context 或 Streaming 变体 |
| `rtl/cgra/cgra_system.sv` | 参数化单 CGRA 系统 |
| `rtl/cgra/cgra_multi.sv` | 同构多 CGRA |
| `rtl/cgra/cgra_multi_template.sv` | 静态异构多 CGRA |
| `rtl/peripheral/` | DMA、im2col 及其系统集成 |

LoopController、静态存储、Scalable DataMem 和独立 NoC/队列 API 仍属于功能实现，即使尚未接入上述系统入口，也保留在 `rtl/`。HardFloat 是浮点 FU 的实际依赖，继续位于 `rtl/vendor/hardfloat/`。

## 已迁出的文件

下面路径均相对于 `sv/`。九份 HDL 及一份第三方说明按字节原样移动，未修改模块名、端口、参数或行为。

| 原路径 | 当前位置 |
|---|---|
| `rtl/cgra/cgra_2x2.sv` | [tests/legacy/rtl/cgra/cgra_2x2.sv](tests/legacy/rtl/cgra/cgra_2x2.sv) |
| `rtl/cgra/cgra_scalar.sv` | [tests/legacy/rtl/cgra/cgra_scalar.sv](tests/legacy/rtl/cgra/cgra_scalar.sv) |
| `rtl/cgra/cgra_programmable.sv` | [tests/legacy/rtl/cgra/cgra_programmable.sv](tests/legacy/rtl/cgra/cgra_programmable.sv) |
| `rtl/tile/tile_core.sv` | [tests/legacy/rtl/tile/tile_core.sv](tests/legacy/rtl/tile/tile_core.sv) |
| `rtl/fu/tile_flexible_fu.sv` | [tests/legacy/rtl/fu/tile_flexible_fu.sv](tests/legacy/rtl/fu/tile_flexible_fu.sv) |
| `rtl/common/cgra_types_pkg.sv` | [tests/legacy/rtl/common/cgra_types_pkg.sv](tests/legacy/rtl/common/cgra_types_pkg.sv) |
| `rtl/fixed/cgra_2x2_core.sv` | [reference/legacy/cgra_2x2_core.sv](reference/legacy/cgra_2x2_core.sv) |
| `rtl/fu/combo/vendor/svsrc/ALUgenMAC.sv` | [reference/vendor/alu_gen_mac/svsrc/ALUgenMAC.sv](reference/vendor/alu_gen_mac/svsrc/ALUgenMAC.sv) |
| `rtl/fu/combo/vendor/dp_fpfma/DW02_multp.v` | [reference/vendor/alu_gen_mac/dp_fpfma/DW02_multp.v](reference/vendor/alu_gen_mac/dp_fpfma/DW02_multp.v) |
| `rtl/fu/combo/vendor/README.md` | [reference/vendor/alu_gen_mac/README.md](reference/vendor/alu_gen_mac/README.md) |

`tests/legacy/rtl/` 中的模块是历史测试使用的旧 DUT，不是当前系统入口。
`reference/legacy/` 和 `reference/vendor/` 中的 HDL 用于差分比较与来源追溯。维护的 MAC 实现仍为 `rtl/fu/combo/cgra_alu_gen_mac_core.sv` 和 `cgra_multp.sv`；原始许可继续适用，见 [DEPENDENCIES.md](DEPENDENCIES.md)。

路径与移动前 SHA-256 保存在 [tests/legacy/relocations.json](tests/legacy/relocations.json)。历史结果、冻结轨迹及源码注释中的旧路径仍表示其记录时的位置，不能据此推断文件还属于当前核心 RTL。原参考内容和验收结果不因目录整理被改写；当前生成的迁移位置清单按新路径更新。

## 构建与历史回归

- `filelists/native.f` 只列出当前功能 RTL，已移除上述六个历史文件及原始 MAC 参考 include 路径。
- `filelists/rtl.f`、`phase3.f`、`phase4.f` 保留历史测试所需模块，引用迁移后的路径。
- 当前构建缓存对 `rtl/` 和调用方显式传入的测试输入计算散列。未使用的历史文件或 golden 参考变化不再使当前 DUT 缓存失效。
- `scripts/run_baseline.sh` 仍先恢复并校验固定旧提交，再复制同一基线的源码到新路径，以供更新后的测试脚本使用。旧路径保留给基线自身的 Makefile 和 filelist；不会把当前版本 RTL 混入基线。

```bash
# 当前原生系统与组件
make -C sv current
bash sv/tests/current/run_relu_yaml.sh sv/examples/yaml/relu_neura_pass.yaml

# 历史行为必须使用对应的固定源码基线
bash sv/scripts/run_baseline.sh types sim
bash sv/scripts/run_baseline.sh phase3

# 目录边界、缓存身份、基线恢复与打包工具检查
python3 -m unittest discover -s sv/tests/scripts -p 'test_*.py'
python3 sv/migration_tools/inventory.py --check
```

移动只改变工程组织，不扩大功能范围，也不把历史回归通过替代为当前原生语义正确性的证明。

名称含 `legacy` 不一定表示历史测试源码。例如 `cgra_loop_controller_legacy.sv`
仍由公开组件的兼容参数选择，属于明确提供的硬件行为；这类可达实现保留在核心目录。

## 本次目录整理的验证

2026-10-16 使用固定工具链完成以下检查：

| 检查 | 结果 |
|---|---|
| 所有保留与迁出的 HDL 字节、第三方许可散列 | 不变；迁移清单与文件位置一致 |
| Python 原文件与当前迁移清单 | 274 个文件散列及实现位置检查通过 |
| 构建、基线恢复、打包与目录边界工具 | 从提交暂存区导出的独立快照中，14 项单元检查通过 |
| `make -C sv current` | 原生 FU、状态、PE 变体、DMA 和系统回环及负例通过 |
| 用户 ReLU YAML | 32 个结果与 STORE/RETURN 验收通过；正常 566 周期，背压 1172 周期 |
| 两个多 CGRA 顶层与三个历史顶层 | Verilator 展开／lint 通过，文件引用完整 |
| 固定基线的 types、2×2 整机 | 打包检查与 134 个采样周期对照通过 |
| 固定基线的 Tile、FU 单元和乘法器差分 | 2000 周期 Tile、4 类 FU 单元、18,432 组乘法器样本通过 |
| 固定基线 Context 与 Streaming 整机 | 正常运行及损坏输出负例通过 |
| 独立交付 | 标记为 dirty 的验证包完整性检查通过；脱离 Git 后可恢复基线并提供 10 个新路径 |
| HTML／Markdown 导览 | 新路径分组、搜索、桌面／手机布局和 ReLU 代码示例检查通过 |

本次未重跑全部回归分组或系统综合；上表中的顶层展开检查不代表综合、时序或 PPA 结果。
