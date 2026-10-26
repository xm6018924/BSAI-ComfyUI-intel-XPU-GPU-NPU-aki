# BSAI 四硬件协同整合包 · 完整使用教程（中英双语）
# BSAI Quad-Hardware Co-op Pack · Complete User Guide (Bilingual)

> 整合包根目录：`G:\BSAI-ComfyUI-intel-XPU-GPU-NPU-aki`
> Package root: `G:\BSAI-ComfyUI-intel-XPU-GPU-NPU-aki`

---

## 0. 总览 Overview

本整合包目标是"全网没有的四硬件协同"：一条工作流内，四个计算单元自动分工、互不抢活。

This pack's goal is quad-hardware cooperation: inside ONE workflow, four compute units share the work automatically, without fighting each other.

| 硬件 Hardware | 角色 Role | 负责 What it does |
|---|---|---|
| RTX 5090（GPU1 / CUDA） | 采样主力 Sampling | 扩散采样（最占算力的大头） |
| Intel 核显（GPU0 / XPU） | VAE 解码 VAE decode | 潜空间 → 画面解码（分担显存与耗时） |
| Intel NPU | 人脸检测 Face detect | 人脸框选/跟踪（不占 GPU） |
| CPU | 兜底 Fallback | 其它插件不可用时降级执行 |

核心组件：编排层（BSAI-ComfyUI-Orchestrator + 协同 SDK）+ VAE 路由（BSAI-ComfyUI-VAERouter）+ 硬件监控 HUD（BSAI-ComfyUI-Hardware-Perf）+ NPU 服务（BSAI-NPU-Service）+ 8190 轻量 VAE 服务（BSAI_XPU_VAE_Server.py）。

Core parts: Orchestrator + Co-op SDK, VAERouter, Hardware-Perf HUD, NPU-Service, and the 8190 lightweight VAE server.

---

## 1. 三个启动器 The Three Launchers

整合包根目录提供 **3 种启动方式**，行为完全不同：

Three launch ways exist in the pack root, with totally different behavior:

| # | 启动器 Launcher | 类型 Type |
|---|---|---|
| 1 | `BSAI-ComfyUI-intel-XPU-GPU-NPU-aki_多硬件协同模式.bat` | 命令行自动协同（推荐） |
| 2 | `BSAI-ComfyUI-intel-XPU-GPU-NPU-aki_H3VM双卡模式.bat` | 命令行双卡并行 |
| 3 | `绘世启动器.exe`（即"秋叶/Aki 启动器"） | 图形界面通用启动器 |

---

## 2. 每个启动器运行后发生什么（核心区别）

### 2.1 多硬件协同模式.bat —— 推荐 Recommended

**启动后发生：**
- 自动检测 GPU（有 NVIDIA → CUDA 主实例；无 → XPU）
- 自动拉起 **8190 轻量 VAE 服务**（新窗口，`BSAI_XPU_VAE_Worker_8190.bat` → `BSAI_XPU_VAE_Server.py`）
- 主实例 **8191**（CUDA，`python_embeded_cuda`），NPU 服务同进程挂载
- 一条流水线内四硬件自动分工：采样 GPU1 / VAE 解码核显 / 人脸检测 NPU / 兜底 CPU

**UI 数量：1 个浏览器标签**（http://127.0.0.1:8191）+ 1 个后台 8190 窗口（无界面）。

After launch: GPU detected → CUDA main on **8191**; the **8190 XPU VAE server** starts automatically in a background window; NPU runs inside 8191. ONE browser tab only. All quad-hardware co-op is automatic inside the same workflow.

### 2.2 H3VM双卡模式.bat —— 备选 Alternate

**启动后发生：**
- **8190**：启动一个**完整独立的 XPU ComfyUI**（`python_embeded` 跑 `ComfyUI\main.py`，完整流水线能力）
- **8199**：启动 CUDA 主实例（`python_embeded_cuda`）
- 两个实例**各自独立、互不通信**（无自动桥接：8190 上没有 `/vae/decode` 轻量端点，VAERouter 的核显分流失效）

**UI 数量：2 个浏览器标签**（http://127.0.0.1:8190 与 http://127.0.0.1:8199）。

After launch: a full XPU ComfyUI on **8190** AND a CUDA ComfyUI on **8199** — two independent instances, no bridge. You get TWO browser tabs.

**同一工作流？还是两条不同工作流？** 都可以——把同一份 JSON 分别拖进两个标签 = 同一工作流双卡并行（不同种子/输入各出各的）；拖两份不同 JSON = 两条完全不同的工作流。但**不是一条流水线内的节点分工**。

Same workflow or two different ones? Either works — same JSON in both tabs = parallel runs; two JSONs = two independent jobs. But there is NO intra-workflow node-level sharing.

### 2.3 绘世启动器.exe（秋叶/Aki Launcher）

