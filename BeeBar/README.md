# 🐝 BeeBar - Native macOS Menu Bar Companion

**BeeBar** is a native, ultra-lightweight macOS menu bar utility for your `bee.computer` device. It lives in your macOS menu bar with a 🐝 icon, continuously keeps your Bee records up to date in the background, and gives you instant one-click access to your latest executive summaries, audio transcripts, and export folders.

---

## ✨ Features

- **Native macOS Menu Bar App**:
  - Zero-dock footprint (`LSUIElement = true`).
  - Sits quietly in the top right menu bar.
  - Native SwiftUI & AppKit implementation compiled in Swift 6.
  - Uses only ~50 MB RAM (unlike heavyweight web or Electron wrappers).

- **Continuous Background Sync**:
  - Automatically polls your local proxy (`http://127.0.0.1:8787`) or public API (`https://api.developer.bee.amazon.dev`) every N minutes (configurable: 1m, 5m, 15m, 30m, 1h).
  - Also includes an instant **"Sync Now"** button with a live progress bar.
  - Downloads conversations, executive summaries, and verbatim transcripts into `~/Documents/Bee Exports/`.
  - Reuses the shared configuration file `~/.bee-desktop/config.json` and updates `metadata.json` so your Desktop app and Menu Bar app are always in sync.

- **Instant Executive Summaries & Transcripts**:
  - Displays the latest conversations with turn counts, durations, and topic badges (`🏷️ Grants & Contracts`, `🏷️ Grid Resilience`, etc.).
  - 📋 **Summary (.md)**: Opens formatted Markdown executive summary directly in your default app (Obsidian, Mac Notes, etc.).
  - 🎙️ **Transcript (.txt)**: Opens pure verbatim audio transcript text in TextEdit.
  - 🔍 **Finder**: Reveals the files in Finder.

- **Quick Links**:
  - 📂 **Open in Finder**: One-click jump to `~/Documents/Bee Exports`.
  - ⚙️ **Settings**: Easily change connection mode (Local Proxy vs Public API), Bearer token, sync interval, and exports directory.

---

## 🚀 How to Run

BeeBar is already compiled and installed at:
- `/Applications/BeeBar.app`
- `/Users/joehagerman/Desktop/Bee Desktop/BeeBar/BeeBar.app`

You can launch it anytime by:
1. Double-clicking **BeeBar** in `/Applications` or Spotlight search (`Cmd + Space` -> `BeeBar`).
2. Or running from the terminal:
   ```bash
   open /Applications/BeeBar.app
   ```

Look for the 🐝 icon in the top right of your macOS menu bar!

---

## 🛠 Rebuilding from Source

To compile and package a new release:
```bash
cd "/Users/joehagerman/Desktop/Bee Desktop/BeeBar"
swift build -c release
./package-app.sh
cp -R BeeBar.app /Applications/BeeBar.app
```
