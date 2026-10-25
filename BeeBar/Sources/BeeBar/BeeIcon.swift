import AppKit

public enum BeeIcon {
    public static func createTemplateIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // Set monochrome drawing color
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.2)
            ctx.setLineCap(.round)

            // Wings (left and right)
            ctx.saveGState()
            let leftWing = CGMutablePath()
            leftWing.addEllipse(in: CGRect(x: 1.5, y: 7.5, width: 6.0, height: 4.5))
            ctx.addPath(leftWing)

            let rightWing = CGMutablePath()
            rightWing.addEllipse(in: CGRect(x: 10.5, y: 7.5, width: 6.0, height: 4.5))
            ctx.addPath(rightWing)
            ctx.fillPath()
            ctx.restoreGState()

            // Main Body (abdomen + thorax)
            let bodyRect = CGRect(x: 5.5, y: 2.0, width: 7.0, height: 9.5)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            ctx.addPath(bodyPath)
            ctx.fillPath()

            // Cutout stripes (blend mode clear)
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.setLineWidth(1.1)
            ctx.strokeLineSegments(between: [
                CGPoint(x: 5.5, y: 4.5), CGPoint(x: 12.5, y: 4.5),
                CGPoint(x: 5.5, y: 7.0), CGPoint(x: 12.5, y: 7.0)
            ])
            ctx.restoreGState()

            // Head
            let headRect = CGRect(x: 6.5, y: 11.5, width: 5.0, height: 3.5)
            ctx.fillEllipse(in: headRect)

            // Antennae
            ctx.setLineWidth(1.0)
            ctx.strokeLineSegments(between: [
                CGPoint(x: 7.5, y: 14.5), CGPoint(x: 6.0, y: 16.5),
                CGPoint(x: 10.5, y: 14.5), CGPoint(x: 12.0, y: 16.5)
            ])

            return true
        }

        image.isTemplate = true
        return image
    }
}
