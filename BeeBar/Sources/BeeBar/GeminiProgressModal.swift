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
    private var closeButton: NSButton!
    private var dismissTimer: Timer?
    private var currentTask: Task<Void, Never>?

    override private init() {
        super.init()
        setupUI()
    }

    private func setupUI() {
        let width: CGFloat = 420
        let height: CGFloat = 260

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.title = "Gemini Summarization"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        visualEffect.layer?.borderWidth = 1.0

        // Title
        titleLabel = NSTextField(labelWithString: "Gemini AI Summary")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: height - 36, width: width - 40, height: 20)
        visualEffect.addSubview(titleLabel)

        // Subtitle (Conversation title & Model)
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: height - 56, width: width - 40, height: 16)
        visualEffect.addSubview(subtitleLabel)

        // Spinner
        spinner = NSProgressIndicator(frame: NSRect(x: (width - 32) / 2, y: height - 105, width: 32, height: 32))
        spinner.style = .spinning
        spinner.controlSize = .regular
        visualEffect.addSubview(spinner)

        // Status Label (e.g. "Sending to Gemini...", "Waiting...", "Returned summary copied to clipboard!")
        statusLabel = NSTextField(labelWithString: "Sending to Gemini...")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: height - 135, width: width - 40, height: 20)
        visualEffect.addSubview(statusLabel)

        // Preview Scroll View (hidden initially, shown on completion)
        previewScrollView = NSScrollView(frame: NSRect(x: 20, y: 52, width: width - 40, height: 120))
        previewScrollView.borderType = .noBorder
        previewScrollView.drawsBackground = false
        previewScrollView.hasVerticalScroller = true
        previewScrollView.isHidden = true

        previewTextView = NSTextView(frame: previewScrollView.contentView.bounds)
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.drawsBackground = false
        previewTextView.textColor = .labelColor
        previewTextView.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewScrollView.documentView = previewTextView
        visualEffect.addSubview(previewScrollView)

        // Close / Cancel Button
        closeButton = NSButton(title: "Cancel", target: self, action: #selector(handleButtonClick))
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: (width - 90) / 2, y: 14, width: 90, height: 28)
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
        currentTask?.cancel()

        titleLabel.stringValue = "Gemini AI Summary"
        subtitleLabel.stringValue = "\(conv.title) • \(model)"
        statusLabel.stringValue = "Sending to Gemini..."
        statusLabel.textColor = .labelColor

        spinner.isHidden = false
        spinner.startAnimation(nil)

        previewScrollView.isHidden = true
        previewTextView.string = ""

        closeButton.title = "Cancel"
        closeButton.keyEquivalent = "\u{1b}" // ESC

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        currentTask = Task { [weak self] in
            // Stage 1: "Sending to Gemini..."
            // Show brief sending feedback before waiting for network stream
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
                    // 1. Copy ENTIRE Gemini response to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(responseText, forType: .string)

                    // 2. Save to exports folder as markdown backup
                    let outPath = (storageDir as NSString).appendingPathComponent("conversations/\(conv.id)_gemini_brief.md")
                    try? responseText.write(toFile: outPath, atomically: true, encoding: .utf8)

                    // 3. Update Pop-up state
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true

                    self.statusLabel.stringValue = "Returned summary copied to clipboard!"
                    self.statusLabel.textColor = NSColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1.0) // Green
                    self.statusLabel.frame = NSRect(x: 20, y: 260 - 75, width: 380, height: 20)

                    self.previewTextView.string = responseText
                    self.previewScrollView.isHidden = false

                    self.closeButton.title = "Done"
                    self.closeButton.keyEquivalent = "\r" // Enter

                    // Auto dismiss after 4 seconds if user doesn't interact
                    self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.panel.orderOut(nil)
                        }
                    }
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    self?.spinner.stopAnimation(nil)
                    self?.spinner.isHidden = true

                    self?.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                    self?.closeButton.title = "Close"
                }
            }
        }
    }

    @objc private func handleButtonClick() {
        dismissTimer?.invalidate()
        currentTask?.cancel()
        panel.orderOut(nil)
    }
}
