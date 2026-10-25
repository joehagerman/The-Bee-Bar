import AppKit

public enum BeeIcon {
    // Custom stylized Bee menu bar tray template icon (@2x 44x44)
    // Matches the user's custom bee design with transparent eye and stripe cutouts
    private static let base64CustomTrayIcon = "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"

    /// Creates the custom Bee menu bar template icon
    public static func createIcon() -> NSImage {
        let targetSize = NSSize(width: 19, height: 19)

        // 1. Try bundle resources (trayTemplate@2x or trayTemplate)
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "trayTemplate@2x", withExtension: "png") ?? bundle.url(forResource: "trayTemplate", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = targetSize
            img.isTemplate = true
            return img
        }

        // 2. Direct path relative to project resources
        let directPath = "/Users/joehagerman/Desktop/Bee Desktop/BeeBar/Resources/trayTemplate@2x.png"
        if FileManager.default.fileExists(atPath: directPath),
           let img = NSImage(contentsOfFile: directPath) {
            img.size = targetSize
            img.isTemplate = true
            return img
        }

        // 3. Embedded base64 template image
        if let data = Data(base64Encoded: base64CustomTrayIcon),
           let img = NSImage(data: data) {
            img.size = targetSize
            img.isTemplate = true
            return img
        }

        let fallback = NSImage(size: targetSize)
        fallback.isTemplate = true
        return fallback
    }
}
