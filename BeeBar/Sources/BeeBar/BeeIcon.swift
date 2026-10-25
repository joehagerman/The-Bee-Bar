import AppKit

public enum BeeIcon {
    // 48x48 @2x high-resolution tight-cropped template icon (pure black on alpha)
    private static let base64TemplateIcon = "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"

    /// Creates a large, crisp monochrome black & white template icon for the macOS menu bar
    public static func createIcon() -> NSImage {
        let targetSize = NSSize(width: 24, height: 24)

        // 1. Try bundle resources (supports high-DPI @2x and @3x)
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "BeeTemplate@2x", withExtension: "png") ?? bundle.url(forResource: "BeeTemplate", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = targetSize
            img.isTemplate = true // Renders black in Light Mode, white in Dark Mode
            return img
        }

        // 2. Direct path relative to project resources
        let directPath = "/Users/joehagerman/Desktop/Bee Desktop/BeeBar/Resources/BeeTemplate@2x.png"
        if FileManager.default.fileExists(atPath: directPath),
           let img = NSImage(contentsOfFile: directPath) {
            img.size = targetSize
            img.isTemplate = true
            return img
        }

        // 3. Embedded base64 template image
        if let data = Data(base64Encoded: base64TemplateIcon),
           let img = NSImage(data: data) {
            img.size = targetSize
            img.isTemplate = true
            return img
        }

        // 4. Clean vector fallback
        let fallback = NSImage(size: targetSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)

            // Body
            ctx.fillEllipse(in: CGRect(x: 8.0, y: 3.0, width: 8.0, height: 13.0))

            // Head
            ctx.fillEllipse(in: CGRect(x: 9.0, y: 17.0, width: 6.0, height: 4.5))

            // Antennae
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.4)
            ctx.strokeLineSegments(between: [
                CGPoint(x: 10.0, y: 20.0), CGPoint(x: 7.0, y: 23.0),
                CGPoint(x: 14.0, y: 20.0), CGPoint(x: 17.0, y: 23.0)
            ])

            // Wings
            ctx.strokeEllipse(in: CGRect(x: 3.0, y: 9.0, width: 6.0, height: 10.0))
            ctx.strokeEllipse(in: CGRect(x: 15.0, y: 9.0, width: 6.0, height: 10.0))

            return true
        }
        fallback.isTemplate = true
        return fallback
    }
}
