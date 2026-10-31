#!/usr/bin/env bash
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./tools/NEXUS-GitHub-Bot.ps1" -Watch -OpenGitHubDesktop
