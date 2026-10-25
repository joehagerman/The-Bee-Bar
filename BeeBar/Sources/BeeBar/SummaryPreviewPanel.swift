//
//  SummaryPreviewPanel.swift
//  BeeBar
//
//  Floating non-activating vibrancy panel displayed to the left of the status bar NSMenu
//  whenever the user hovers over a conversation item.
//

import AppKit

/// Floating popover-styled panel that previews a conversation's full summary alongside the open menu.
@MainActor
public final class SummaryPreviewPanel: NSObject {
    public static let shared = SummaryPreviewPanel()

    // MARK: - Layout Constants

    private let defaultWidth: CGFloat = 380
    private let defaultHeight: CGFloat = 420

    // MARK: - UI Components

    private var panel: NSPanel!
    private var visualEffectView: NSVisualEffectView!
    private var titleLabel: NSTextField!
    private var metaLabel: NSTextField!
    private var tagsLabel: NSTextField!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!

    // MARK: - Initialization

    override private init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true

        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight))
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10
        visualEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.autoresizingMask = [.width, .height]

        // 1. Conversation Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 2
        titleLabel.cell?.wraps = true
        titleLabel.cell?.isScrollable = false
        titleLabel.frame = NSRect(x: 14, y: defaultHeight - 46, width: defaultWidth - 28, height: 36)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(titleLabel)

        // 2. Metadata Subtitle (Date • Duration • Utterance Turns)
        metaLabel = NSTextField(labelWithString: "")
        metaLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.frame = NSRect(x: 14, y: defaultHeight - 64, width: defaultWidth - 28, height: 16)
        metaLabel.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(metaLabel)

        // 3. Header Divider
        let separator = NSBox(frame: NSRect(x: 14, y: defaultHeight - 72, width: defaultWidth - 28, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(separator)

        // 4. Category Tags Footer
        tagsLabel = NSTextField(labelWithString: "")
        tagsLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        tagsLabel.textColor = .tertiaryLabelColor
        tagsLabel.frame = NSRect(x: 14, y: 10, width: defaultWidth - 28, height: 16)
        tagsLabel.autoresizingMask = [.width, .maxYMargin]
        visualEffectView.addSubview(tagsLabel)

        // 5. Scrollable Executive Summary Body
        scrollView = NSScrollView(frame: NSRect(x: 14, y: 32, width: defaultWidth - 28, height: defaultHeight - 110))
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

    // MARK: - Presentation

    /// Updates the panel contents and positions it immediately to the left of `menuFrame`.
    public func show(for conv: BeeConversationItem, summary: String, menuFrame: NSRect) {
        titleLabel.stringValue = conv.title

        let dateStr = conv.relativeDateString
        let durStr = conv.formattedDuration ?? ""
        let turnsStr = conv.utteranceCount.map { "\($0) turns" } ?? ""
        metaLabel.stringValue = [dateStr, durStr, turnsStr].filter { !$0.isEmpty }.joined(separator: " • ")

        if let tags = conv.tags, !tags.isEmpty {
            tagsLabel.stringValue = "Categories: " + tags.joined(separator: ", ")
        } else {
            tagsLabel.stringValue = ""
        }

        textView.string = summary.isEmpty ? "No summary text captured for this conversation." : summary

        let panelHeight: CGFloat = min(max(320, menuFrame.height), 460)
        var screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        for s in NSScreen.screens where s.frame.intersects(menuFrame) {
            screenFrame = s.visibleFrame
            break
        }

        // Place on the left side of the menu with an 8pt margin (or flip to right if near left screen edge)
        var x = menuFrame.minX - defaultWidth - 8
        if x < screenFrame.minX {
            x = menuFrame.maxX + 8
        }

        let y = min(menuFrame.maxY - panelHeight, screenFrame.maxY - panelHeight)
        panel.setFrame(
            NSRect(x: x, y: max(screenFrame.minY, y), width: defaultWidth, height: panelHeight),
            display: true
        )
        panel.orderFront(nil)
    }

    /// Hides the preview panel.
    public func hide() {
        panel?.orderOut(nil)
    }
}
