# 单元库与本地工具

使用用户工作区事先已有的 `lib/NangateOpenCellLibrary_typical.lib`；不修改或重新分发该文件，Git 忽略 `lib/`。参数：NanGate45 typical，1.1 V、25 °C，Liberty 时间单位 ns、电容单位 fF。

库 SHA256：`8d540a4d4cf6d09d27c87ad067857a9c0c2eeb023ab7a56e058cd3113db4e9b1`。

公开获取地址：[OpenROAD-flow-scripts 的库文件](https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib)。上游可能更新，复现实验时以 SHA256 匹配为准。保留上游版权和许可信息；[平台许可文件](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/master/flow/platforms/nangate45/LICENSE) 可在上游查看。

本机工具：

- [OSS CAD Suite 2026-09-16](https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2026-09-16)，Windows x64；归档 SHA256 `d8e5cd5a3676a09773cb276ccc76b2b31e818549a11959ac044f69e9b4d8c3cc`。
- [sv2v 0.0.13](https://github.com/zachjs/sv2v/releases/tag/v0.0.13)，Windows；归档 SHA256 `5fd5ae5177d88999e333db21cdfa1796e60e557586df10bc0bdd378b94e9eb71`。
- Python 依赖固定在 `requirements-lock.txt`；需要自定义 PyMTL3 fork，不能替换为上游 PyPI 版本。

上述二进制、虚拟环境和下载缓存只在本地使用，不纳入代码提交。
