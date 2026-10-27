//
//  AppDelegate.swift
//  BeeBar
//
//  Main application delegate managing the macOS menu bar NSStatusItem, dynamic NSMenu
//  construction, left-side hover summary preview panel, clipboard actions, Gemini AI
//  summarization triggers, and Preferences window lifecycle.
//

import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Properties

    var statusItem: NSStatusItem!
    var mainMenu: NSMenu!
    var preferencesWindow: NSWindow?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent macOS Automatic Termination from closing this accessory menu bar app when idle
        ProcessInfo.processInfo.disableAutomaticTermination("BeeBar status item")
        ProcessInfo.processInfo.disableSuddenTermination()

        // Run purely as an accessory menu bar application (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Request user notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Enable standard macOS Edit menu shortcuts (⌘V, ⌘C, ⌘X, ⌘A, ⌘Z) for all modal and settings text fields
        setupStandardEditMenu()

        // Configure NSStatusItem in the system menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "computer.bee.beebar.statusItem"
        statusItem.behavior = [.removalAllowed]
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.image = BeeIcon.createIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Bee Menu Bar (⌘-drag to reposition)"
        }

        // Attach dynamic NSMenu
        mainMenu = NSMenu()
        mainMenu.delegate = self
        statusItem.menu = mainMenu

        // Load cached local conversation index
        BeeStore.shared.loadLocalData()

        showNotification(
            title: "The Bee Bar is Active",
            body: "Look for the Bee icon in your menu bar. Tip: Hold ⌘ and drag the icon to reposition it."
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Configures the hidden application Edit menu so standard keyboard shortcuts (Paste, Copy, Cut, Select All, Undo) work inside `NSTextField` and SwiftUI `TextField` views.
    private func setupStandardEditMenu() {
        let appMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        appMenu.addItem(editMenuItem)
        NSApp.mainMenu = appMenu
    }

    // MARK: - NSMenuDelegate (Dynamic Menu Construction)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let store = BeeStore.shared
        store.loadLocalData()

        // 1. Top Header Line
        let headerItem = NSMenuItem(title: "Select a Bee conversation to copy or view", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // 2. Recent Conversation Items (configurable count)
        let limit = store.config.maxItemsToShow > 0 ? store.config.maxItemsToShow : BeeConfig.defaultMaxItemsToShow
        let conversations = Array(store.conversations.prefix(limit))
        if conversations.isEmpty {
            let emptyItem = NSMenuItem(title: "No Bee records found in \(store.config.storageDir)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, conv) in conversations.enumerated() {
                menu.addItem(createConversationMenuItem(conv, index: index))
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Settings & Sync Management Section

        // A. Exports Folder Submenu
        let folderDisplay = store.config.storageDir.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
        let folderItem = NSMenuItem(title: "Folder: \(folderDisplay)", action: #selector(openFolderInFinder), keyEquivalent: "")
        folderItem.target = self

        let folderSubmenu = NSMenu()
        let openFolderAction = NSMenuItem(title: "Open in Finder", action: #selector(openFolderInFinder), keyEquivalent: "")
        openFolderAction.target = self
        folderSubmenu.addItem(openFolderAction)

        let changeFolderAction = NSMenuItem(title: "Change Folder...", action: #selector(changeStorageFolder), keyEquivalent: "")
        changeFolderAction.target = self
        folderSubmenu.addItem(changeFolderAction)

        folderItem.submenu = folderSubmenu
        menu.addItem(folderItem)

        // B. Bee Sync Endpoint & Auth Submenu
        let syncStatusText = store.isConnected
            ? (store.config.endpoint.contains("8787") ? "Connected (Proxy 127.0.0.1:8787)" : "Connected (Cloud API)")
            : "Offline / Needs Setup"
        let syncItem = NSMenuItem(title: "Bee Sync: \(syncStatusText)", action: nil, keyEquivalent: "")

        let syncSubmenu = NSMenu()
        let proxyAction = NSMenuItem(title: "Switch to Local Proxy (127.0.0.1:8787)", action: #selector(switchToProxy), keyEquivalent: "")
        proxyAction.target = self
        if store.config.endpoint.contains("8787") { proxyAction.state = .on }
        syncSubmenu.addItem(proxyAction)

        let cloudAction = NSMenuItem(title: "Switch to Public API", action: #selector(switchToPublicApi), keyEquivalent: "")
        cloudAction.target = self
        if store.config.endpoint.contains("developer.bee.amazon.dev") { cloudAction.state = .on }
        syncSubmenu.addItem(cloudAction)

        syncSubmenu.addItem(NSMenuItem.separator())

        let tokenAction = NSMenuItem(title: "Set Bearer Token...", action: #selector(promptForToken), keyEquivalent: "")
        tokenAction.target = self
        syncSubmenu.addItem(tokenAction)

        let testAction = NSMenuItem(title: "Verify Connection (GET /v1/me)", action: #selector(testConnection), keyEquivalent: "")
        testAction.target = self
        syncSubmenu.addItem(testAction)

        syncItem.submenu = syncSubmenu
        menu.addItem(syncItem)

        // C. Update Frequency Submenu
        let freqText = formatFrequency(store.config.syncIntervalMinutes)
        let freqItem = NSMenuItem(title: "Update Frequency: \(freqText)", action: nil, keyEquivalent: "")

        let freqSubmenu = NSMenu()
        let frequencies: [(String, Int)] = [
            ("Every 1 minute", 1),
            ("Every 5 minutes (Recommended)", 5),
            ("Every 15 minutes", 15),
            ("Daily (Every 24 hours)", 1440),
            ("Weekly", 10080),
            ("Manual Only", 0)
        ]
        for (label, val) in frequencies {
            let item = NSMenuItem(title: label, action: #selector(setFrequency(_:)), keyEquivalent: "")
            item.target = self
            item.tag = val
            if store.config.syncIntervalMinutes == val {
                item.state = .on
            }
            freqSubmenu.addItem(item)
        }
        freqItem.submenu = freqSubmenu
        menu.addItem(freqItem)

        // D. Number of Recordings Submenu
        let countItem = NSMenuItem(title: "Recordings to Show: \(limit)", action: nil, keyEquivalent: "")
        let countSubmenu = NSMenu()
        let countOptions = [5, 10, 15, 20, 25, 50, 100]
        for opt in countOptions {
            let label = opt >= 100 ? "All Recordings (100)" : "\(opt) Recordings"
            let item = NSMenuItem(title: label, action: #selector(setRecordingsCount(_:)), keyEquivalent: "")
            item.target = self
            item.tag = opt
            if limit == opt {
                item.state = .on
            }
            countSubmenu.addItem(item)
        }
        countItem.submenu = countSubmenu
        menu.addItem(countItem)

        // E. Manual Sync Actions
        let updateNowTitle = store.isSyncing ? "Updating Records..." : "Update Now (Sync Recent Records)"
        let updateNowItem = NSMenuItem(title: updateNowTitle, action: #selector(updateNow), keyEquivalent: "r")
        updateNowItem.target = self
        updateNowItem.isEnabled = !store.isSyncing
        menu.addItem(updateNowItem)

        let updateAllItem = NSMenuItem(title: "Update All (Full Archive Sync)", action: #selector(updateAll), keyEquivalent: "")
        updateAllItem.target = self
        updateAllItem.isEnabled = !store.isSyncing
        menu.addItem(updateAllItem)

        menu.addItem(NSMenuItem.separator())

        // E. Preferences & Quit
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit The Bee Bar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Conversation Menu Item Builder

    /// Builds a single conversation `NSMenuItem` displaying the first line of the summary,
    /// attaching a right-side action submenu (`Copy Summary`, `Copy Transcript`, `Copy Gemini Summary`, file openers).
    private func createConversationMenuItem(_ conv: BeeConversationItem, index: Int) -> NSMenuItem {
        let cleanSummary = getCleanSummary(conv: conv)
        let firstLine = extractFirstLine(cleanSummary)

        let rawLine = firstLine.isEmpty ? conv.title : firstLine
        let lineTitle = formatSummaryLine(rawLine, maxLength: 52)
        let keyEq = index < 10 ? "\(index)" : ""

        let item = NSMenuItem(title: lineTitle, action: #selector(copySummary(_:)), keyEquivalent: keyEq)
        item.target = self
        item.representedObject = conv

        let dateStr = conv.relativeDateString
        let durStr = conv.formattedDuration ?? ""
        let turnsStr = conv.utteranceCount.map { "\($0) turns" } ?? ""
        let metaLine = [dateStr, durStr, turnsStr].filter { !$0.isEmpty }.joined(separator: " • ")

        item.toolTip = """
        \(conv.title)
        [\(metaLine)]

        \(cleanSummary)
        """

        // Action Submenu
        let submenu = NSMenu()

        let copySummaryItem = NSMenuItem(title: "Copy Summary", action: #selector(copySummary(_:)), keyEquivalent: "")
        copySummaryItem.target = self
        copySummaryItem.representedObject = conv
        submenu.addItem(copySummaryItem)

        let copyTranscriptItem = NSMenuItem(title: "Copy Transcript", action: #selector(copyTranscript(_:)), keyEquivalent: "")
        copyTranscriptItem.target = self
        copyTranscriptItem.representedObject = conv
        submenu.addItem(copyTranscriptItem)

        let modelName = BeeStore.shared.config.geminiModel
        let geminiItem = NSMenuItem(title: "Copy Gemini Summary (\(modelName))", action: #selector(summarizeWithGemini(_:)), keyEquivalent: "")
        geminiItem.target = self
        geminiItem.representedObject = conv
        submenu.addItem(geminiItem)

        submenu.addItem(NSMenuItem.separator())

        let openMdItem = NSMenuItem(title: "Open Markdown Summary (.md)", action: #selector(openMarkdown(_:)), keyEquivalent: "")
        openMdItem.target = self
        openMdItem.representedObject = conv
        submenu.addItem(openMdItem)

        let openTxtItem = NSMenuItem(title: "Open Transcript (.txt)", action: #selector(openTranscript(_:)), keyEquivalent: "")
        openTxtItem.target = self
        openTxtItem.representedObject = conv
        submenu.addItem(openTxtItem)

        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: "")
        revealItem.target = self
        revealItem.representedObject = conv
        submenu.addItem(revealItem)

        item.submenu = submenu
        return item
    }

    // MARK: - Conversation Actions

    /// Copies the original Bee summary (under `## Summary` without the audio transcript) to the system clipboard.
    @objc func copySummary(_ sender: NSMenuItem) {
        guard let conv = sender.representedObject as? BeeConversationItem else { return }
        let summaryText = extractOriginalBeeSummary(conv)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summaryText, forType: .string)
        showNotification(title: "Summary Copied", body: "\(conv.title) summary copied to clipboard.")
    }

    /// Copies the verbatim plain-text transcript (`transcripts/<id>_transcript.txt`) to the system clipboard.
    @objc func copyTranscript(_ sender: NSMenuItem) {
        guard let conv = sender.representedObject as? BeeConversationItem else { return }
        let store = BeeStore.shared
        let txtPath = conv.transcriptTextPath(storageDir: store.config.storageDir)

        guard FileManager.default.fileExists(atPath: txtPath),
              let content = try? String(contentsOfFile: txtPath, encoding: .utf8) else {
            showNotification(title: "Transcript Missing", body: "Verbatim transcript file not found.")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        showNotification(title: "Transcript Copied", body: "\(conv.title) transcript copied to clipboard.")
    }

    /// Opens the floating `GeminiProgressModal` to summarize the conversation transcript with the selected Gemini model
    /// and copies the complete response to the clipboard.
    @objc func summarizeWithGemini(_ sender: NSMenuItem) {
        guard let conv = sender.representedObject as? BeeConversationItem else { return }
        let store = BeeStore.shared

        var apiKey = store.config.geminiApiKey
        if apiKey.isEmpty {
            apiKey = promptForGeminiKey()
            guard !apiKey.isEmpty else { return }
        }

        let txtPath = conv.transcriptTextPath(storageDir: store.config.storageDir)
        var sourceText = ""
        if FileManager.default.fileExists(atPath: txtPath),
           let content = try? String(contentsOfFile: txtPath, encoding: .utf8), !content.isEmpty {
            sourceText = content
        } else {
            let mdPath = conv.markdownPath(storageDir: store.config.storageDir)
            if FileManager.default.fileExists(atPath: mdPath),
               let mdContent = try? String(contentsOfFile: mdPath, encoding: .utf8), !mdContent.isEmpty {
                sourceText = mdContent
            } else {
                sourceText = conv.summarySnippet ?? conv.title
            }
        }

        GeminiProgressModal.shared.startSummarization(
            conv: conv,
            sourceText: sourceText,
            apiKey: apiKey,
            model: store.config.geminiModel,
            storageDir: store.config.storageDir,
            prePrompt: store.config.geminiPrompt
        )
    }

    @objc func openMarkdown(_ sender: NSMenuItem) {
        guard let conv = sender.representedObject as? BeeConversationItem else { return }
        let store = BeeStore.shared
        store.openFile(atPath: conv.markdownPath(storageDir: store.config.storageDir))
    }

    @objc func openTranscript(_ sender: NSMenuItem) {
        guard let conv = sender.representedObject as? BeeConversationItem else { return }
        let store = BeeStore.shared
        store.openFile(atPath: conv.transcriptTextPath(storageDir: store.config.storageDir))
    }

    @objc func revealInFinder(_ sender: NSMenuItem) {
        guard let conv = sender.representedObject as? BeeConversationItem else { return }
        let store = BeeStore.shared
        store.revealInFinder(atPath: conv.transcriptTextPath(storageDir: store.config.storageDir))
    }

    // MARK: - Summary Parsing & Formatting Helpers

    /// Extracts the clean summary section from the original Bee JSON record (`c["summary"]`)
    /// or Markdown file, stripping YAML frontmatter and audio transcripts.
    private func extractOriginalBeeSummary(_ conv: BeeConversationItem) -> String {
        let store = BeeStore.shared
        var text = ""

        // 1. Read directly from the original Bee JSON record
        let jsonPath = conv.jsonPath(storageDir: store.config.storageDir)
        if FileManager.default.fileExists(atPath: jsonPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let c = (json["conversation"] as? [String: Any]) ?? json
            if let s = c["summary"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = s
            } else if let s = c["short_summary"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = s
            }
        }

        // 2. Fallback to Markdown file if JSON is not available
        if text.isEmpty {
            let mdPath = conv.markdownPath(storageDir: store.config.storageDir)
            if FileManager.default.fileExists(atPath: mdPath),
               let mdContent = try? String(contentsOfFile: mdPath, encoding: .utf8) {
                text = mdContent
            }
        }

        if text.isEmpty {
            return conv.summarySnippet ?? conv.title
        }

        // Strip YAML frontmatter
        if text.hasPrefix("---") {
            let parts = text.components(separatedBy: "---")
            if parts.count >= 3 {
                text = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strip verbatim transcript section if attached
        for marker in ["## \u{1F399}\u{FE0F} Audio Transcript", "## \u{1F399}\u{FE0F} Transcript", "## Audio Transcript", "## Transcript"] {
            if let range = text.range(of: marker) {
                text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Extract clean text under ## Summary / # Summary up to the next section heading
        let summaryHeadings = [
            "## Summary\n", "## Summary\r\n",
            "# Summary\n", "# Summary\r\n",
            "### Summary\n", "### Summary\r\n",
            "## \u{1F4CB} Executive Summary\n", "## \u{1F4CB} Executive Summary\r\n"
        ]

        for heading in summaryHeadings {
            if let range = text.range(of: heading) {
                var chunk = String(text[range.upperBound...])
                if let nextHeading = chunk.range(of: "\n## ") ?? chunk.range(of: "\n# ") {
                    chunk = String(chunk[..<nextHeading.lowerBound])
                }
                let cleaned = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns a clean summary string suitable for the hover preview panel and menu line extraction.
    private func getCleanSummary(conv: BeeConversationItem) -> String {
        let extracted = extractOriginalBeeSummary(conv)
        return extracted
            .replacingOccurrences(of: "## Summary", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts the first non-empty content line from a summary block.
    private func extractFirstLine(_ text: String) -> String {
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines {
            if !line.isEmpty && !line.hasPrefix("---") && !line.hasPrefix("id:") && !line.hasPrefix("title:") {
                return line
            }
        }
        return ""
    }

    /// Truncates a single-line summary string with an ellipsis if it exceeds `maxLength`.
    private func formatSummaryLine(_ line: String, maxLength: Int) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > maxLength {
            return String(trimmed.prefix(maxLength - 3)) + "..."
        }
        return trimmed
    }

    private func formatFrequency(_ mins: Int) -> String {
        switch mins {
        case 0: return "Manual Only"
        case 1: return "Every 1 min"
        case 5: return "Every 5 min"
        case 15: return "Every 15 min"
        case 1440: return "Daily (24h)"
        case 10080: return "Weekly"
        default: return "Every \(mins) min"
        }
    }

    // MARK: - Settings & Sync Management Actions

    @objc func openFolderInFinder() {
        BeeStore.shared.openFolderInFinder()
    }

    @objc func changeStorageFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Export Folder"
        if panel.runModal() == .OK, let url = panel.url {
            var updated = BeeStore.shared.config
            updated.storageDir = url.path
            BeeStore.shared.updateConfig(updated)
            showNotification(title: "Folder Updated", body: "Bee exports will now be saved to: \(url.path)")
        }
    }

    @objc func switchToProxy() {
        var updated = BeeStore.shared.config
        updated.endpoint = BeeConfig.defaultEndpoint
        BeeStore.shared.updateConfig(updated)
        showNotification(title: "Bee Connection", body: "Switched to Local Proxy (127.0.0.1:8787).")
    }

    @objc func switchToPublicApi() {
        var updated = BeeStore.shared.config
        updated.endpoint = BeeConfig.publicCloudEndpoint
        BeeStore.shared.updateConfig(updated)
        showNotification(title: "Bee Connection", body: "Switched to Public API.")
    }

    @objc func testConnection() {
        Task {
            let engine = BeeSyncEngine(config: BeeStore.shared.config)
            let res = await engine.testConnection()
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = res.success ? "Connection Succeeded" : "Connection Failed"
                alert.informativeText = res.message
                alert.runModal()
            }
        }
    }

    @objc func setFrequency(_ sender: NSMenuItem) {
        var updated = BeeStore.shared.config
        updated.syncIntervalMinutes = sender.tag
        BeeStore.shared.updateConfig(updated)
        showNotification(title: "Sync Schedule Updated", body: "Frequency set to \(formatFrequency(sender.tag)).")
    }

    @objc func setRecordingsCount(_ sender: NSMenuItem) {
        var updated = BeeStore.shared.config
        updated.maxItemsToShow = sender.tag
        BeeStore.shared.updateConfig(updated)
        let display = sender.tag >= 100 ? "all available" : "\(sender.tag)"
        showNotification(title: "Menu Updated", body: "Showing up to \(display) recordings in menu bar.")
    }

    @objc func updateNow() {
        Task {
            await BeeStore.shared.performSync()
            showNotification(title: "Bee Sync Complete", body: "Latest conversations and transcripts are current.")
        }
    }

    @objc func updateAll() {
        Task {
            await BeeStore.shared.performSync()
            showNotification(title: "Bee Archive Synced", body: "All conversations and transcripts are current.")
        }
    }

    @objc func openPreferences() {
        if preferencesWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.title = "The Bee Bar Preferences"
            win.minSize = CGSize(width: 480, height: 500)
            win.isReleasedWhenClosed = false
            let rootView = SettingsView(store: BeeStore.shared) { [weak win] in
                win?.close()
            }
            win.contentView = NSHostingView(rootView: rootView)
            self.preferencesWindow = win
        }
        BeeStore.shared.showingSettings = true
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - User Prompts & Notifications

    @objc func promptForToken() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Set Bee Developer Bearer Token"
        alert.informativeText = "Paste your Bee developer Bearer token ($BEE_TOKEN):"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 26))
        input.stringValue = BeeStore.shared.config.token
        input.placeholderString = "Paste token here..."
        input.isEditable = true
        input.isSelectable = true
        alert.accessoryView = input

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Paste from Clipboard")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = input

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            var updated = BeeStore.shared.config
            updated.token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            BeeStore.shared.updateConfig(updated)
            showNotification(title: "Token Saved", body: "Bearer token updated.")
        } else if resp == .alertSecondButtonReturn {
            if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                var updated = BeeStore.shared.config
                updated.token = clip
                BeeStore.shared.updateConfig(updated)
                showNotification(title: "Token Pasted & Saved", body: "Bearer token updated from clipboard.")
            }
        }
    }

    private func promptForGeminiKey() -> String {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Gemini API Key Needed"
        alert.informativeText = "Paste your Google Gemini API key to enable instant AI summarization:"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 26))
        input.placeholderString = "Paste API key (AIzaSy...)"
        input.stringValue = BeeStore.shared.config.geminiApiKey
        input.isEditable = true
        input.isSelectable = true
        alert.accessoryView = input

        alert.addButton(withTitle: "Save & Summarize")
        alert.addButton(withTitle: "Paste from Clipboard")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = input

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let key = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                var updated = BeeStore.shared.config
                updated.geminiApiKey = key
                BeeStore.shared.updateConfig(updated)
                return key
            }
        } else if resp == .alertSecondButtonReturn {
            if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                var updated = BeeStore.shared.config
                updated.geminiApiKey = clip
                BeeStore.shared.updateConfig(updated)
                return clip
            }
        }
        return ""
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - NSMenuDelegate (Left-Side Hover Summary Preview)

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard let item = item, let conv = item.representedObject as? BeeConversationItem else {
            SummaryPreviewPanel.shared.hide()
            return
        }
        let cleanSummary = getCleanSummary(conv: conv)

        // Locate the active NSMenu window frame on screen
        var menuFrame = NSRect.zero
        for w in NSApp.windows {
            let className = String(describing: type(of: w))
            if className.contains("Menu") && w.isVisible && w.frame.width > 80 {
                menuFrame = w.frame
                break
            }
        }
        if menuFrame == .zero, let button = statusItem.button, let window = button.window {
            let buttonScreen = window.convertToScreen(button.frame)
            menuFrame = NSRect(x: buttonScreen.minX - 320, y: buttonScreen.minY - 420, width: 340, height: 420)
        }

        SummaryPreviewPanel.shared.show(for: conv, summary: cleanSummary, menuFrame: menuFrame)
    }

    func menuDidClose(_ menu: NSMenu) {
        SummaryPreviewPanel.shared.hide()
    }
}
