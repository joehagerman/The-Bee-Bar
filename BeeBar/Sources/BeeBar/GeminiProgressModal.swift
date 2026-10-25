//
//  GeminiProgressModal.swift
//  BeeBar
//
//  Floating HUD modal that displays real-time status while summarizing a transcript
//  with Google Gemini:
//    1. "Sending to Gemini..."
//    2. "Waiting..."
//    3. "Returned summary copied to clipboard!"
//  Upon completion, copies the full Gemini response to the system clipboard, displays
//  a scrollable preview, and runs a 0–5 second progress bar before auto-dismissing.
//

import AppKit

/// Interactive floating modal controller for Gemini AI summarization.
@MainActor
public final class GeminiProgressModal: NSObject {
    public static let shared = GeminiProgressModal()

    // MARK: - Layout & Timing Constants

    private let panelWidth: CGFloat = 480
    private let panelHeight: CGFloat = 360
    private let totalCountdownSeconds: Double = 5.0
    private let timerTickInterval: Double = 0.05

    // MARK: - UI Elements

    private var panel: NSPanel!
    private var visualEffect: NSVisualEffectView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var spinner: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var previewScrollView: NSScrollView!
    private var previewTextView: NSTextView!
    private var progressBar: NSProgressIndicator!
    private var closeButton: NSButton!

    // MARK: - State

    private var dismissTimer: Timer?
    private var currentTask: Task<Void, Never>?
    private var elapsedSeconds: Double = 0.0

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
        panel.title = "Gemini AI Summarization"
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
        titleLabel = NSTextField(labelWithString: "Gemini AI Summary")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: panelHeight - 38, width: panelWidth - 40, height: 22)
        visualEffect.addSubview(titleLabel)

        // 2. Conversation & Model Subtitle
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: panelHeight - 58, width: panelWidth - 40, height: 16)
        visualEffect.addSubview(subtitleLabel)

        // 3. Indeterminate Spinner (visible during network request)
        spinner = NSProgressIndicator(frame: NSRect(x: (panelWidth - 32) / 2, y: panelHeight - 150, width: 32, height: 32))
        spinner.style = .spinning
        spinner.controlSize = .regular
        visualEffect.addSubview(spinner)

        // 4. Status Label
        statusLabel = NSTextField(labelWithString: "Sending to Gemini...")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: panelHeight - 190, width: panelWidth - 40, height: 22)
        visualEffect.addSubview(statusLabel)

        // 5. Scrollable Response Preview
        previewScrollView = NSScrollView(frame: NSRect(x: 20, y: 78, width: panelWidth - 40, height: 195))
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
        previewTextView.textContainerInset = NSSize(width: 8, height: 8)
        previewScrollView.documentView = previewTextView
        visualEffect.addSubview(previewScrollView)

        // 6. Determinate 0–5s Auto-Dismiss Progress Bar
        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: panelWidth - 40, height: 12))
        progressBar.isIndeterminate = false
        progressBar.style = .bar
        progressBar.minValue = 0.0
        progressBar.maxValue = totalCountdownSeconds
        progressBar.doubleValue = 0.0
        progressBar.controlSize = .small
        progressBar.isHidden = true
        visualEffect.addSubview(progressBar)

        // 7. Action Button (Cancel / Done)
        closeButton = NSButton(title: "Cancel", target: self, action: #selector(handleButtonClick))
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: (panelWidth - 110) / 2, y: 14, width: 110, height: 28)
        visualEffect.addSubview(closeButton)

        panel.contentView = visualEffect
    }

    // MARK: - Summarization Workflow

    /// Presents the modal, invokes `GeminiService.shared.summarize`, copies the full response
    /// to the clipboard, saves a Markdown backup, and starts the 5-second auto-dismiss countdown bar.
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

        titleLabel.stringValue = "Gemini AI Summary"
        subtitleLabel.stringValue = "\(conv.title) • \(model)"

        spinner.isHidden = false
        spinner.startAnimation(nil)

        statusLabel.stringValue = "Sending to Gemini..."
        statusLabel.textColor = .labelColor
        statusLabel.frame = NSRect(x: 20, y: panelHeight - 190, width: panelWidth - 40, height: 22)

        previewScrollView.isHidden = true
        previewTextView.string = ""

        progressBar.isHidden = true
        progressBar.doubleValue = 0.0

        closeButton.title = "Cancel"
        closeButton.keyEquivalent = "\u{1b}" // Escape

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        currentTask = Task { [weak self] in
            // Stage 1: "Sending to Gemini..."
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                // Stage 2: "Waiting..."
                self?.statusLabel.stringValue = "Waiting..."
            }

            do {
                let responseText = try await GeminiService.shared.summarize(
                    text: sourceText,
                    apiKey: apiKey,
                    model: model,
                    prePrompt: prePrompt
                )

                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    guard let self = self else { return }

                    // 1. Copy entire Gemini response payload to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(responseText, forType: .string)

                    // 2. Save full response to exports folder as Markdown backup
                    let outPath = conv.geminiBriefPath(storageDir: storageDir)
                    try? responseText.write(toFile: outPath, atomically: true, encoding: .utf8)

                    // 3. Transition UI to completed state ("Returned summary copied to clipboard!")
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true

                    self.statusLabel.stringValue = "Returned summary copied to clipboard!"
                    self.statusLabel.textColor = NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0)
                    self.statusLabel.frame = NSRect(x: 20, y: self.panelHeight - 82, width: self.panelWidth - 40, height: 22)

                    self.previewTextView.string = responseText
                    self.previewScrollView.isHidden = false

                    self.closeButton.title = "Done"
                    self.closeButton.keyEquivalent = "\r" // Return

                    // 4. Start 0–5s progress bar countdown before auto-closing
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
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true

                    self.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    self.statusLabel.textColor = .systemRed
                    self.statusLabel.frame = NSRect(x: 20, y: self.panelHeight - 170, width: self.panelWidth - 40, height: 40)
                    self.closeButton.title = "Close"
                }
            }
        }
    }

    // MARK: - Timer & Button Actions

    @objc private func handleTimerTick(_ timer: Timer) {
        elapsedSeconds += timerTickInterval
        progressBar.doubleValue = min(elapsedSeconds, totalCountdownSeconds)
        if elapsedSeconds >= totalCountdownSeconds {
            timer.invalidate()
            dismissTimer = nil
            panel.orderOut(nil)
        }
    }

    @objc private func handleButtonClick() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentTask?.cancel()
        panel.orderOut(nil)
    }
}