**启动后发生：**
- 图形界面（GUI）启动器：环境（python）、端口、启动参数全部在 GUI 里每次自选
- **单实例启动**：只起一个 ComfyUI（默认选 CUDA 环境 `python_embeded_cuda`，端口以 GUI 设置为准，通常 8188）
- **不会自动拉起 8190**：核显 VAE 分流默认不可用（VAERouter auto 探活 8190 失败 → 自动降级 cuda/cpu）

**想用绘世又想要协同？** 先手动双击 `BSAI_XPU_VAE_Worker_8190.bat`（单独开 8190 轻量服务窗口），再用绘世启动主实例 —— 效果等同多硬件协同模式。

After launch: ONE ComfyUI via GUI (env/port chosen each time in the launcher UI). The 8190 VAE server is NOT auto-started — to keep co-op, open `BSAI_XPU_VAE_Worker_8190.bat` manually first, then start the main instance.

---

## 3. 三启动器速查对比表 Comparison Cheat Sheet

| 维度 Dimension | ① 多硬件协同模式 | ② H3VM双卡模式 | ③ 绘世启动器（秋叶） |
|---|---|---|---|
| 主实例端口 Main port | **8191** | **8199** | GUI 自选（默认 8188） |
| 8190 端口 | 轻量 VAE 服务（自动拉起） | 完整 XPU ComfyUI（独立实例） | 不启动 |
| 浏览器标签 Tabs | 1 个 | 2 个 | 1 个 |
| 协同 Co-op | ✅ 一条流水线四硬件分工 | ❌ 两条独立流水线并行 | ⚠️ 手动开 8190 才协同 |
| VAERouter 核显分流 | ✅ 可用 | ❌ 失效（8190 无轻量端点） | ⚠️ 手动开 8190 后可用 |
| 人脸 NPU | ✅ 同进程 8191 | ✅ 同进程 8199 | ✅ 同进程主实例 |
| HUD 监控 | ✅ 全表盘 | ✅ 8190 表盘仅 system_stats | ✅ 需 8190 在跑 |
| 适用场景 | **日常 / 人脸修复 / 单流水线提速** | H3 视频双卡批量并行出片 | 习惯 GUI / 只想开一个实例 |
| 同时只能开一个 | ✅ 与 ② 冲突（抢 8190） | ✅ 与 ① 冲突 | 可与 8190 worker 组合 |

---

## 4. 我该用哪个？Which One Should I Use?

| 你的需求 Your need | 选择 Choice |
|---|---|
| 人脸修复 / 普通工作流 / 验收四硬件协同 | **① 多硬件协同模式.bat** |
| H3 视频两条完整流水线并行（不同工作流/不同输入） | ② H3VM双卡模式.bat |
| 习惯图形界面、单实例、不想看命令行 | ③ 绘世启动器 + 手动 `BSAI_XPU_VAE_Worker_8190.bat` |
| 不确定 | **永远先选 ①** |

**铁律**：①②抢同一个 8190 端口，**同一时间只能开一个**。切换前先关掉另一个的全部窗口。

Rule: ① and ② both use port 8190 — only ONE at a time. Close all windows of the other before switching.

---

## 5. 与插件协同的配合 How Co-op Works in Practice

1. **启动**：用 ①（或 ③+手动 8190）。等日志出现：
   - `[BSAI H3VM] XPU worker on port 8190 starting...`（8190 轻量服务）
   - `[BSAIFaceRefine] NPU face detect ENABLED`（NPU 就绪）
   - 无插件 import 报错
2. **跑工作流**：加载 `BSAI_人脸修复_四硬件协同_v3.0.json`，VAE 解码路由（VAERouter）保持 `strategy=auto`
3. **看证据**：
   - 8191 日志出现 `[BSAI-VAERouter] decode on xpu` → 核显真的在解码
   - HUD 五表盘：GPU1/核显/NPU/CPU/RAM 实时跳动；核显从 N/A 变真实读数
   - NPU 表盘有检测计数 → 人脸检测走 NPU

Start with launcher ①, wait for the three log markers, run the v3.0 face-refine workflow with VAERouter on auto, then check the HUD gauges and the `decode on xpu` log line.

---

## 6. 常见问题 FAQ

**Q1：启动后一直卡在 logo？** 首次启动加载自定义节点 1~2 分钟属正常；超过 3 分钟请关掉重试，并确认没有第二个实例占端口。

**Q2：拖工作流进画布卡死？** 确认用的是 ①；② 的两个实例不要同时打开同一工作流执行。

**Q3：核显表盘一直是 N/A？** 8190 没在跑——确认 `bsai_8190_worker.log` 有内容，或重开 `BSAI_XPU_VAE_Worker_8190.bat`。

**Q4：日志报 `decode on cuda`（没走核显）？** VAERouter 是 auto 吗？GPU1 显存充足时水位策略可能优先保留 cuda；8190 在线且显存紧张时自动切 xpu——属正常分流逻辑。

**Q5：HUD 拖动/透明？** 左键拖动自由停靠、右键调透明度；指针拖尾为同色光幕（非多指针）。

