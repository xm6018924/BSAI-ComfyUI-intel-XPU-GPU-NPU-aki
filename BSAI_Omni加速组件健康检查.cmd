@echo off
setlocal enabledelayedexpansion
title BSAI Omni Accelerator Health Check

REM ============================================================
REM  BSAI Omni Accelerator Health Check
REM  Based on the 4 startup-log checkpoints from the intel+aki
REM  ComfyUI pack review video (BV1SPno6bE4w):
REM    1) Kitchen XPU backend available      -> operator layer OK
REM    2) DynamicVRAM / AIMDO active         -> OOM protection ON
REM    3) omni_xpu_kernel available          -> low-level kernel OK
REM    4) Omni adapter status mix            -> macro assessment
REM
REM  Usage: BSAI_Omni_HealthCheck.cmd [log_file_path]
REM    (no arg: auto-find latest comfyui_*_console.log under ComfyUI\user)
REM  NOTE: pure-ASCII, no parens/semicolons inside if-blocks.
REM ============================================================

set "ROOT=%~dp0"
set "LOG=%~1"

if not defined LOG (
    pushd "%ROOT%ComfyUI\user"
    for /f "delims=" %%F in ('dir /b /o-d comfyui_*_console.log 2^>nul') do (
        if not defined LOG set "LOG=%ROOT%ComfyUI\user\%%F"
    )
    popd
)

if not defined LOG (
    echo [BSAI] No ComfyUI console log found.
    echo [BSAI] Start the pack first, then run:  %~nx0 ^<log_path^>
    exit /b 1
)
if not exist "%LOG%" (
    echo [BSAI] Log file not found: %LOG%
    exit /b 1
)

echo [BSAI] ============================================================
echo [BSAI]   BSAI Omni Accelerator Health Check  -  ref BV1SPno6bE4w
echo [BSAI]   Log: %LOG%
echo [BSAI] ============================================================
echo.

set "PASS=0"
set "FAIL=0"
set "CUDA_MODE=0"

REM ---- Mode detection: CUDA mode - OmniXPU expected off ----
findstr /c:"OMNIXPU_ENABLE=0" "%LOG%" >nul 2>&1
if !errorlevel! equ 0 set "CUDA_MODE=1"
findstr /c:"No Intel XPU detected, skipping all patches" "%LOG%" >nul 2>&1
if !errorlevel! equ 0 set "CUDA_MODE=1"

if "!CUDA_MODE!"=="1" (
    echo [BSAI] Mode: CUDA main-instance log - OmniXPU not expected, XPU items skipped
) else (
    echo [BSAI] Mode: XPU / Omni-accelerated log
)
echo.

REM ==================== Check 1: Kitchen XPU backend ====================
if "!CUDA_MODE!"=="1" (
    echo [BSAI] [1/4] Kitchen XPU backend : [SKIP] CUDA mode
) else (
    findstr /c:"backend xpu: {'available': True, 'disabled': False" "%LOG%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [BSAI] [1/4] Kitchen XPU backend : [OK] XPU operator channel available
        set /a PASS+=1
    ) else (
        findstr /c:"Found comfy_kitchen backend xpu" "%LOG%" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [BSAI] [1/4] Kitchen XPU backend : [WARN] XPU channel found, state not confirmed
            set /a FAIL+=1
        ) else (
            echo [BSAI] [1/4] Kitchen XPU backend : [FAIL] XPU backend not found - check OMNIXPU_ENABLE=1
            set /a FAIL+=1
        )
    )
)

REM ==================== Check 2: DynamicVRAM / AIMDO ====================
findstr /c:"DynamicVRAM support detected and enabled" "%LOG%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [BSAI] [2/4] DynamicVRAM/AIMDO   : [OK] DynamicVRAM active, OOM protection ON
    set /a PASS+=1
) else (
    findstr /c:"DynamicVRAM model-weight offloading is available" "%LOG%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [BSAI] [2/4] DynamicVRAM/AIMDO   : [OK] OmniXPU took over, dynamic weight offload ready
        set /a PASS+=1
    ) else (
        findstr /c:"DynamicVRAM is disabled" "%LOG%" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [BSAI] [2/4] DynamicVRAM/AIMDO   : [FAIL] DynamicVRAM disabled - AIMDO AmigoXPU patch skipped
            if "!CUDA_MODE!"=="1" (
                echo [BSAI]        Note: CUDA branch defaults to --disable-dynamic-vram - BSAI-AimDo-Fix manages CUDA compat
            ) else (
                echo [BSAI]        Fix: XPU branch defaults to Smart Memory ON - ensure BSAI_DYNAMIC_VRAM is not 0
            )
            set /a FAIL+=1
        ) else (
            findstr /c:"Dynamic vram disabled with argument" "%LOG%" >nul 2>&1
            if !errorlevel! equ 0 (
                echo [BSAI] [2/4] DynamicVRAM/AIMDO   : [FAIL] --disable-dynamic-vram present in launch args
                set /a FAIL+=1
            ) else (
                echo [BSAI] [2/4] DynamicVRAM/AIMDO   : [WARN] no DynamicVRAM status line found
                set /a FAIL+=1
            )
        )
    )
)

REM ==================== Check 3: omni_xpu_kernel ====================
if "!CUDA_MODE!"=="1" (
    echo [BSAI] [3/4] omni_xpu_kernel   : [SKIP] CUDA mode
) else (
    findstr /c:"omni_xpu_kernel" "%LOG%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [BSAI] [3/4] omni_xpu_kernel   : [OK] Kernel load record found
        set /a PASS+=1
    ) else (
        echo [BSAI] [3/4] omni_xpu_kernel   : [FAIL] Kernel load record not found
        set /a FAIL+=1
    )
)

REM ==================== Check 4: Omni adapter status mix ====================
if "!CUDA_MODE!"=="1" (
    echo [BSAI] [4/4] Omni adapters    : [SKIP] CUDA mode
) else (
    findstr /c:"[OmniXPU]" "%LOG%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [BSAI] [4/4] Omni adapters    : [OK] [OmniXPU] log present - review applied/skipped mix manually
        set /a PASS+=1
    ) else (
        echo [BSAI] [4/4] Omni adapters    : [FAIL] [OmniXPU] adapter log not found
        set /a FAIL+=1
    )
)

REM ==================== Version summary ====================
echo.
echo [BSAI] ---- Version summary - from log ----
for /f "delims=" %%L in ('findstr /c:"ComfyUI version" "%LOG%" 2^>nul') do echo [BSAI]   %%L
for /f "delims=" %%L in ('findstr /c:"comfy-aimdo version" "%LOG%" 2^>nul') do echo [BSAI]   %%L
for /f "delims=" %%L in ('findstr /c:"comfy-kitchen version" "%LOG%" 2^>nul') do echo [BSAI]   %%L
for /f "delims=" %%L in ('findstr /c:"omni_xpu_kernel" "%LOG%" 2^>nul') do echo [BSAI]   %%L

echo.
echo [BSAI] Result: !PASS! passed / !FAIL! attention
if !FAIL! equ 0 (
    echo [BSAI] Verdict: all Omni accelerator checkpoints passed.
) else (
    echo [BSAI] Verdict: items need attention - follow the hints above.
    echo [BSAI] Ref BV1SPno6bE4w - if speed is off, check these points first.
)
echo.
pause