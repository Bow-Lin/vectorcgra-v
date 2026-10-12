# 原生回归与工具链

`scripts/regression.json` 是本地与 CI 共用的清单，14 个分组覆盖 48 个当前验收目标。
清单检查拒绝漏列或重复目标；原 Python 源码分类审计 `migration-inventory` 单独运行。
历史 `phase2/3/4` 入口不属于当前 RTL 契约；`baseline` 在固定 `cd7aad` 源码上运行
原 `all`（类型、2×2 仿真、负例及综合），不声称重跑了全部历史阶段。

```bash
python3 sv/scripts/install_toolchain.py
source sv/build/toolchain/env.sh
python3 sv/scripts/regression.py --check-catalog
python3 sv/scripts/regression.py --list
python3 sv/scripts/regression.py --shard core
make -C sv regression
make -C sv migration-inventory
```

安装器支持 Linux x86_64，依赖系统 Python 3 标准库、curl、tar、unzip；编译另需
C++20 编译器、make 和 Perl（Verilator 启动脚本使用）。锁定 OSS CAD Suite 2024-09-20（Verilator 5.029、Yosys
0.45+139）与 sv2v 0.0.13，下载后检查完整 SHA256。缓存归档同样检查 SHA，再解压并
核对实际版本。正常构建不需要 PyMTL，也不运行原项目的 Python RTL。其他平台可自行
设置 VERILATOR／SV2V／YOSYS／CXX，验证记录必须保留实际版本。

统一驱动逐项记录退出码、耗时、日志 SHA、工具版本及输入源码 SHA；失败即停止该分组，
标出未执行目标。前后输入变化也视为失败。结果位于 `sv/build/regression/<shard>/`。
CI 使用同一清单，分组独立执行，保存失败日志，不以日志里的单个 PASS 字样代替退出状态。
旧 CI 使用 apt Verilator 5.020，在 Shifter 原始周期重放中失败；该失败不计入通过记录。

完整 Mesh 网表解析实测需要约 11.4 GiB，建议独占 16 GiB 内存。CI 对 systems／pe
分组检查有效上限至少 14 GiB（为标称 16 GiB 主机保留内核差额），同时记录 cgroup
限制。默认 JOBS=1，重型 runner 拆分生成 C++ 函数并关闭 C++ 优化；Verilator 的 RTL
优化仍开启。资源预检不等于对任意架构规模的内存保证。CI 每组超时 180 分钟。

内核边界及迁移 runner 的 `run` 模式检查构建身份：RTL、头文件、文件清单、bench、
runner、有效参数和工具版本。身份变化必须重新编译，不允许使用旧二进制。新生成的
程序数据仍逐次读取；核验的编译参数包含内存模式和生成器输出的 elaboration 参数。

`tests/scripts/test_regression.py` 检查漏列、重复、失败传播、执行期间源码变化，以及
内存模式／文件清单变化对构建身份的影响。完整远端结果应查对应提交的 Actions 运行，
不可把本地通过或工作流语法检查写成远端 CI 通过。

本批本地记录见 `reference/current/regression/validation.json`：统一 baseline／core、
Context64 实际网表、72 次内核数学运行及两个迁移场景均通过；干净 Ubuntu 24.04／
GCC 13 的 8 FU、539 周期重放也通过。该记录生成于提交前，远端结果单独记录。
具体远端提交、运行链接和观察结果见 [最终验收索引](FINAL_ACCEPTANCE.md)。
