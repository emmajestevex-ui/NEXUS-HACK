@echo off
setlocal
cd /d "%~dp0"
title NEXUS - subida automatica a GitHub
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\NEXUS-GitHub-Bot.ps1" -Watch -OpenGitHubDesktop
pause
