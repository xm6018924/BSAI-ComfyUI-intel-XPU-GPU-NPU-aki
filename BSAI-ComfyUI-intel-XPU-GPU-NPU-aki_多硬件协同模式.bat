@echo off
set PYTHONUTF8=1

REM ---- BSAI DynamicVRAM / Smart Memory 开关 ----
REM 视频依据: intel秋叶整合包评测(BV1SPno6bE4w) 建议 B 系列显卡开启 Smart Memory(动态显存),
REM 以激活 Intel Omni 加速组件中的 AIMDO(AmigoXPU) 补丁(动态显存调度/防爆显存, 冷跑提速约1.7x)。
REM 默认开启(1); 如需回退旧行为(禁动态显存): set BSAI_DYNAMIC_VRAM=0
if not defined BSAI_DYNAMIC_VRAM set "BSAI_DYNAMIC_VRAM=1"

REM ---- BSAI 预留显存(GB) ----
REM 视频依据: 显存富裕保持默认 4G; 12G 显存(B580 等)建议 1G 或 0.5G。
REM 自定义: set BSAI_RESERVE_VRAM=1
if not defined BSAI_RESERVE_VRAM set "BSAI_RESERVE_VRAM=4"
set "OMNI_COMFYUI_RESERVE_VRAM_GB=%BSAI_RESERVE_VRAM%"
setlocal enabledelayedexpansion
title BSAI ComfyUI Dual-Backend Launcher

set "ROOT=%~dp0"
cd /d "%ROOT%"

set "FORCE="
if /i "%~1"=="--xpu" set "FORCE=xpu"
if /i "%~1"=="--cuda" set "FORCE=cuda"
if not "!FORCE!"=="" shift

set "PORT=8191"
if not "%~1"=="" set "PORT=%~1"

echo [BSAI] ============================================
echo [BSAI]   BSAI ComfyUI Dual-Backend Launcher
echo [BSAI]   Requested port: !PORT!   Forced backend: !FORCE!
echo [BSAI]   DynamicVRAM(Smart Memory): !BSAI_DYNAMIC_VRAM!   Reserve VRAM: !BSAI_RESERVE_VRAM! GB
echo [BSAI] ============================================

REM ---- Forced backend ----
if "!FORCE!"=="xpu" (
    set "GPU_TYPE=xpu"
    goto :portcheck
)
if "!FORCE!"=="cuda" (
    set "GPU_TYPE=nvidia"
    goto :portcheck
)

REM ---- Fast GPU detection ----
set "GPU_TYPE=nvidia"
nvidia-smi >nul 2>&1
if !errorlevel! neq 0 set "GPU_TYPE=xpu"

echo [BSAI] Detected GPU type: !GPU_TYPE!

:portcheck
netstat -ano | findstr /R /C:":!PORT! .*LISTENING" >nul 2>&1
if !errorlevel! equ 0 (
    set /a PORT+=1
    if !PORT! gtr 8250 (
        echo [BSAI] ERROR: ports 8191-8250 all in use.
        pause & exit /b 1
    )
    goto :portcheck
)
set "DB=comfyui_!PORT!.db"
echo [BSAI] Using port: !PORT!   Database: !DB!
echo.

REM ---- XPU VAE worker (8190) ----
set "XPU_WORKER_BAT=%ROOT%BSAI_XPU_VAE_Worker_8190.bat"
netstat -ano | findstr /R /C:":8190 .*LISTENING" >nul 2>&1
if !errorlevel! neq 0 (
    if exist "!XPU_WORKER_BAT!" (
        echo [BSAI] Starting XPU VAE worker on 8190 ...
        start "BSAI-XPU-VAE-Worker" /min "!XPU_WORKER_BAT!"
    ) else (
        echo [BSAI] XPU worker script not found: !XPU_WORKER_BAT!
    )
) else (
    echo [BSAI] XPU VAE worker already running on 8190
)

if "!GPU_TYPE!"=="nvidia" goto :cuda
if "!GPU_TYPE!"=="xpu" goto :xpu
goto :nofound

:xpu
REM ---- BSAI DynamicVRAM 参数落地 (Intel XPU 侧) ----
REM Intel Omni 加速组件建议: B 系列开启 Smart Memory 后 AIMDO(AmigoXPU) 补丁才会激活。
if "!BSAI_DYNAMIC_VRAM!"=="0" (set "DYNAMIC_VRAM_ARG=--disable-dynamic-vram") else (set "DYNAMIC_VRAM_ARG=--enable-dynamic-vram")
if not exist "%ROOT%python_embeded\python.exe" (
    echo [BSAI] ERROR: python_embeded\python.exe not found
    echo [BSAI] This XPU runtime is required on machines without NVIDIA GPU.
    pause & exit /b 1
)
echo [BSAI] ============================================
echo [BSAI]  XPU-ONLY MODE (no NVIDIA GPU detected)
echo [BSAI]  - ComfyUI running on Intel iGPU via OpenVINO/IPEX
echo [BSAI]  - Requires >= 16GB system RAM (shared GPU memory)
echo [BSAI]  - VAE decode offloaded to XPU worker on :8190
echo [BSAI] ============================================

