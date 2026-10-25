import AppKit

@MainActor
public final class GeminiProgressModal: NSObject {
    public static let shared = GeminiProgressModal()

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
    private var dismissTimer: Timer?
    private var currentTask: Task<Void, Never>?
    private var elapsedSeconds: Double = 0.0
    private let totalCountdownSeconds: Double = 5.0

    override private init() {
        super.init()
        setupUI()
    }

    private func setupUI() {
        let width: CGFloat = 480
        let height: CGFloat = 360

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
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

        visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        visualEffect.layer?.borderWidth = 1.0

        // Title
        titleLabel = NSTextField(labelWithString: "Gemini AI Summary")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: height - 38, width: width - 40, height: 22)
        visualEffect.addSubview(titleLabel)

        // Subtitle (Conversation title & Model)
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: height - 58, width: width - 40, height: 16)
        visualEffect.addSubview(subtitleLabel)

        // Spinner (shown while waiting)
        spinner = NSProgressIndicator(frame: NSRect(x: (width - 32) / 2, y: height - 150, width: 32, height: 32))
        spinner.style = .spinning
        spinner.controlSize = .regular
        visualEffect.addSubview(spinner)

        // Status Label (e.g. "Sending to Gemini...", "Waiting...", "Returned summary copied to clipboard!")
        statusLabel = NSTextField(labelWithString: "Sending to Gemini...")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: height - 190, width: width - 40, height: 22)
        visualEffect.addSubview(statusLabel)

        // Preview Scroll View (displays full returned Gemini brief)
        previewScrollView = NSScrollView(frame: NSRect(x: 20, y: 78, width: width - 40, height: 195))
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

        // 0 to 5 second Progress Bar (determinate)
        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: width - 40, height: 12))
        progressBar.isIndeterminate = false
        progressBar.style = .bar
        progressBar.minValue = 0.0
        progressBar.maxValue = totalCountdownSeconds
        progressBar.doubleValue = 0.0
        progressBar.controlSize = .small
        progressBar.isHidden = true
        visualEffect.addSubview(progressBar)

        // Close / Cancel / Done Button
        closeButton = NSButton(title: "Cancel", target: self, action: #selector(handleButtonClick))
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: (width - 110) / 2, y: 14, width: 110, height: 28)
        visualEffect.addSubview(closeButton)

        panel.contentView = visualEffect
    }

    public func startSummarization(
        conv: BeeConversationItem,
        sourceText: String,
        apiKey: String,
        model: String,
        storageDir: String
    ) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentTask?.cancel()
        elapsedSeconds = 0.0

        titleLabel.stringValue = "Gemini AI Summary"
        subtitleLabel.stringValue = "\(conv.title) • \(model)"

        // Initial loading state
        spinner.isHidden = false
        spinner.startAnimation(nil)

        statusLabel.stringValue = "Sending to Gemini..."
        statusLabel.textColor = .labelColor
        statusLabel.frame = NSRect(x: 20, y: 360 - 190, width: 480 - 40, height: 22)

        previewScrollView.isHidden = true
        previewTextView.string = ""

        progressBar.isHidden = true
        progressBar.doubleValue = 0.0

        closeButton.title = "Cancel"
        closeButton.keyEquivalent = "\u{1b}" // ESC

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
                    model: model
                )

                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    guard let self = self else { return }

                    // 1. Copy ENTIRE Gemini response payload to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(responseText, forType: .string)

                    // 2. Save full response to exports folder as markdown backup
                    let outPath = (storageDir as NSString).appendingPathComponent("conversations/\(conv.id)_gemini_brief.md")
                    try? responseText.write(toFile: outPath, atomically: true, encoding: .utf8)

                    // 3. Update Pop-up state
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true

                    self.statusLabel.stringValue = "Returned summary copied to clipboard!"
                    self.statusLabel.textColor = NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0) // Green
                    self.statusLabel.frame = NSRect(x: 20, y: 360 - 82, width: 480 - 40, height: 22)

                    self.previewTextView.string = responseText
                    self.previewScrollView.isHidden = false

                    self.closeButton.title = "Done"
                    self.closeButton.keyEquivalent = "\r" // Enter

                    // 4. Progress bar running from 0 to 5 seconds
                    self.progressBar.isHidden = false
                    self.progressBar.doubleValue = 0.0
                    self.elapsedSeconds = 0.0

                    self.dismissTimer = Timer.scheduledTimer(
                        timeInterval: 0.05,
                        target: self,
                        selector: #selector(self.handleTimerTick(_:)),
                        userInfo: nil,
                        repeats: true
                    )
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    self?.spinner.stopAnimation(nil)
                    self?.spinner.isHidden = true

                    self?.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                    self?.statusLabel.frame = NSRect(x: 20, y: 360 - 170, width: 480 - 40, height: 40)
                    self?.closeButton.title = "Close"
                }
            }
        }
    }

    @objc private func handleTimerTick(_ timer: Timer) {
        elapsedSeconds += 0.05
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
