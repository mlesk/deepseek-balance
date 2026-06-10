import AppKit

enum IconGenerator {

    /// Loads the deepseek.png from the bundle Resources.
    private static func loadPNG() -> NSImage? {
        // Try main bundle first (for .app), then module bundle (for SPM)
        if let path = Bundle.main.path(forResource: "deepseek", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        if let path = Bundle.module.path(forResource: "deepseek", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }

    /// Standard template icon — adapts to light/dark menu bar.
    static func menuBarIcon() -> NSImage {
        guard let image = loadPNG() else {
            return drawIcon(fillColor: NSColor.black, isTemplate: true)
        }
        let sized = NSImage(size: NSSize(width: 18, height: 18))
        sized.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        sized.unlockFocus()
        sized.isTemplate = true
        return sized
    }

    /// Red warning icon — used when balance drops below the threshold.
    static func warningIcon() -> NSImage {
        guard let image = loadPNG() else {
            return drawIcon(fillColor: NSColor.systemRed, isTemplate: false)
        }
        let sized = NSImage(size: NSSize(width: 18, height: 18))
        sized.lockFocus()
        NSColor.systemRed.set()
        NSRect(x: 0, y: 0, width: 18, height: 18).fill(using: .sourceAtop)
        image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        sized.unlockFocus()
        sized.isTemplate = false
        return sized
    }

    // MARK: - Shared drawing

    private static func drawIcon(fillColor: NSColor, isTemplate: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let w = rect.width
            let h = rect.height
            let scale: CGFloat = 0.85
            let ox = (w - w * scale) / 2
            let oy = (h - h * scale) / 2

            let path = CGMutablePath()

            // Left lobe
            path.move(to:     CGPoint(x: ox + w * scale * 0.50, y: oy + h * scale * 0.10))
            path.addCurve(to: CGPoint(x: ox + w * scale * 0.10, y: oy + h * scale * 0.45),
                          control1: CGPoint(x: ox + w * scale * 0.42, y: oy + h * scale * 0.10),
                          control2: CGPoint(x: ox + w * scale * 0.15, y: oy + h * scale * 0.20))
            path.addCurve(to: CGPoint(x: ox + w * scale * 0.50, y: oy + h * scale * 0.50),
                          control1: CGPoint(x: ox + w * scale * 0.05, y: oy + h * scale * 0.70),
                          control2: CGPoint(x: ox + w * scale * 0.50, y: oy + h * scale * 0.50))

            // Right lobe
            path.addCurve(to: CGPoint(x: ox + w * scale * 0.90, y: oy + h * scale * 0.45),
                          control1: CGPoint(x: ox + w * scale * 0.50, y: oy + h * scale * 0.50),
                          control2: CGPoint(x: ox + w * scale * 0.95, y: oy + h * scale * 0.70))
            path.addCurve(to: CGPoint(x: ox + w * scale * 0.50, y: oy + h * scale * 0.10),
                          control1: CGPoint(x: ox + w * scale * 0.85, y: oy + h * scale * 0.20),
                          control2: CGPoint(x: ox + w * scale * 0.58, y: oy + h * scale * 0.10))

            path.closeSubpath()

            // Wave line
            path.move(to:     CGPoint(x: ox + w * scale * 0.05, y: oy + h * scale * 0.80))
            path.addCurve(to: CGPoint(x: ox + w * scale * 0.95, y: oy + h * scale * 0.80),
                          control1: CGPoint(x: ox + w * scale * 0.30, y: oy + h * scale * 0.90),
                          control2: CGPoint(x: ox + w * scale * 0.70, y: oy + h * scale * 0.70))

            ctx.addPath(path)
            ctx.setFillColor(fillColor.cgColor)
            ctx.fillPath()

            return true
        }
        image.isTemplate = isTemplate
        return image
    }
}
