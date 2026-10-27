//
//  GeminiProgressModal.swift
//  BeeBar
//
//  Interactive floating HUD terminal console that displays real-time descriptive logging
//  of payloads and network communication while summarizing a conversation with Google Gemini.
//  Provides both a live Terminal Log view and a formatted Summary Preview tab,
//  copies the full response to the system clipboard upon completion, and manages a 5-second
//  auto-dismiss countdown bar with pause and re-copy capabilities.
//

import AppKit

/// Interactive floating modal controller for Gemini AI summarization with terminal streaming.
@MainActor
public final class GeminiProgressModal: NSObject {
    public static let shared = GeminiProgressModal()

    // MARK: - Layout & Timing Constants

    private let panelWidth: CGFloat = 560
    private let panelHeight: CGFloat = 450
    private let totalCountdownSeconds: Double = 5.0
    private let timerTickInterval: Double = 0.05

    // MARK: - UI Elements

    private var panel: NSPanel!
    private var visualEffect: NSVisualEffectView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var modeSegmentedControl: NSSegmentedControl!

    private var terminalScrollView: NSScrollView!
    private var terminalTextView: NSTextView!

    private var previewScrollView: NSScrollView!
    private var previewTextView: NSTextView!

    private var statusLabel: NSTextField!
    private var progressBar: NSProgressIndicator!
    private var pauseTimerButton: NSButton!
    private var copyAgainButton: NSButton!
    private var actionButton: NSButton!

    // MARK: - State

    private var dismissTimer: Timer?
    private var currentTask: Task<Void, Never>?
    private var elapsedSeconds: Double = 0.0
    private var isTimerPaused: Bool = false
    private var lastGeneratedSummary: String = ""

    // MARK: - Initialization

    override private init() {
        super.init()
        setupUI()
    }

    private func setupUI() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.title = "Gemini AI Summary Console"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        visualEffect.layer?.borderWidth = 1.0

