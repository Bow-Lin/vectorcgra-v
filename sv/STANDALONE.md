# 独立 SystemVerilog 工程

导出包包含当前 `sv/` 源码、独立配置／程序工具、测试、冻结输入、来源及许可声明。
普通构建不需要原项目的 Python 目录、`.git` 或 PyMTL。Python 3 标准库仍用于配置、
回归编排和完整性检查；EDA 工具本身也可能使用 Python／Perl。
直接加载 YAML 以及包含 `native-yaml-relu` 的完整回归另需 PyYAML；原 JSON 工具不受影响。

从完整 Git 仓库导出：

```bash
python3 sv/scripts/export_standalone.py --output work/vectorcgra-native.tar.gz
mkdir -p work/unpacked
tar -xzf work/vectorcgra-native.tar.gz -C work/unpacked
cd work/unpacked
python3 sv/scripts/verify_bundle.py
python3 sv/scripts/install_toolchain.py
source sv/build/toolchain/env.sh
make -C sv current
make -C sv config-tools program-tools
python3 sv/scripts/regression.py --shard baseline
```

默认要求 `sv/` 工作树干净。`--allow-dirty` 只用于提交前验收，生成清单会明确标记
`dirty_source: true`；正式包来自干净提交。归档按路径排序，时间及 uid/gid 归一化，
同一输入重复导出字节相同。旁边的 `.sha256` 检查压缩包；包内
`BUNDLE_MANIFEST.json` 逐项检查文件内容、来源提交和原 Python 目标。

完整 native 回归使用 `python3 sv/scripts/regression.py --all`，范围及资源需求见
[REGRESSION.md](REGRESSION.md)。独立包附带固定 `cd7aad` 的历史 SV 归档及 SHA；
baseline runner 每次先校验并还原原始 DUT／输入／参考，再覆盖原来存在的便携 runner，
因此不依赖包外 Git 历史，也不会因原历史目标不可用而假装通过。

`migration-inventory` 是原 274 个 Python 文件的源码审计，需要完整原仓库，单独运行，
不包含在 native 回归中。保留的 `migration_tools/` 和 `exporter_snapshot.py` 是
历史取证／参考生成工具，不属于普通构建入口；重建原 Python 参照仍需要原开发环境。
导出包内再次执行 Git 导出器也需要完整仓库，不作为独立运行条件。

干净环境验收记录见 `reference/current/standalone/validation.json`：在仅挂载解包工程
和固定 HDL 工具的 Ubuntu 24.04 容器中检查 PyMTL 不存在，再从空 build 目录运行指定
目标。该验收与完整仓库的 14 组 CI 结果分开记录，不把选定干净构建冒称为所有参数的证明。

许可范围见 [DEPENDENCIES.md](DEPENDENCIES.md)。包保留 HardFloat、PyOCN、PyMTL
以及 MAC／乘法模型的原声明；MAC 相关部分不能仅按项目 BSD 许可处理。

验收入口 `bash sv/scripts/check_standalone.sh` 要求新解包且没有 build 目录；先选择
包外已安装的 HDL 工具。它运行 current、架构／程序工具、历史 baseline 和 AXPY
组合存储模式的六个场景及背压／完成负例。正常开发不要求系统卸载 PyMTL，只有此
干净环境验收会检查 PyMTL 不存在。

本批验收快照含 1,575 个有效载荷文件，两次导出字节完全一致；947 个基线文件与 Git
归档逐项相同。运行前后完整性检查通过，故意破坏 RTL 的反例被拒绝。记录明确标明
该提交前快照为 dirty；正式归档由提交后的干净工作树重新导出，不混淆两个 SHA。
正式提交包的 SHA、运行输入比对和远端 artifact 入口见 [最终验收索引](FINAL_ACCEPTANCE.md)。
