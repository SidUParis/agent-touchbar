#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.agent-touchbar.plist"

echo "🔨 正在编译精致原生版 Agent Touch Bar..."
cd "$DIR"
make clean && make

mkdir -p "$BIN_DIR" "$APP_DIR" "$HOME/Library/LaunchAgents"

rm -rf "$APP_DIR/AgentTouchBar.app"
cp -R build/AgentTouchBar.app "$APP_DIR/"
cp -f tb-ask "$BIN_DIR/tb-ask"
chmod +x "$BIN_DIR/tb-ask"

echo "📦 已安装应用到 $APP_DIR/AgentTouchBar.app"
echo "📦 已安装 CLI 触发器到 $BIN_DIR/tb-ask"

# Stop existing service
launchctl bootout "gui/$(id -u)/com.user.agent-touchbar" 2>/dev/null || pkill -9 AgentTouchBar 2>/dev/null || true

# Generate LaunchAgent plist
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.agent-touchbar</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_DIR/AgentTouchBar.app/Contents/MacOS/AgentTouchBar</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/agent_touchbar.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/agent_touchbar.log</string>
</dict>
</plist>
EOF

echo "🚀 注册并启动纯后台无图标服务..."
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || open "$APP_DIR/AgentTouchBar.app"

if [ -d "$HOME/.claude" ]; then
    "$DIR/claude-hook-install.sh"
fi

echo ""
echo "🎉 安装完成！Agent Touch Bar 已作为纯后台守护进程静默运行（无任何菜单栏/Dock图标）。"
