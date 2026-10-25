import AppKit

public enum BeeIcon {
    // 28x28 @2x high-resolution tight-cropped template icon (pure black on alpha for 14pt menu bar size)
    private static let base64TemplateIcon = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAEDmlDQ1BrQ0dDb2xvclNwYWNlR2VuZXJpY1JHQgAAOI2NVV1oHFUUPpu5syskzoPUpqaSDv41lLRsUtGE2uj+ZbNt3CyTbLRBkMns3Z1pJjPj/KRpKT4UQRDBqOCT4P9bwSchaqvtiy2itFCiBIMo+ND6R6HSFwnruTOzu5O4a73L3PnmnO9+595z7t4LkLgsW5beJQIsGq4t5dPis8fmxMQ6dMF90A190C0rjpUqlSYBG+PCv9rt7yDG3tf2t/f/Z+uuUEcBiN2F2Kw4yiLiZQD+FcWyXYAEQfvICddi+AnEO2ycIOISw7UAVxieD/Cyz5mRMohfRSwoqoz+xNuIB+cj9loEB3Pw2448NaitKSLLRck2q5pOI9O9g/t/tkXda8Tbg0+PszB9FN8DuPaXKnKW4YcQn1Xk3HSIry5ps8UQ/2W5aQnxIwBdu7yFcgrxPsRjVXu8HOh0qao30cArp9SZZxDfg3h1wTzKxu5E/LUxX5wKdX5SnAzmDx4A4OIqLbB69yMesE1pKojLjVdoNsfyiPi45hZmAn3uLWdpOtfQOaVmikEs7ovj8hFWpz7EV6mel0L9Xy23FMYlPYZenAx0yDB1/PX6dledmQjikjkXCxqMJS9WtfFCyH9XtSekEF+2dH+P4tzITduTygGfv58a5VCTH5PtXD7EFZiNyUDBhHnsFTBgE0SQIA9pfFtgo6cKGuhooeilaKH41eDs38Ip+f4At1Rq/sjr6NEwQqb/I/DQqsLvaFUjvAx+eWirddAJZnAj1DFJL0mSg/gcIpPkMBkhoyCSJ8lTZIxk0TpKDjXHliJzZPO50dR5ASNSnzeLvIvod0HG/mdkmOC0z8VKnzcQ2M/Yz2vKldduXjp9bleLu0ZWn7vWc+l0JGcaai10yNrUnXLP/8Jf59ewX+c3Wgz+B34Df+vbVrc16zTMVgp9um9bxEfzPU5kPqUtVWxhs6OiWTVW+gIfywB9uXi7CGcGW/zk98k/kmvJ95IfJn/j3uQ+4c5zn3Kfcd+AyF3gLnJfcl9xH3OfR2rUee80a+6vo7EK5mmXUdyfQlrYLTwoZIU9wsPCZEtP6BWGhAlhL3p2N6sTjRdduwbHsG9kq32sgBepc+xurLPW4T9URpYGJ3ym4+8zA05u44QjST8ZIoVtu3qE7fWmdn5LPdqvgcZz8Ww8BWJ8X3w0PhQ/wnCDGd+LvlHs8dRy6bLLDuKMaZ20tZrqisPJ5ONiCq8yKhYM5cCgKOu66Lsc0aYOtZdo5QCwezI4wm9J/v0X23mlZXOfBjj8Jzv3WrY5D+CsA9D7aMs2gGfjve8ArD6mePZSeCfEYt8CONWDw8FXTxrPqx/r9Vt4biXeANh8vV7/+/16ffMD1N8AuKD/A/8leAvFY9bLAAAAbGVYSWZNTQAqAAAACAAEARoABQAAAAEAAAA+ARsABQAAAAEAAABGASgAAwAAAAEAAgAAh2kABAAAAAEAAABOAAAAAAAAAJAAAAABAAAAkAAAAAEAAqACAAQAAAABAAAAHKADAAQAAAABAAAAHAAAAAAOlx2kAAAACXBIWXMAABYlAAAWJQFJUiTwAAACl0lEQVRIDd2VzW9NQRTA66MqKBa+dyL1zUJiIYLaWJQNW6vaCH9AN3YSiYWNaiJSib1YNSFdtgQLiY/YIJFYSImkoq02iuL3e+25Ge+9693KrYWT/N6cO3NmzpkzZ+Y1Nf0up/gchp8zTNL2wFaYD0WkA6MpiDU+o++FRdAMmSxGG4BvoPEP6AINi8pKDB9DOLM9nzd5NwNDifEg+to845z+i/SblXD4CH1hapt+bGKgJRnsQx9PvhupBzA4DWlG+vk+CPOg5kiu05lGd4LvNAA+c2UFIw+h+uw+0WfQnqPteLrDF3R8hYhwKbqRFZFzGO2B2MVL9OMwCrlymJEPEPm/jG4RNJKjGLhwzLO90miS4xvAXVqdTnoH+2AB1BN3swteQ8wJpzo0OzWki5nnbbATvC/LYDvch9gBaiVtjm+BXtgx00eTiUEY/Cqw0tfAaqk+IyO+BW0QY068BndBx8uhHc6AlR12qJlMoI2AO45zVa9r3En/BVivQSJWmY+CRbUk6Ve12Nx1ODfoS1BYzmL5FuLVibOpbh1/D90QO9LGgpu1tDOjD1zoC7i4uBu/x6AfvPCbwTsXAfWg15X0HlYbDNDhZbZSD4GLtoDOXsEgPACD8OxTMe1eKVNsEEol3ZHz6a6//9XhPfDFUT7CEFgwXhmlUjx/2uG0WbHf2EVYP0fphbI2FOtm7Tq0NxAPwDN0/+5qJL34NYOz6PDeWTzeX1PnZfe8TfN3yKQsh6ZUp8cgdrYf3UfiCVjZcZao5YjBXwUdG0DwFL0TdB6vDmo5YpXeAO9oOIzW9B6B0qWVFX3W/KubhHBo6yMyZ9LByndgGCyccIw6d2KlngQLxxdKp/9ENuLlJoyWdS0aRe3Dfhts/3P5Bek6rOlMxIdAAAAAAElFTkSuQmCC"

    /// Creates a crisp, compact monochrome black & white template icon for the macOS menu bar (14x14 pt)
    public static func createIcon() -> NSImage {
        let targetSize = NSSize(width: 14, height: 14)

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
            ctx.fillEllipse(in: CGRect(x: 4.5, y: 1.5, width: 5.0, height: 8.0))

            // Head
            ctx.fillEllipse(in: CGRect(x: 5.0, y: 10.0, width: 4.0, height: 3.0))

            // Antennae
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.0)
            ctx.strokeLineSegments(between: [
                CGPoint(x: 5.5, y: 12.0), CGPoint(x: 3.5, y: 13.5),
                CGPoint(x: 8.5, y: 12.0), CGPoint(x: 10.5, y: 13.5)
            ])

            return true
        }
        fallback.isTemplate = true
        return fallback
    }
}
