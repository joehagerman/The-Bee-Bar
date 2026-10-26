<p align="center">
  <img src="assets/logo.png" width="120" alt="The Bee Bar Logo" />
</p>

<h1 align="center">The Bee Bar</h1>

<p align="center">
  <strong>Native macOS Menu Bar Companion and Export Utility for Bee.computer</strong>
</p>

<p align="center">
  <a href="https://github.com/joehagerman/The-Bee-Bar/releases/latest/download/The-Bee-Bar-macOS.zip">
    <img src="https://img.shields.io/badge/Download-The_Bee_Bar_v1.0.0_(macOS)-blue?style=for-the-badge&logo=apple" alt="Download The Bee Bar">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS_13.0+-lightgrey?style=flat-square" alt="Platform: macOS 13.0+">
  <img src="https://img.shields.io/badge/Architecture-Universal_(Apple_Silicon_%26_Intel)-lightgrey?style=flat-square" alt="Architecture: Universal">
  <img src="https://img.shields.io/badge/Language-Swift_6-orange?style=flat-square" alt="Language: Swift 6">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License: MIT">
</p>

---

<p align="center">
  <img src="assets/screenshot.png" width="460" alt="The Bee Bar Interface" />
</p>

---

## Overview

**The Bee Bar** is a lightweight, native macOS status bar utility designed for users of the [Bee.computer](https://bee.computer) wearable microphone and assistant.

Running quietly in the macOS menu bar (`LSUIElement`), The Bee Bar synchronizes audio recordings, conversational transcripts, executive summaries, journals, action items, and memory facts into clean local Markdown (`.md`) and raw JSON (`.json`) files. It also integrates directly with the Google Gemini API to generate customized, high-impact executive summaries on demand.

---

## Direct Download

| Version | Target Platform | Archive |
|:---|:---|:---|
| **v1.0.0** | macOS 13.0 or later (Apple Silicon & Intel) | [**Download The-Bee-Bar-macOS.zip**](https://github.com/joehagerman/The-Bee-Bar/releases/latest/download/The-Bee-Bar-macOS.zip) |

All official releases and change notes are available on the [GitHub Releases Page](https://github.com/joehagerman/The-Bee-Bar/releases).

---

## Key Capabilities

### 1. Continuous Background Synchronization
- Automatically polls Bee's servers at configurable intervals: 1 minute, 5 minutes, 15 minutes, Daily (24 hours), Weekly, or Manual Only.
- Updates file timestamps on downloaded Markdown and JSON files to match the exact historical date and time the conversation occurred.
- Maintains a local index (`metadata.json`) for fast lookup without redundant network requests.

### 2. Dual Connection Modes
- **Local Proxy Mode (Recommended)**: Automatically interfaces with `bee proxy` on `http://127.0.0.1:8787`. No API tokens or manual secret management required.
- **Direct Cloud API Mode**: Connects directly to the Bee developer endpoint (`https://api.developer.bee.amazon.dev`) using Bearer token authentication.

### 3. One-Click Clipboard Actions
Every conversation entry in the menu bar dropdown includes an action submenu:
- **Copy Summary**: Extracts only the clean executive summary section without verbatim audio turns.
- **Copy Transcript**: Copies the complete verbatim dialogue transcript directly to the clipboard.
- **Copy Gemini Summary**: Sends the transcript to Google Gemini, displays a 3-stage progress modal with a 5-second countdown bar, and copies the full returned response to the clipboard.
- **Open Markdown (.md)**: Opens the formatted report in your default editor (Obsidian, Mac Notes, VS Code, or Bear).
- **Open Transcript (.txt)**: Opens the raw verbatim transcript in TextEdit.
- **Reveal in Finder**: Locates the file in macOS Finder.

### 4. Google Gemini AI Integration
- **Dynamic Model Selection**: Queries the Google API to list available text models (including `gemini-2.5-flash`, `gemini-3.8-flash`, and `gemini-2.5-pro`).
- **Customizable Pre-Prompt**: Configure the exact executive instruction prepended to transcripts in Preferences, with an instant "Reset to Default" button.
- **Full Payload Retention**: Configured with extended token output limits (`maxOutputTokens: 8192`) to prevent thinking tokens from truncating the final summary.

### 5. Hover Summary Inspection
Hovering over any conversation item in the menu displays a floating, non-activating summary panel on the left side of the screen, allowing you to read full executive briefs without clicking.

---

## Step-by-Step Installation & Setup

### Step 1: Install the Application
1. Download [**The-Bee-Bar-macOS.zip**](https://github.com/joehagerman/The-Bee-Bar/releases/latest/download/The-Bee-Bar-macOS.zip).
2. Uncompress the archive and drag `The Bee Bar.app` into your macOS `/Applications` directory.
3. Open `The Bee Bar`. A striped bee icon will appear in the top-right macOS menu bar.

### Step 2: Configure Bee Connection

#### Option A: Local Proxy Mode (Recommended)
1. Install the Bee CLI if not already present on your Mac:
   ```bash
   npm install -g @bee-computer/cli
   ```
2. Log in using the terminal QR code:
   ```bash
   bee login --qr
   ```
   Open your Bee mobile app, navigate to **Settings**, and scan the QR code displayed in your terminal.
3. Start the local proxy:
   ```bash
   bee proxy
   ```
   Keep this terminal process running.
4. Click **The Bee Bar** menu icon &rarr; **Preferences...** &rarr; select **Local Proxy (8787)**.
5. Click **Verify Connection (GET /v1/me)** to confirm pairing, then click **Save Settings**.

#### Option B: Public Cloud API Mode
1. In your Bee mobile app, open **Settings** &rarr; tap the version number 5 times to enable **Developer Mode** &rarr; copy your Bearer token.
2. In The Bee Bar Preferences, select **Public Cloud API**.
3. Paste your token into the **Bearer Token** field.
4. Click **Verify Connection (GET /v1/me)** and click **Save Settings**.

### Step 3: Configure Google Gemini AI (Optional)
1. In Preferences, switch to the **Gemini AI** tab.
2. Enter your Google Gemini API key (obtained from [Google AI Studio](https://aistudio.google.com)).
3. Click **Fetch Models** to populate available model versions and select your preferred model.
4. (Optional) Customize the Pre-Prompt instructions to tailor the tone and section headers of your executive summaries.
5. Click **Save Settings**.

---

## Local Storage Layout

All data is stored locally on your Mac (default path: `~/Documents/Bee Exports`):

```text
~/Documents/Bee Exports/
  ├── conversations/
  │     ├── conv_<id>.md         Formatted Markdown with summary and speaker dialogue
  │     ├── conv_<id>.json       Full raw JSON payload from Bee API
  │     └── conv_<id>_gemini.md  Cached Gemini AI executive summaries
  ├── transcripts/
  │     ├── <id>_transcript.txt  Plain-text verbatim audio transcript
  │     └── <id>_transcript.md  Markdown verbatim audio transcript
  ├── daily/
  │     ├── daily_<date>.md      Daily morning/evening recap briefs
  │     └── daily_<date>.json
  ├── journals/
  │     ├── journal_<id>.md      Reflections and journal entries
  │     └── journal_<id>.json
  ├── todos/
  │     ├── todos.md             Extracted action items checklist
  │     └── todos.json
  ├── facts/
  │     ├── facts.md             Memory bank facts summary
  │     └── facts.json
  └── metadata.json              Fast local index with parsed timestamps
```

User preferences and credentials are saved in `~/.bee-desktop/config.json` in your home directory, completely isolated from project code.

---

## Codebase Architecture & Source Reference

The source code for the native macOS application is located in `BeeBar/Sources/BeeBar/`:

| Source File | Description |
|:---|:---|
| `main.swift` | Application entry point configuring NSApplication activation policy and lifecycle. |
| `AppDelegate.swift` | Manages `NSStatusItem`, dynamic menu construction, hover tooltips, and action handlers. |
| `BeeIcon.swift` | Renders and caches the custom 22x22 template menu bar icon. |
| `BeeModels.swift` | Strongly-typed Codable structures for Bee conversations, utterances, timestamps, and metadata. |
| `BeeStore.swift` | Observable state store coordinating background sync timers and local data reloading. |
| `BeeSyncEngine.swift` | HTTP client handling Bee REST API endpoints, date matching, and file serialization. |
| `ConfigManager.swift` | Manages reading and atomic non-destructive writing of `~/.bee-desktop/config.json`. |
| `GeminiService.swift` | Client for Google Gemini generateContent and model list APIs with thinking token resilience. |
| `GeminiProgressModal.swift` | Floating AppKit HUD modal presenting 3-stage progress and 0-5s auto-dismiss progress bar. |
| `SettingsView.swift` | SwiftUI preferences panel with tabbed navigation, proxy setup guide, and pre-prompt editor. |
| `SummaryPreviewPanel.swift` | Non-activating floating panel displaying conversation summaries upon hover. |

---

## Building from Source

To compile and package The Bee Bar from source:

```bash
# Clone the repository
git clone https://github.com/joehagerman/The-Bee-Bar.git
cd The-Bee-Bar/BeeBar

# Compile production binary with Swift Package Manager
swift build -c release

# Package the standalone application bundle
./package-app.sh

# Install into /Applications
cp -R BeeBar.app "/Applications/The Bee Bar.app"
```

---

## License

This project is licensed under the [MIT License](LICENSE).