for /f "skip=1 tokens=*" %%M in ('wmic ComputerSystem get TotalPhysicalMemory') do (
    if not "%%M"=="" (
        set /a TOTAL_MB=%%M/1024/1024
        goto :ramdone
    )
)
:ramdone
if !TOTAL_MB! LSS 16000 (
    echo [BSAI] WARNING: only !TOTAL_MB! MB RAM detected, H3 models need >=16GB for iGPU.
) else (
    echo [BSAI] RAM: !TOTAL_MB! MB OK
)

set OMNIXPU_ENABLE=1
set OMNIXPU_PROVIDER_BOOTSTRAP=auto
set OMNI_IMAGE_XPU_TARGET=bmg
set OMNI_ATTN_BACKEND=cute
set UR_L0_USE_IMMEDIATE_COMMANDLISTS=1
set OMNIXPU_INTERPOLATE_FIX=0
set SOL_ATTN_XPU_EXPERIMENTAL=1
set "OMNI_COMFYUI_RESERVE_VRAM_GB=%BSAI_RESERVE_VRAM%"
set PYOPENGL_USE_ACCELERATE=false
set HF_ENDPOINT=https://hf-mirror.com
set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6,max_split_size_mb:256
set VDN_H3_WINDOW_SDPA=mem_efficient
set BSAI_H3_LLM_GPU_LAYERS=0
set TRANSFORMERS_DISABLE_DOCSTRING_VALIDATION=1

echo [BSAI] Launch args: port !PORT! / db !DB!
echo.

"%ROOT%python_embeded\python.exe" -u -s ComfyUI\main.py --reserve-vram !OMNI_COMFYUI_RESERVE_VRAM_GB! --preview-method auto --windows-standalone-build --listen --port !PORT! --async-offload !DYNAMIC_VRAM_ARG! --database-url "sqlite:///ComfyUI/user/!DB!" --fast --disable-comfy-compiler
goto :end

:cuda
if not exist "%ROOT%python_embeded_cuda\python.exe" (
    echo [BSAI] ERROR: python_embeded_cuda\python.exe not found
    pause & exit /b 1
)
echo [BSAI] Starting ComfyUI with NVIDIA CUDA runtime ...

REM ---- BSAI GPU topology detect (shared module) ----
REM Single-GPU machines keep ComfyUI's official forced single-GPU mode;
REM multi-GPU machines automatically inject --cuda-device all.
call "%ROOT%_bsai_gpu_detect.cmd"
set "CUDA_DEVICE_ARGS="
if !BSAI_NVIDIA_GPU_COUNT! GEQ 2 set "CUDA_DEVICE_ARGS=--cuda-device all"
if !BSAI_NVIDIA_GPU_COUNT! GEQ 2 (
    echo [BSAI] Detected !BSAI_NVIDIA_GPU_COUNT! NVIDIA GPU: !BSAI_NVIDIA_GPU_NAMES!
    echo [BSAI] Multi-GPU mode ON: --cuda-device all ^(2nd GPU used for offload / VRAM expansion^)
) else (
    echo [BSAI] NVIDIA GPU count = !BSAI_NVIDIA_GPU_COUNT! - single-GPU mode, no --cuda-device all.
)

set OMNIXPU_ENABLE=0
set PYOPENGL_USE_ACCELERATE=false
set HF_ENDPOINT=https://hf-mirror.com
set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6,max_split_size_mb:256
set VDN_H3_WINDOW_SDPA=mem_efficient
set BSAI_H3_LLM_GPU_LAYERS=0
set TRANSFORMERS_DISABLE_DOCSTRING_VALIDATION=1

echo [BSAI] Launch args: port !PORT! / db !DB!
echo.

"%ROOT%python_embeded_cuda\python.exe" -u -s ComfyUI\main.py --reserve-vram 1 --cuda-malloc !CUDA_DEVICE_ARGS! --preview-method auto --windows-standalone-build --listen --port !PORT! --async-offload --disable-dynamic-vram --database-url "sqlite:///ComfyUI/user/!DB!" --fast --use-sage-attention --disable-comfy-compiler
goto :end

:nofound
echo [BSAI] No NVIDIA or Intel GPU detected.
echo [BSAI] Force a backend: launcher.bat --cuda  or  launcher.bat --xpu
pause & exit /b 1

:end
echo.
echo [BSAI] ComfyUI exited.
pause
