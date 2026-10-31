@echo off
setlocal
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0NEXUS-GitHub-Bot.ps1" -Watch
pause
