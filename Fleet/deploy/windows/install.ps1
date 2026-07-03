# Fleet/deploy/windows/install.ps1
#
# What: Windows service installer for the Lucidity Fleet (RTX 4070 box).
# Does: Registers Scheduled Tasks that start at logon and keep running:
#         - opencode serve on :4096 (bound to 0.0.0.0 inside the tailnet)
#         - optionally ComfyUI with --listen so the MCP diffusion server
#           (on the Mac Mini) can reach it.
# Usage (elevated PowerShell):
#   .\install.ps1 -Unit opencode
#   .\install.ps1 -Unit comfyui -ComfyDir 'C:\ComfyUI' -ComfyPython 'C:\ComfyUI\venv\Scripts\python.exe'
# Touches: Task Scheduler (\Lucidity\ folder), %USERPROFILE%\lucidity-logs.
# Touched by: run manually or by the GitLab deploy job on this machine.

param(
    [Parameter(Mandatory = $true)][ValidateSet('opencode', 'comfyui')] [string]$Unit,
    [string]$ComfyDir = 'C:\ComfyUI',
    [string]$ComfyPython = 'C:\ComfyUI\venv\Scripts\python.exe'
)

$ErrorActionPreference = 'Stop'
$logDir = Join-Path $env:USERPROFILE 'lucidity-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Register-LucidityTask {
    param([string]$Name, [string]$Exe, [string]$Arguments, [string]$WorkDir)
    $action = New-ScheduledTaskAction -Execute $Exe -Argument $Arguments -WorkingDirectory $WorkDir
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet `
        -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Days 3650) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskPath '\Lucidity\' -TaskName $Name `
        -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskPath '\Lucidity\' -TaskName $Name
    Write-Host "registered + started \Lucidity\$Name"
}

switch ($Unit) {
    'opencode' {
        $opencode = (Get-Command opencode -ErrorAction SilentlyContinue).Source
        if (-not $opencode) {
            throw 'opencode not found on PATH — install it first (npm i -g opencode-ai)'
        }
        Register-LucidityTask -Name 'opencode-serve' -Exe $opencode `
            -Arguments 'serve --hostname 0.0.0.0 --port 4096' `
            -WorkDir $env:USERPROFILE
    }
    'comfyui' {
        if (-not (Test-Path $ComfyPython)) {
            throw "ComfyUI python not found at $ComfyPython — pass -ComfyPython"
        }
        # --listen 0.0.0.0 exposes ComfyUI to the tailnet only (no public route).
        Register-LucidityTask -Name 'comfyui' -Exe $ComfyPython `
            -Arguments 'main.py --listen 0.0.0.0 --port 8188' `
            -WorkDir $ComfyDir
    }
}