Q1: first launch loads custom nodes 1–2 min — normal; >3 min restart and check no second instance. Q2: use launcher ①. Q3: N/A gauge = 8190 down — check `bsai_8190_worker.log`. Q4: `decode on cuda` = auto policy kept cuda (VRAM ample) — expected. Q5: HUD drag = left button, opacity = right button.

---

## 7. 日志与维护 Logs & Maintenance

| 内容 Item | 位置 Location |
|---|---|
| 8190 轻量服务日志 | `G:\BSAI-ComfyUI-intel-XPU-GPU-NPU-aki\user\bsai_8190_worker.log` |
| 编排状态 | `ComfyUI\user\bsai_orchestrator_state.json` |
| 主实例数据库 | `ComfyUI\user\comfyui_8191.db`（①）/ `comfyui_8199.db`（②） |
| NPU 模型缓存 | `ComfyUI\models\NPU\.cache` |

版本历史：v2.0（NPU 激活）→ v3.0（四硬件协同 + SDK 批量接入 + 编排租约双写防护）。改动仅限本 G 盘整合包；验收后如需同步其他盘符，需用户明确指示。

Version history: v2.0 NPU enabled → v3.0 quad co-op + SDK batch integration + lease fencing. Changes stay on this G-drive pack only; syncing elsewhere only on your explicit go-ahead.

---

## 8. Intel Omni 加速组件优化（对照 BV1SPno6bE4w）
## 8. Intel Omni Accelerator Tuning (ref BV1SPno6bE4w)

> 视频参考：《intel秋叶整合包评价：加速组件效果优异，启动器仍需努力》https://www.bilibili.com/video/BV1SPno6bE4w/ （1h04m，2026-10-25）
> Ref: intel+aki pack review — Omni accelerator praised, launcher still improving.

### 8.1 已按视频建议落地的优化 Applied changes

| 视频建议 Video tip | 本项目落地 Applied here |
|---|---|
| B 系列显卡建议开启 Smart Memory（动态显存，激活 AmigoXPU/AIMDO 防爆显存） | 多硬件协同模式.bat XPU 分支默认 `--enable-dynamic-vram`（原为 disable，会跳过 AIMDO 补丁）；可用 `set BSAI_DYNAMIC_VRAM=0` 回退 |
| 预留显存：显存富裕保持 4G；12G（B580 等）建议 1G/0.5G | 新增 `BSAI_RESERVE_VRAM` 环境变量（默认 4G），同时作用于 `OMNI_COMFYUI_RESERVE_VRAM_GB` 与 `--reserve-vram` |
| 注意力后端：B 系列 Q 算子 / A 系列 ESIMD / CPU 兜底 SDPA | 已配置 `OMNI_IMAGE_XPU_TARGET=bmg` + `OMNI_ATTN_BACKEND=cute`，无需改动 |
| 旧版插值修复：正常不开 | 已配置 `OMNIXPU_INTERPOLATE_FIX=0`，无需改动 |
| 启动日志 4 个检查点（Kitchen XPU 后端 / DynamicVRAM-AIMDO / Kernel / 适配器状态） | 新增 `BSAI_Omni加速组件健康检查.cmd`，自动扫描日志并逐项判定 |

### 8.2 健康检查脚本用法 Health check usage

```bat
BSAI_Omni加速组件健康检查.cmd            :: 自动找 ComfyUI\user\ 下最新 comfyui_*_console.log
BSAI_Omni加速组件健康检查.cmd <日志路径>  :: 指定日志文件
```

四个检查点含义（同视频总结）：
1. **Kitchen XPU 后端** `[OK]` → 算子层通（39+ 个算子进 XPU 通道）
2. **DynamicVRAM / AIMDO** `[OK]` → 防爆显存机制激活（Amigo 补丁挂载成功）
3. **omni_xpu_kernel** `[OK]` → 底层加速库可用（Kernel available）
4. **Omni 适配器** `[OK]` → [OmniXPU] 工作日志存在，applied/skipped 配比人工核对

> CUDA 主实例日志会显示 `[SKIP]`（OmniXPU 预期不激活）并提示 CUDA 分支默认 `--disable-dynamic-vram`（由 BSAI-AimDo-Fix 管理 NVIDIA 侧兼容性），属正常。

### 8.3 版本协同说明 Version alignment

| 组件 Component | 本项目版本 Installed | 视频拍摄时状态 Video state |
|---|---|---|
| ComfyUI | 0.42.0 | 0.42（官方最新） |
| torch | 2.13.0+xpu | 2.13（Omni 内核关键版本） |
| comfy-kitchen | 0.2.40 | 0.2.39（已追平） |
| comfy-aimdo | 0.6.0 | 0.56 |
| omni_xpu_kernel | 0.2.0b2+torch213.bmg | B2（B 系列） |

Intel 加速组件以源码方式发布，版本落后时可改源码版本号追平；本整合包内核与加速组件已配套升级，可放心使用。

---

*BSAI Quad-Hardware Co-op Pack · 中英双语教程 · 2026-10*
