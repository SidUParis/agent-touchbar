#!/bin/bash
set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.user.agent-touchbar.plist"
BIN_DIR="$HOME/.local/bin"

echo "🛑 停止 Agent Touch Bar 服务..."
launchctl bootout "gui/$(id -u)/com.user.agent-touchbar" 2>/dev/null || pkill -x agent-touchbar-daemon 2>/dev/null || true

rm -f "$PLIST_PATH"
rm -f "$BIN_DIR/agent-touchbar-daemon" "$BIN_DIR/tb-ask" "$BIN_DIR/tb-claude-relay"
rm -f /tmp/agent_touchbar.sock /tmp/agent_touchbar.log

echo "✅ Agent Touch Bar 已完全卸载。"
