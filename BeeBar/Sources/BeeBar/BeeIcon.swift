import AppKit

public enum BeeIcon {
    public static func createIcon() -> NSImage {
        // 1. Try bundle resources for color icon
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "BeeColor@2x", withExtension: "png") ?? bundle.url(forResource: "BeeColor", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false // Colorized icon
            return img
        }

        // 2. Direct path relative to project
        let directPath = "/Users/joehagerman/Desktop/Bee Desktop/BeeBar/Resources/BeeColor@2x.png"
        if FileManager.default.fileExists(atPath: directPath),
           let img = NSImage(contentsOfFile: directPath) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }

        // 3. Fallback programmatic rendering
        let size = NSSize(width: 18, height: 18)
        let fallback = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let amber = NSColor(red: 245/255, green: 175/255, blue: 25/255, alpha: 1.0).cgColor
            let dark = NSColor(red: 25/255, green: 25/255, blue: 28/255, alpha: 1.0).cgColor

            // Body
            ctx.setFillColor(amber)
            ctx.fillEllipse(in: CGRect(x: 5.5, y: 2.0, width: 7.0, height: 10.0))

            // Stripes
            ctx.setStrokeColor(dark)
            ctx.setLineWidth(1.2)
            ctx.strokeLineSegments(between: [
                CGPoint(x: 5.5, y: 5.0), CGPoint(x: 12.5, y: 5.0),
                CGPoint(x: 5.5, y: 7.5), CGPoint(x: 12.5, y: 7.5)
            ])

            // Head
            ctx.setFillColor(dark)
            ctx.fillEllipse(in: CGRect(x: 6.5, y: 12.0, width: 5.0, height: 3.5))

            return true
        }
        fallback.isTemplate = false
        return fallback
    }
}
