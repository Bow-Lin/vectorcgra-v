# HDL 来源与许可范围

独立包保留各依赖的原始声明，不能把整个包概括为仅受 VectorCGRA 的 BSD 许可覆盖。
源码和冻结参照均包含在包的逐文件 SHA256 清单中；生成网表并不改变来源条件。

| 内容 | 来源／固定版本 | 声明位置与边界 |
|---|---|---|
| VectorCGRA 维护版 RTL、测试及独立工具 | 历史起点 ac96a7af；Python 目标 cd7aad878915（源码来自父提交 e3caf6928a4e） | `LICENSE`，BSD 3-Clause；下列依赖另有条件 |
| 原 PyMTL 框架及冻结 HDL 的来源 | 项目原有 PyMTL 工作流 | `licenses/PyMTL-LICENSE`；正常原生构建不安装 PyMTL |
| PyOCN 衍生网络行为 | d8ffacc64fb8dd24ce26e944d501016880302bbe | `licenses/PyOCN-LICENSE`，BSD 3-Clause |
| Berkeley HardFloat | aea69e416e079178df4bb5697795ef653f55df58 | `rtl/vendor/hardfloat/COPYING.txt` 及各源码头；11 个文件 SHA 见同目录 `provenance.json` |
| ALUgenMAC 与维护版 `cgra_alu_gen_mac_core` | 原 `fu/fused_alu_fixedp` | `rtl/fu/combo/vendor/svsrc/ALUgenMAC.sv` 的 Genesis2 非商业声明继续适用 |
| DW02_multp 与维护版 `cgra_multp` | 原 Synopsys 模型；原文仅换行归一化 | `rtl/fu/combo/vendor/dp_fpfma/DW02_multp.v` 及 `cgra_multp.sv` 的 Synopsys 专有声明继续适用 |

MAC 的两个维护版模块是原算法的可综合整理，不能因为文件名或语言组织改变而称为
重新授权的独立实现。原 vendor 模型不在 DUT 文件清单中，但其声明及衍生关系仍保留；
冻结参考也可能嵌入同一 IP。具体内容与字节差异见 `rtl/fu/combo/vendor/README.md`。

机器可读清单为 `licenses/dependencies.json`。它记录当前相关文件 SHA 和原始来源，
不授予原声明之外的使用或再分发权限。公开发布、商业使用等应遵循这些已有条款。

Verilator、Yosys、sv2v、编译器属于外部构建工具，不打包进工程源码归档。
`scripts/toolchain.lock.json` 固定下载版本和 SHA；各工具自己的发行包保留其许可。

可选 `tools/cgra_yaml.py` 使用外部 PyYAML（MIT）解析数据，本次验证版本为 6.0.3；
工程包不内嵌 PyYAML。仅使用原有 JSON 工具时不需要安装它。
