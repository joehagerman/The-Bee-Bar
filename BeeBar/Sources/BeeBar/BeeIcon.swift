//
//  BeeIcon.swift
//  BeeBar
//
//  Provides the custom monochrome template icon for the macOS status bar item.
//  Configured with `isTemplate = true` so macOS automatically adapts the icon
//  tint across Light Mode, Dark Mode, and active menu highlight states.
//

import AppKit

/// Factory for creating the BeeBar menu bar status item icon.
public enum BeeIcon {

    // MARK: - Embedded Fallback Asset

    /// Base64-encoded @2x (44x44px) PNG representation of the custom stylized Bee template icon.
    /// Features dual antennae dots, a triangular head, tapering horizontal body stripes, and a pointed stinger.
    private static let base64CustomTrayIcon = "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"

    /// Standard optical point size for the status bar icon.
    private static let iconPointSize = NSSize(width: 19, height: 19)

    // MARK: - Icon Construction

    /// Loads and returns the BeeBar status item template icon.
    ///
    /// Resolution order:
    /// 1. App bundle `Resources/trayTemplate@2x.png` or `trayTemplate.png`
    /// 2. Embedded base64 PNG representation (`base64CustomTrayIcon`)
    /// 3. Empty template fallback of `iconPointSize`
    public static func createIcon() -> NSImage {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "trayTemplate@2x", withExtension: "png")
            ?? bundle.url(forResource: "trayTemplate", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = iconPointSize
            img.isTemplate = true
            return img
        }

        if let data = Data(base64Encoded: base64CustomTrayIcon),
           let img = NSImage(data: data) {
            img.size = iconPointSize
            img.isTemplate = true
            return img
        }

        let fallback = NSImage(size: iconPointSize)
        fallback.isTemplate = true
        return fallback
    }
}
