# BSAI-ComfyUI-intel-XPU-GPU-NPU-aki

BSAI 多硬件协同整合包（Intel XPU + NVIDIA GPU + NPU）—— 整合包级启动器、Intel Omni 加速组件健康检查与使用文档。

本仓库承载整合包根目录下的启动器与文档类文件（不含模型、Python 环境、ComfyUI 本体与插件源码，插件源码在各插件仓库独立管理）。

## 内容 Contents

- `BSAI-ComfyUI-intel-XPU-GPU-NPU-aki_多硬件协同模式.bat` — 多硬件协同启动器（CUDA 主实例 8191 + 8190 XPU VAE worker + NPU 同进程），XPU 分支默认开启 Smart Memory（`BSAI_DYNAMIC_VRAM=1`），预留显存可用 `BSAI_RESERVE_VRAM` 配置
- `BSAI_Omni加速组件健康检查.cmd` — 对照视频 BV1SPno6bE4w 的 4 个启动日志检查点：Kitchen XPU 后端 / DynamicVRAM-AIMDO / omni_xpu_kernel / Omni 适配器状态
- `BSAI_Omni加速优化报告_20261026.md` — 本次 Intel Omni 优化总结报告（含对照表与验证结果）
- `user/BSAI_四硬件协同工作说明/BSAI-整合包完整使用教程_中英双语.md` — 完整使用教程（中英双语）

## 相关仓库 Related repos

- 各 BSAI 插件: https://github.com/xm6018924?tab=repositories
