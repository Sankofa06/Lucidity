#!/usr/bin/env bash
# Fleet/deploy/macos/install.sh
#
# What: macOS service installer for the Lucidity Fleet.
# Does: Substitutes paths into the launchd plist templates and (re)loads them
#       as LaunchAgents for the current user.
# Usage:
#   ./install.sh opencode                 # every Mac: opencode serve on :4096
#   ./install.sh orchestrator             # Mac Mini only
#   ./install.sh mcp-diffusion COMFY_URL  # Mac Mini only, e.g.
#       ./install.sh mcp-diffusion http://your-rtx-box.your-tailnet.ts.net:8188
# Touches: ~/Library/LaunchAgents, ~/Library/Logs/lucidity.
# Touched by: run manually or by the GitLab deploy jobs.

set -euo pipefail

UNIT="${1:?usage: install.sh <opencode|orchestrator|mcp-diffusion> [comfy_url]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
NODE_BIN="$(command -v node)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$AGENTS_DIR" "$HOME/Library/Logs/lucidity"

render_and_load() {
    local label="$1" template="$2" comfy_url="${3:-}"
    local target="$AGENTS_DIR/$label.plist"
    sed -e "s|__NODE__|$NODE_BIN|g" \
        -e "s|__REPO__|$REPO|g" \
        -e "s|__HOME__|$HOME|g" \
        -e "s|__COMFY_URL__|$comfy_url|g" \
        -e "s|__OPENCODE__|$(command -v opencode || echo /opt/homebrew/bin/opencode)|g" \
        "$template" > "$target"
    launchctl unload "$target" 2>/dev/null || true
    launchctl load "$target"
    echo "loaded $label ($target)"
}

case "$UNIT" in
    opencode)
        command -v opencode >/dev/null || {
            echo "opencode not found — install it first: brew install anomalyco/tap/opencode (or npm i -g opencode-ai)"
            exit 1
        }
        render_and_load com.lucidity.opencode "$HERE/com.lucidity.opencode.plist"
        ;;
    orchestrator)
        [ -f "$REPO/LocalDev/fleet.local.json" ] || {
            echo "Missing $REPO/LocalDev/fleet.local.json — copy Fleet/config/fleet.example.json and fill in real tailnet hosts."
            exit 1
        }
        render_and_load com.lucidity.orchestrator "$HERE/com.lucidity.orchestrator.plist"
        ;;
    mcp-diffusion)
        COMFY_URL="${2:?usage: install.sh mcp-diffusion http://<comfy-host>:8188}"
        render_and_load com.lucidity.mcp-diffusion "$HERE/com.lucidity.mcp-diffusion.plist" "$COMFY_URL"
        ;;
    *)
        echo "unknown unit: $UNIT"
        exit 1
        ;;
esac
