# The Bee Bar - Native macOS Menu Bar Utility

The Bee Bar is a native, lightweight macOS menu bar utility designed for the `bee.computer` wearable device and developer API. It resides in the macOS status bar, continuously synchronizes records in the background, and provides instant access to conversation summaries, audio transcripts, and AI-powered executive briefs.

---

## Capabilities

- **Native macOS Status Item**:
  - Operates as a persistent menu bar accessory (`LSUIElement = true`).
  - Native SwiftUI and AppKit implementation compiled in Swift 6.
  - Minimal memory footprint (~50 MB RAM).

- **Continuous Background Synchronization**:
  - Polls the local proxy (`http://127.0.0.1:8787`) or public API (`https://api.developer.bee.amazon.dev`) at configurable intervals (1 min, 5 min, 15 min, 24 hours, or manual).
  - Downloads conversations, executive summaries, and verbatim transcripts into `~/Documents/Bee Exports/`.
  - Maintains a local search index at `metadata.json` with matching file creation and modification timestamps.

- **One-Click Clipboard Operations**:
  - **Copy Summary**: Copies the clean executive summary section without transcripts.
  - **Copy Transcript**: Copies verbatim dialogue text.
  - **Copy Gemini Summary**: Summarizes the transcript with Google Gemini using configurable models and custom pre-prompts, copying the complete structured brief to clipboard.

- **Hover Preview Panel**:
  - Displays a clean floating preview panel on hover showing the full summary of the hovered conversation.

---

## Installation & Running

Download the pre-compiled application bundle from GitHub Releases:
- Download `The-Bee-Bar-macOS.zip` from [Releases](https://github.com/joehagerman/The-Bee-Bar/releases).
- Move `The Bee Bar.app` to `/Applications`.
- Launch the application. The menu bar icon will appear in the top-right status bar.

---

## Building from Source

### Prerequisites
- macOS 13.0 or later
- Xcode 15+ / Command Line Tools (`swift --version`)

### Compilation Commands
```bash
cd BeeBar
swift build -c release
./package-app.sh
cp -R BeeBar.app /Applications/BeeBar.app
```
