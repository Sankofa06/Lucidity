# Fleet/deploy/windows/restart-services.ps1
#
# What: Restart the Lucidity scheduled tasks on the Windows box.
# Touched by: GitLab deploy job or run manually after pulling updates.

$ErrorActionPreference = 'SilentlyContinue'
foreach ($name in @('opencode-serve', 'comfyui')) {
    $task = Get-ScheduledTask -TaskPath '\Lucidity\' -TaskName $name
    if ($task) {
        Stop-ScheduledTask -TaskPath '\Lucidity\' -TaskName $name
        Start-ScheduledTask -TaskPath '\Lucidity\' -TaskName $name
        Write-Host "restarted \Lucidity\$name"
    }
}
