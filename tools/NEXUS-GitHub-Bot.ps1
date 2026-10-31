[CmdletBinding()]
param(
    [string]$RepoPath = "",
    [string]$Message = "Actualiza NEXUS",
    [switch]$Watch,
    [int]$IntervalSeconds = 15,
    [switch]$DryRun,
    [switch]$OpenGitHubDesktop
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Split-Path -Parent $PSScriptRoot
}

function Invoke-Git([string[]]$Arguments) {
    Push-Location -LiteralPath $RepoPath
    try {
        & git @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Git terminó con código ${LASTEXITCODE}: git $($Arguments -join ' ')"
        }
    } finally {
        Pop-Location
    }
}

function Get-GitOutput([string[]]$Arguments) {
    Push-Location -LiteralPath $RepoPath
    try {
        $output = & git @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Git terminó con código ${LASTEXITCODE}: git $($Arguments -join ' ')"
        }
        return ($output -join "`n")
    } finally {
        Pop-Location
    }
}

function Push-NexusChanges {
    $status = Get-GitOutput @("status", "--porcelain")
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "NEXUS: no hay cambios nuevos."
        return $false
    }

    $branch = (Get-GitOutput @("branch", "--show-current")).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "El repositorio está en detached HEAD. Cámbialo a la rama main antes de usar el bot."
    }

    Write-Host "NEXUS: cambios detectados en $branch."
    if ($DryRun) {
        Write-Host $status
        return $true
    }

    Invoke-Git @("add", "-A")
    Invoke-Git @("commit", "-m", $Message)
    Invoke-Git @("push", "origin", $branch)
    Write-Host "NEXUS: cambios subidos. GitHub Actions se iniciará automáticamente por el push."
    return $true
}

function Open-GitHubDesktop {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "GitHubDesktop\GitHubDesktop.exe"),
        (Join-Path $env:ProgramFiles "GitHub Desktop\GitHub Desktop.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "GitHub Desktop\GitHub Desktop.exe")
    )
    $desktop = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if ($desktop) {
        Start-Process -FilePath $desktop -ArgumentList $RepoPath
        Write-Host "NEXUS: GitHub Desktop abierto con este repositorio."
    } else {
        Write-Host "NEXUS: GitHub Desktop no está instalado; el bot seguirá usando Git automáticamente."
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $RepoPath ".git"))) {
    throw "No encontré un repositorio Git en $RepoPath"
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git no está instalado o no está disponible en PATH."
}
if ($OpenGitHubDesktop) { Open-GitHubDesktop }

if (-not $Watch) {
    [void](Push-NexusChanges)
    exit 0
}

Write-Host "NEXUS: modo automático activo. Revisando cada $IntervalSeconds segundos."
Write-Host "Pulsa Ctrl+C para detenerlo."
$lastStatus = ""
while ($true) {
    try {
        $currentStatus = Get-GitOutput @("status", "--porcelain")
        if ($currentStatus -ne $lastStatus) {
            $lastStatus = $currentStatus
            if (-not [string]::IsNullOrWhiteSpace($currentStatus)) {
                Start-Sleep -Seconds 3
                [void](Push-NexusChanges)
                $lastStatus = Get-GitOutput @("status", "--porcelain")
            }
        }
    } catch {
        Write-Warning "NEXUS: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds ([Math]::Max(5, $IntervalSeconds))
}
