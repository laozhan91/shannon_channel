@echo off
REM 一键运行仿真（在 PowerShell / cmd 中执行： run_main.bat）
REM 等价于在 MATLAB 命令行里执行 main_simulation
cd /d "%~dp0"
matlab -batch "main_simulation"
if errorlevel 1 (
    echo.
    echo [ERROR] 仿真运行失败，请查看上方 MATLAB 报错信息。
    pause
)
