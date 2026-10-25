import AppKit

public enum BeeIcon {
    // Official Bee.computer menu bar tray template icon (@2x 44x44)
    private static let base64OfficialTrayIcon = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAQAAAC0jZKKAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAD/h4/MvwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB+oEAwICIw/rXPQAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMTEtMTZUMTE6MTU6MTIrMDA6MDAdrLVLAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTExLTE2VDExOjE1OjEyKzAwOjAwbPEN9wAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNi0wNC0wM1QwMjowMjozNSswMDowMCCbUTMAAAKASURBVEjH7dYxaFVXHMfxj8+YpAlpNGKjKES0oiRWWlCRWEScakHRQQWr4lAHQR3UsWIzpDoJDqWLg6KDg0PcBLWlCtoh0rRDxcaUWONTEdPkgUk0McehL/G+5L7cG+xgIb8zXPif+/+e3z33/P/3MqUp/f81fZL3Z1SrEgwl3ThtUiY22GmFck9cd8Hf/82zlWuSE0ZHq8bJQzIxW3TIYAQbBG0Wpd+KauusUycj67YfPc3HF7rq43HZzb5J53S9awZGHQ1ptU0G7PB6jN8g+EV1GuxW2XGpOYdkcCQGG3RYkIz9TGdscq9N2B87d1dtErbE2djUIPhZlcaCEzEyLpmRBF7mUVHwoD1muDQu/sKWNPs7WBQc/Gq+Bm1jlmtO9su+CbBBcEaZehd1C4JX7jqoFKVmqo5boCR/7RMmLO+9co77yqcaVOjS6ql6m601V9DlphZ/xSWu0Zvg+bUrtpin0ocW2+7cmLdyz95RmxFV+SkBHAQDOtzxm6yhmNk+h/PlVKAd+lOgJx7/+GIE97bZtKuyJnafX+qRM6ws8QiUq9FicGy40nHPCxz0u6XJRvUWW+2o3xM9d1sZt2LG537QJuuxP5y32Uww3yfmos7FBPCwXcUfaLYllqrNb9Ms37mv25+OqVDjcgL6QHLR/PsOTkWSvkW99gkd704HXlbQSjvU4WBsbx45F6vSgTcUHMJeqzBHa1HwFZXpwA2eRNI6LQS7I9+Z6OjxZTosJb6PJJ7IV1apkzHdsN/RuMorpo+c1iXngZNmjUY/cMTDAux9X0d7RZoflukWqfFMp+GC+HJbNaoVZN3Qoj06OZk/oTiVqRD0efWOnClN6b3UG2Do8kFd+j3YAAAAAElFTkSuQmCC"

    /// Creates the authentic Bee.computer menu bar template icon
    public static func createIcon() -> NSImage {
        let targetSize = NSSize(width: 20, height: 20)

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

        // 3. Embedded authentic base64 template image
        if let data = Data(base64Encoded: base64OfficialTrayIcon),
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
