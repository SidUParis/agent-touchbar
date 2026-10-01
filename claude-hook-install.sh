#!/bin/bash
set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
RELAY_SCRIPT="$HOME/.local/bin/tb-claude-relay"

mkdir -p "$HOME/.local/bin" "$HOME/.claude"

cat > "$RELAY_SCRIPT" <<'EOF'
#!/bin/bash
SOCKET="/tmp/agent_touchbar.sock"
if [ -S "$SOCKET" ]; then
  # Read hook JSON payload from stdin
  PAYLOAD=$(cat)
  # Extract notification or session info if jq is available, or send generic prompt
  MSG="Claude Code 权限请求"
  if command -v jq >/dev/null 2>&1; then
    NOTIF=$(echo "$PAYLOAD" | jq -r '.notification // .message // empty' 2>/dev/null || true)
    if [ -n "$NOTIF" ]; then
      MSG="Claude: $NOTIF"
    fi
  fi
  printf "%s" "$MSG" | /usr/bin/nc -U -w 1 "$SOCKET" 2>/dev/null || true
fi
exit 0
EOF

chmod +x "$RELAY_SCRIPT"

python3 - "$SETTINGS_FILE" "$RELAY_SCRIPT" <<'PYEOF'
import json, os, sys

settings_path, relay = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        settings = {}

hooks = settings.setdefault("hooks", {})
relay_hook = {"type": "command", "command": relay}

for event in ["Notification", "Stop"]:
    entries = hooks.setdefault(event, [])
    already = any(
        h.get("command") == relay
        for entry in entries
        for h in entry.get("hooks", [])
    )
    if not already:
        entries.append({"hooks": [relay_hook]})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
print("✅ Claude Code hook registered in " + settings_path)
PYEOF

echo "Done! Claude Code will now automatically pop up Touch Bar when asking for permissions."
