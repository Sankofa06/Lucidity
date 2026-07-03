#!/usr/bin/env bash
# Fleet/deploy/macos/restart-services.sh
#
# What: Restart whichever Lucidity LaunchAgents are installed on this Mac.
# Does: kickstart -k restarts only units that exist, so the same script works
#       on the Mini (all three) and the MacBook (opencode only).
# Touched by: GitLab deploy jobs after a build, or run manually.

set -euo pipefail
UID_NUM="$(id -u)"
for label in com.lucidity.opencode com.lucidity.orchestrator com.lucidity.mcp-diffusion; do
    if [ -f "$HOME/Library/LaunchAgents/$label.plist" ]; then
        launchctl kickstart -k "gui/$UID_NUM/$label" && echo "restarted $label"
    fi
done
