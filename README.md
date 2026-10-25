# 🐝 Bee Desktop Companion

A native macOS desktop application designed for **Bee.computer** users with Developer Mode enabled. 

Connect to your Bee account, download all your conversational audio transcripts, executive summaries, journals, action items, and facts, and browse or export them in both human-readable GitHub-flavored Markdown (`.md`) and raw JSON (`.json`).

---

## ✨ Key Features

### 1. 🔑 Flexible Bee Authentication & Login
- **Public API Endpoint (Recommended)**: Connect directly to `https://api.developer.bee.amazon.dev` using your `$BEE_TOKEN` Bearer token.
- **Local Proxy Mode**: Automatic detection and integration with `bee proxy` running on `http://127.0.0.1:8787` (zero credentials needed when proxying).
- **Profile Verification**: Live verification test calling `GET /v1/me` to display your user name, email, and device ID.
- **Offline / Sample Data Mode**: Built-in realistic sample data so you can test drive the full application immediately even before connecting your device.

### 2. 📥 Full Sync & Downloader Engine
- **One-Click Sync**: Downloads and updates all your Bee records:
  - 💬 **Conversations & Transcripts** (`GET /v1/conversations` & `/v1/conversations/:id`)
  - 🌅 **Daily Executive Summaries** (`GET /v1/daily` & `/v1/daily/:id`)
  - 📖 **Journals & Reflections** (`GET /v1/journals` & `/v1/journals/:id`)
  - ✅ **Action Items & Todos** (`GET /v1/todos`)
  - 💡 **Facts & Memory Bank** (`GET /v1/facts`)
- **Live Progress Reporting**: Progress bar, active download item indicators, and error resilience.
- **Incremental Sync**: Keeps track of timestamps and changes.

### 3. 📂 Open File Storage & Multi-Format Exports
- All downloaded files are saved locally on your Mac into an organized directory (default: `~/Documents/Bee Exports`):
  ```text
  Bee Exports/
    ├── conversations/
    │     ├── conv_<id>.md    <-- Clean Markdown with Executive Summary & Speaker turns
    │     └── conv_<id>.json  <-- Full raw API payload
    ├── daily/
    │     ├── daily_<date>.md <-- Morning/evening briefs & daily executive summaries
    │     └── daily_<date>.json
    ├── journals/
    │     ├── journal_<id>.md
    │     └── journal_<id>.json
    ├── todos/
    │     ├── todos.md        <-- Formatted checklist
    │     └── todos.json
    ├── facts/
    │     ├── facts.md        <-- Memory bank summary
    │     └── facts.json
    └── metadata.json         <-- Quick search index
  ```
- **Obsidian & Notion Friendly**: Every `.md` file is generated with YAML frontmatter tags, headers, bulleted lists, and speaker quote blocks.
- **1-Click Actions**:
  - `Open .md`: Opens the conversation directly in your default macOS Markdown editor (Obsidian, Mac Notes, VS Code, Bear).
  - `JSON`: Inspect the raw payload.
  - `Finder`: Reveals the selected file directly in macOS Finder.
  - `Export All as ZIP`: Bundles your entire Bee history into a single backup ZIP file.

### 4. 🔍 Instant Global Full-Text Search
- Instant client-side search across all transcripts, summaries, action items, and memories with keyword highlighting.

---

## 🚀 Getting Started

### Prerequisites
- macOS (Apple Silicon or Intel)
- Node.js (v18 or newer)

### Running the App

In the project folder (`/Users/joehagerman/Desktop/Bee Desktop`), run:

```bash
# Option 1: Start using npm
npm start

# Option 2: Run using the helper script
./run.sh
```

---

## 🔐 How to Connect Your Bee Account

### Method A: Direct Public API (Default)
1. In the Bee Desktop app, click **Settings & Auth** in the sidebar.
2. Select **Public API Endpoint** (`https://api.developer.bee.amazon.dev`).
3. Enter your Bee Bearer Token (found in your Bee developer settings or from `curl` tests).
4. Click **Verify Connection (GET /v1/me)** to test your login.
5. Click **Save Configuration**.
6. Click **Sync Now** in the top title bar to download your data!

### Method B: Via `bee proxy`
If you already use the Bee CLI on your computer:
1. Start the proxy in your terminal:
   ```bash
   bee proxy
   ```
2. In the Bee Desktop app, navigate to **Settings & Auth**.
3. Select **Local Proxy** (`http://127.0.0.1:8787`).
4. Click **Verify Connection** and then **Save Configuration**.

---

## 🛠️ Project Structure

- `src/main/main.js`: Electron main process, IPC handlers, native macOS dialogs, window management.
- `src/main/sync-engine.js`: HTTP synchronization engine handling Bee endpoints, error handling, rate limiting, and ZIP archiving.
- `src/main/markdown-formatter.js`: Formats Bee conversational objects into clean, elegant Markdown documents with frontmatter and transcript dialogue.
- `src/preload/preload.js`: Secure IPC context bridge exposing `window.beeAPI`.
- `src/renderer/index.html`: Three-pane desktop UI layout.
- `src/renderer/styles.css`: macOS dark theme styling inspired by Bee's signature warm amber and obsidian slate aesthetic.
- `src/renderer/app.js`: Client-side reactivity, tab navigation, search filtering, and download manager.
