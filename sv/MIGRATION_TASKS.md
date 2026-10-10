# 已授权的迁移收尾顺序

2026-10-10：用户要求按以下顺序推进，每项检查通过后独立提交并推送 `origin/work`。
提交描述实际改动，不使用里程碑编号作标题。Python 目标固定为
`cd7aad878915e389cecf8cc01ff6987d156bd019`，原始 274 个源文件保持不变。

| 顺序 | 工作 | 状态 |
|---|---|---|
| 1 | 独立 DataMemRTL API；多读写口、预加载、冲突、复位 | 已完成；见 DATA_MEMORY_API.md 与独立 validation.json |
| 2 | DataMemScalableRTL API；保留原 NoC 端口未实现的边界 | 已完成；见 DATA_MEMORY_API.md 与独立 validation.json |
| 3 | N 输入 OrLinkRTL API | 已完成；见 LINK_APIS.md 与独立 validation.json |
| 4 | SelectorRTL API；修正未选择输入的 ready | 已完成；见 LINK_APIS.md 与独立 validation.json |
| 5 | PipeQueueRTL API；满队列同拍出入替换 | 已完成；见 PIPE_QUEUE_API.md 与独立 validation.json |
| 6 | VectorAllReduce 数学、请求及返回握手语义 | 已完成；见 VECTOR_REDUCE_API.md、八份网表及四 CGRA 加／乘法验收 |
| 7 | 向量组合常量进位、VectorMul lane 数边界 | 已完成；见 VECTOR_ARITHMETIC_API.md、十一份网表及三种 PE 验收 |
| 8 | LoopController 输出保持、并发完成及父循环契约 | 已完成；见 LOOP_CONTROLLER_API.md、八份网表及独立语义证据 |
| 9 | 复位、未驱动／锁存、除零及 MAC 有符号边界 | 待执行 |
| 10 | im2col／DataMem、非对称端口、DMA 长度及重启边界 | 待执行 |
| 11 | Base／Context／Streaming PE 公共参数、类型及重复逻辑整理 | 待执行 |
| 12 | NoC 剩余握手、VC／credit 及实际组合环检查 | 待执行 |
| 13 | 不依赖项目 Python 的架构配置工具 | 待执行 |
| 14 | 不依赖项目 Python 的程序／常量／预加载／命令生成工具 | 待执行 |
| 15 | 全模块／功能／opcode 与原始 274 文件覆盖清单 | 待执行 |
| 16 | 扩展内核独立数学验收，包括 AXPY 最终回读及矩阵边界 | 待执行 |
| 17 | 当前源码完整系统与选定综合网表验收 | 待执行 |
| 18 | 统一回归、CI 与工具链 | 待执行 |
| 19 | 当前独立工程导出、干净环境构建与 IP 来源／许可 | 待执行 |
| 20 | 最终文档、差异、参数范围及证据交付 | 待执行 |

以下为另行确认的功能扩展，不因收尾任务而自动实现：LoopController 系统路由，
DataMemScalable 远程访问，任意 FU 端口／VC／credit／稀疏删除 Tile，通用 DAG，
运行时隔离重配置，更广 DMA 格式，以及平台指定后的 FPGA／ASIC PPA。
原 Python 同样未实现的功能不能标成 SV 迁移遗漏。
