@echo off
REM 一键运行单元测试（在 PowerShell / cmd 中执行： run_tests.bat）
cd /d "%~dp0"
matlab -batch "addpath(fullfile(pwd,'tests')); test_ber_uncoded; test_turbo_awgn"
if errorlevel 1 (
    echo.
    echo [ERROR] 测试未通过，请查看上方 MATLAB 输出。
    pause
)
