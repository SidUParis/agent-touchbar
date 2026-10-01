# 🛡️ Agent Touch Bar

> **Ultra-lightweight, zero-CPU native macOS Touch Bar approval controller for AI Coding Agents.**  
> Designed for **Anti Gravity**, **VS Code**, **OpenAI Codex**, and **Claude Code**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS%2012%2B-lightgrey.svg)](https://apple.com)
[![Language: Objective-C](https://img.shields.io/badge/Language-Objective--C-orange.svg)]()
[![RAM: ~8MB](https://img.shields.io/badge/RAM-~8%20MB-brightgreen.svg)]()
[![Idle CPU: 0.0%](https://img.shields.io/badge/Idle%20CPU-0.0%25-brightgreen.svg)]()

When AI Coding Agents (such as Claude Code, Codex, or Anti Gravity) request tool execution permissions (running shell commands, modifying critical files, web scraping), `Agent Touch Bar` instantly presents a modern, physical **Touch Bar Approval Strip**. Tap once to allow or reject without moving your mouse or losing focus!

```text
┌─────┬──────────────────────────┬────────────────────────────────────────────┐
│ esc │  ✨ Agent Request        │  ✓ Allow ⏎ │ ① Once │ ② Always │ ✕ Reject ⎋ │
└─────┴──────────────────────────┴────────────────────────────────────────────┘
```

---

## ⚡ Highlights & Minimal Cost

- **0.00% Idle CPU**: Pure event-driven kernel `kqueue` / `DispatchSource` waiting. Zero polling, zero wakeups, maximum battery savings.
- **0.00% Idle GPU**: Zero Metal/OpenGL pipelines; uses native macOS AppKit system vector controls.
- **~8 MB Resident RAM**: Native ARC machine code without Python/Go/Node runtime overhead.
- **Sub-2ms Latency**: Physical tap injects simulated keystrokes directly into the frontmost window via CoreGraphics.
- **100% Headless**: No menu bar icon clutter, no Dock icon. Quietly stays in the background until invoked.
- **Apple HIG Design**: Native SF Symbols (`checkmark`, `xmark`, `1.circle`, `2.circle`, `sparkles`) with refined macOS semantic colors.

---

## 🎮 Button Actions & Mapping

| Button | Key Injected | Primary Target | Behavior |
| :--- | :--- | :--- | :--- |
| **✓ Allow ⏎** | `Return` (36) | **Anti Gravity**, **VS Code**, **Codex Desktop** | Approves the active modal dialog or command execution prompt. |
| **① Once** | `1` (18) | **Claude Code** CLI / Desktop | Selects "Allow Once". |
| **② Always** | `2` (19) | **Claude Code** CLI / Desktop | Selects "Always Allow". |
| **✕ Reject ⎋** | `Escape` (53) | **All Agents** | Rejects or dismisses the requested tool execution. |

*Tapping any button automatically injects the key into the active window and immediately dismisses the Touch Bar.*

---

## 🚀 How to Trigger

### 1. Global Hotkey (For Desktop Apps)
Whenever you see a confirmation modal on screen in **Anti Gravity**, **VS Code**, or **Codex**:
- Press **`⇧⌘A` (`Shift + Command + A`)**
- The Touch Bar immediately lights up with the approval strip. Tap **✓ Allow ⏎** with your thumb!

### 2. Auto-Trigger (Claude Code)
When running Claude Code in the terminal, the included hook automatically detects permission notifications and presents the Touch Bar without requiring any manual hotkey.

### 3. CLI Script Trigger
Any terminal script or CI agent can trigger the Touch Bar:
```bash
tb-ask "Anti Gravity: Run build test?"
```

---

## 📦 Quick Installation

Clone and install with the included automated script:

```bash
git clone https://github.com/SidUParis/agent-touchbar.git
cd agent-touchbar
./install.sh
```

### 🔐 One-time Accessibility Permission
Because `Agent Touch Bar` posts keystrokes (`Return` / `Escape`) to the frontmost application:
1. Open **System Settings** → **Privacy & Security** → **Accessibility**.
2. Enable / toggle on **`AgentTouchBar`**.

---

## 🛠️ Uninstallation

To completely remove the background service and binaries:

```bash
./uninstall.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
