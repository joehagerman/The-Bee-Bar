import AppKit

public enum BeeIcon {
    // Custom stylized Bee menu bar tray template icon (@2x 44x44)
    // Matches user's updated icon design with circular keyhole notch wings and transparent stripe cutouts
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
