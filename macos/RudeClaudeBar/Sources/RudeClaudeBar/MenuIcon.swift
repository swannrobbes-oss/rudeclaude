import AppKit

extension NSColor {
    static let rudeYellow = NSColor(srgbRed: 0xFE / 255, green: 0xC8 / 255, blue: 0x24 / 255, alpha: 1)
    static let rudeOrange = NSColor(srgbRed: 0xFF / 255, green: 0x8C / 255, blue: 0x28 / 255, alpha: 1)
    static let rudeRed = NSColor(srgbRed: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255, alpha: 1)

    static func fill(_ used: Double) -> NSColor {
        used >= 90 ? .rudeRed : used >= 70 ? .rudeOrange : .rudeYellow
    }
}

/// Menu bar label: a small ring like the dashboard's, the 5-hour percentage,
/// and a yellow speech bubble when Claude is waiting for an answer.
///
/// Drawn as one non-template image so the arc keeps its color. The text uses
/// labelColor, resolved at draw time against the menu bar's appearance.
enum MenuIcon {
    private static let height: CGFloat = 18
    private static let ring: CGFloat = 14
    private static let lineWidth: CGFloat = 2.2
    private static let gap: CGFloat = 4

    static func image(used: Double, asking: Bool) -> NSImage {
        let text = "\(Int(used.rounded())) %" as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let textSize = text.size(withAttributes: [.font: font])
        let bubble = asking ? bubbleImage() : nil
        let bubbleWidth = bubble.map { $0.size.width + gap + 1 } ?? 0
        let width = ceil(ring + gap + textSize.width + bubbleWidth)
        let fill = NSColor.fill(used)
        let fraction = min(max(used, 0), 100) / 100

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let center = NSPoint(x: ring / 2, y: height / 2)
            let radius = (ring - lineWidth) / 2

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            track.stroke()

            if fraction > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius,
                              startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                fill.setStroke()
                arc.stroke()
            }

            let x = ring + gap
            text.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2),
                      withAttributes: [.font: font, .foregroundColor: NSColor.labelColor])

            if let bubble {
                let size = bubble.size
                bubble.draw(in: NSRect(x: x + textSize.width + gap + 1, y: (height - size.height) / 2,
                                       width: size.width, height: size.height))
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Session 5 h : \(text)" + (asking ? ", Claude attend une réponse" : "")
        return image
    }

    private static func bubbleImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            .applying(.init(paletteColors: [NSColor(white: 0.1, alpha: 1), .rudeYellow]))
        return NSImage(systemSymbolName: "questionmark.bubble.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}
