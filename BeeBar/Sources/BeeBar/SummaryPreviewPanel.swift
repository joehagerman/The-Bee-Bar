import AppKit

@MainActor
public final class SummaryPreviewPanel: NSObject {
    public static let shared = SummaryPreviewPanel()

    private var panel: NSPanel!
    private var visualEffectView: NSVisualEffectView!
    private var titleLabel: NSTextField!
    private var metaLabel: NSTextField!
    private var tagsLabel: NSTextField!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!

    override private init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let width: CGFloat = 380
        let height: CGFloat = 420

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu // Matches or floats next to NSMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true

        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10
        visualEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.autoresizingMask = [.width, .height]

        // 1. Title Label
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 2
        titleLabel.cell?.wraps = true
        titleLabel.cell?.isScrollable = false
        titleLabel.frame = NSRect(x: 14, y: height - 46, width: width - 28, height: 36)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(titleLabel)

        // 2. Metadata line
        metaLabel = NSTextField(labelWithString: "")
        metaLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.frame = NSRect(x: 14, y: height - 64, width: width - 28, height: 16)
        metaLabel.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(metaLabel)

        // 3. Separator Line
        let separator = NSBox(frame: NSRect(x: 14, y: height - 72, width: width - 28, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(separator)

        // 4. Tags / Keywords Line (at bottom)
        tagsLabel = NSTextField(labelWithString: "")
        tagsLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        tagsLabel.textColor = .tertiaryLabelColor
        tagsLabel.frame = NSRect(x: 14, y: 10, width: width - 28, height: 16)
        tagsLabel.autoresizingMask = [.width, .maxYMargin]
        visualEffectView.addSubview(tagsLabel)

        // 5. Scrollable Text Area for Full Executive Summary
        scrollView = NSScrollView(frame: NSRect(x: 14, y: 32, width: width - 28, height: height - 110))
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        visualEffectView.addSubview(scrollView)

        panel.contentView = visualEffectView
    }

    public func show(for conv: BeeConversationItem, summary: String, menuFrame: NSRect) {
        titleLabel.stringValue = conv.title

        let dateStr = conv.relativeDateString
        let durStr = conv.formattedDuration ?? ""
        let turnsStr = (conv.utteranceCount != nil) ? "\(conv.utteranceCount!) turns" : ""
        let meta = [dateStr, durStr, turnsStr].filter { !$0.isEmpty }.joined(separator: " • ")
        metaLabel.stringValue = meta

        var tagsText = ""
        if let tags = conv.tags, !tags.isEmpty {
            tagsText = "Categories: " + tags.joined(separator: ", ")
        }
        tagsLabel.stringValue = tagsText

        // Clean executive summary text
        let cleanText = summary.isEmpty ? "No summary text captured for this conversation." : summary
        textView.string = cleanText

        // Position directly to the LEFT of the active menu window
        let panelWidth: CGFloat = 380
        let panelHeight: CGFloat = min(max(320, menuFrame.height), 460)

        var screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        for s in NSScreen.screens {
            if s.frame.intersects(menuFrame) {
                screenFrame = s.visibleFrame
                break
            }
        }

        // Place on the LEFT of the menu with an 8pt gap
        var x = menuFrame.minX - panelWidth - 8
        if x < screenFrame.minX {
            // If screen edge doesn't have room on left, flip to right
            x = menuFrame.maxX + 8
        }

        let y = min(menuFrame.maxY - panelHeight, screenFrame.maxY - panelHeight)
        panel.setFrame(NSRect(x: x, y: max(screenFrame.minY, y), width: panelWidth, height: panelHeight), display: true)

        panel.orderFront(nil)
    }

    public func hide() {
        panel?.orderOut(nil)
    }
}