        // 1. Header Title
        titleLabel = NSTextField(labelWithString: "Gemini AI Summary Console")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: panelHeight - 38, width: 280, height: 22)
        visualEffect.addSubview(titleLabel)

        // 2. Subtitle
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: panelHeight - 56, width: 280, height: 16)
        visualEffect.addSubview(subtitleLabel)

        // 3. Tab Selector (Terminal Log vs Summary Preview)
        modeSegmentedControl = NSSegmentedControl(labels: ["Terminal Log", "Summary Preview"], trackingMode: .selectOne, target: self, action: #selector(handleTabSwitch))
        modeSegmentedControl.selectedSegment = 0
        modeSegmentedControl.controlSize = .small
        modeSegmentedControl.frame = NSRect(x: panelWidth - 220, y: panelHeight - 44, width: 200, height: 24)
        visualEffect.addSubview(modeSegmentedControl)

        // 4. Terminal Log View
        let contentFrame = NSRect(x: 20, y: 78, width: panelWidth - 40, height: 295)
        terminalScrollView = NSScrollView(frame: contentFrame)
        terminalScrollView.borderType = .bezelBorder
        terminalScrollView.drawsBackground = true
        terminalScrollView.backgroundColor = NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
        terminalScrollView.hasVerticalScroller = true
        terminalScrollView.autohidesScrollers = true

        terminalTextView = NSTextView(frame: terminalScrollView.contentView.bounds)
        terminalTextView.isEditable = false
        terminalTextView.isSelectable = true
        terminalTextView.drawsBackground = false
        terminalTextView.textColor = NSColor(red: 0.88, green: 0.91, blue: 0.95, alpha: 1.0)
        terminalTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        terminalTextView.textContainerInset = NSSize(width: 10, height: 10)
        terminalScrollView.documentView = terminalTextView
        visualEffect.addSubview(terminalScrollView)

        // 5. Response Markdown Preview
        previewScrollView = NSScrollView(frame: contentFrame)
        previewScrollView.borderType = .bezelBorder
        previewScrollView.drawsBackground = true
        previewScrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.6)
        previewScrollView.hasVerticalScroller = true
        previewScrollView.autohidesScrollers = true
        previewScrollView.isHidden = true

        previewTextView = NSTextView(frame: previewScrollView.contentView.bounds)
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.drawsBackground = false
        previewTextView.textColor = .labelColor
        previewTextView.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewTextView.textContainerInset = NSSize(width: 10, height: 10)
        previewScrollView.documentView = previewTextView
        visualEffect.addSubview(previewScrollView)

        // 6. Bottom Status Label
        statusLabel = NSTextField(labelWithString: "Initializing...")
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 20, y: 46, width: panelWidth - 40, height: 18)
        visualEffect.addSubview(statusLabel)

        // 7. Determinate 0–5s Auto-Dismiss Progress Bar
        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 38, width: panelWidth - 40, height: 6))
        progressBar.isIndeterminate = false
        progressBar.style = .bar
        progressBar.minValue = 0.0
        progressBar.maxValue = totalCountdownSeconds
        progressBar.doubleValue = 0.0
        progressBar.controlSize = .mini
        progressBar.isHidden = true
        visualEffect.addSubview(progressBar)

        // 8. Bottom Action Buttons
        pauseTimerButton = NSButton(title: "Pause Auto-Close", target: self, action: #selector(handlePauseTimer))
        pauseTimerButton.bezelStyle = .rounded
        pauseTimerButton.controlSize = .small
        pauseTimerButton.frame = NSRect(x: 20, y: 10, width: 130, height: 24)
        pauseTimerButton.isHidden = true
        visualEffect.addSubview(pauseTimerButton)

        copyAgainButton = NSButton(title: "Copy Again", target: self, action: #selector(handleCopyAgain))
        copyAgainButton.bezelStyle = .rounded
        copyAgainButton.controlSize = .small
        copyAgainButton.frame = NSRect(x: 156, y: 10, width: 95, height: 24)
        copyAgainButton.isHidden = true
        visualEffect.addSubview(copyAgainButton)

        actionButton = NSButton(title: "Cancel", target: self, action: #selector(handleActionButtonClick))
        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .small
        actionButton.frame = NSRect(x: panelWidth - 100, y: 10, width: 80, height: 24)
        actionButton.keyEquivalent = "\u{1b}" // Escape
        visualEffect.addSubview(actionButton)

        panel.contentView = visualEffect
    }

    // MARK: - Summarization Workflow

    /// Presents the modal, logs detailed telemetry in real time, calls `GeminiService`,
    /// copies the full result to the clipboard, and begins the auto-dismiss countdown.
    public func startSummarization(
        conv: BeeConversationItem,
        sourceText: String,
        apiKey: String,
        model: String,
        storageDir: String,
        prePrompt: String? = nil
    ) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentTask?.cancel()
        elapsedSeconds = 0.0
        isTimerPaused = false
        lastGeneratedSummary = ""

        titleLabel.stringValue = "Gemini AI Summary Console"
        subtitleLabel.stringValue = "\(conv.title) • \(model)"

        modeSegmentedControl.selectedSegment = 0
        terminalScrollView.isHidden = false
        previewScrollView.isHidden = true
        terminalTextView.string = ""
        previewTextView.string = ""

        statusLabel.stringValue = "Sending request to Google Gemini API..."
        statusLabel.textColor = .secondaryLabelColor

        progressBar.isHidden = true
        progressBar.doubleValue = 0.0

        pauseTimerButton.isHidden = true
        copyAgainButton.isHidden = true
        actionButton.title = "Cancel"
        actionButton.keyEquivalent = "\u{1b}" // Escape

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Initial Terminal Log Entries
        appendTerminalLog("[INIT] Session started for: \"\(conv.title)\"")
        appendTerminalLog("[TARGET] Conversation ID: \(conv.id) | Recorded: \(conv.relativeDateString)")
        appendTerminalLog("[ENGINE] Model selected: \(model)")

        currentTask = Task { [weak self] in
            do {
                let responseText = try await GeminiService.shared.summarize(
                    text: sourceText,
                    apiKey: apiKey,
                    model: model,
                    prePrompt: prePrompt,
                    onLog: { message in
                        Task { @MainActor in
                            self?.appendTerminalLog(message)
                        }
                    }
                )

                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    guard let self = self else { return }

                    self.lastGeneratedSummary = responseText

                    // 1. Copy entire Gemini response payload to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(responseText, forType: .string)

                    // 2. Save full response to exports folder as Markdown backup with historical timestamp
                    let outPath = conv.geminiBriefPath(storageDir: storageDir)
                    try? responseText.write(toFile: outPath, atomically: true, encoding: .utf8)
                    if let fileDate = conv.createdDate {
                        try? FileManager.default.setAttributes([
                            .creationDate: fileDate,
                            .modificationDate: fileDate
                        ], ofItemAtPath: outPath)
                    }

                    self.appendTerminalLog("[CLIPBOARD] Copied full response (\(responseText.count) chars) to macOS clipboard.")
                    self.appendTerminalLog("[STORAGE] Saved Markdown dossier to: \(outPath)")
                    self.appendTerminalLog("[COMPLETE] All operations finished. Auto-dismissing in 5s...")

                    // 3. Update preview view and switch to Summary Preview tab
                    self.previewTextView.string = responseText
                    self.modeSegmentedControl.selectedSegment = 1
                    self.terminalScrollView.isHidden = true
                    self.previewScrollView.isHidden = false

                    // 4. Update status labels and action controls
                    self.statusLabel.stringValue = "Returned summary copied to clipboard! (\(responseText.count) characters)"
                    self.statusLabel.textColor = NSColor(red: 0.1, green: 0.75, blue: 0.35, alpha: 1.0)

                    self.pauseTimerButton.isHidden = false
                    self.pauseTimerButton.title = "Pause Auto-Close"
                    self.copyAgainButton.isHidden = false
                    self.actionButton.title = "Done"
                    self.actionButton.keyEquivalent = "\r" // Return

                    // 5. Start 0–5s progress bar countdown
                    self.progressBar.isHidden = false
                    self.progressBar.doubleValue = 0.0
                    self.elapsedSeconds = 0.0

                    self.dismissTimer = Timer.scheduledTimer(
                        timeInterval: self.timerTickInterval,
                        target: self,
                        selector: #selector(self.handleTimerTick(_:)),
                        userInfo: nil,
                        repeats: true
                    )
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.appendTerminalLog("[ERROR] Generation failed: \(error.localizedDescription)")

                    self.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    self.statusLabel.textColor = .systemRed
                    self.actionButton.title = "Close"
                }
            }
        }
    }

    // MARK: - Logging Helper

    private func appendTerminalLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] > \(text)\n"

        if let storage = terminalTextView.textStorage {
            let attrString = NSAttributedString(
                string: line,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: text.contains("[ERROR]")
                        ? NSColor.systemRed
                        : (text.contains("[SUCCESS]") || text.contains("[COMPLETE]") || text.contains("[CLIPBOARD]")
                            ? NSColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1.0)
                            : (text.contains("[HTTP]") || text.contains("[NET]")
                                ? NSColor(red: 0.95, green: 0.65, blue: 0.2, alpha: 1.0)
                                : NSColor(red: 0.85, green: 0.88, blue: 0.93, alpha: 1.0)))
                ]
            )
            storage.append(attrString)
            terminalTextView.scrollToEndOfDocument(nil)
        }
    }

    // MARK: - Control Actions

    @objc private func handleTabSwitch() {
        if modeSegmentedControl.selectedSegment == 0 {
            terminalScrollView.isHidden = false
            previewScrollView.isHidden = true
        } else {
            terminalScrollView.isHidden = true
            previewScrollView.isHidden = false
        }
    }

    @objc private func handlePauseTimer() {
        if isTimerPaused {
            // Resume timer
            isTimerPaused = false
            pauseTimerButton.title = "Pause Auto-Close"
            progressBar.isHidden = false
            dismissTimer = Timer.scheduledTimer(
                timeInterval: timerTickInterval,
                target: self,
                selector: #selector(handleTimerTick(_:)),
                userInfo: nil,
                repeats: true
            )
        } else {
            // Pause timer
            isTimerPaused = true
            dismissTimer?.invalidate()
            dismissTimer = nil
            progressBar.isHidden = true
            pauseTimerButton.title = "Resume Auto-Close"
            statusLabel.stringValue = "Auto-dismiss paused. Take your time to review or copy."
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func handleCopyAgain() {
        guard !lastGeneratedSummary.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastGeneratedSummary, forType: .string)
        statusLabel.stringValue = "Re-copied summary to clipboard!"
        statusLabel.textColor = NSColor(red: 0.1, green: 0.75, blue: 0.35, alpha: 1.0)
    }

    @objc private func handleTimerTick(_ timer: Timer) {
        elapsedSeconds += timerTickInterval
        progressBar.doubleValue = min(elapsedSeconds, totalCountdownSeconds)
        if elapsedSeconds >= totalCountdownSeconds {
            timer.invalidate()
            dismissTimer = nil
            panel.orderOut(nil)
        }
    }

    @objc private func handleActionButtonClick() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentTask?.cancel()
        panel.orderOut(nil)
    }
}
