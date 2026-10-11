import AppKit

let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)
image.lockFocus()

guard let context = NSGraphicsContext.current else {
    fatalError("Could not create drawing context")
}
context.imageInterpolation = .high

let outerRect = NSRect(x: 76, y: 76, width: 872, height: 872)
let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 196, yRadius: 196)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
shadow.shadowBlurRadius = 48
shadow.shadowOffset = NSSize(width: 0, height: -28)
shadow.set()

let background = NSGradient(
    starting: NSColor(srgbRed: 0.075, green: 0.149, blue: 0.227, alpha: 1),
    ending: NSColor(srgbRed: 0.027, green: 0.063, blue: 0.114, alpha: 1)
)!
background.draw(in: outerPath, angle: -45)

NSGraphicsContext.saveGraphicsState()
NSShadow().set()
let innerPath = NSBezierPath(roundedRect: NSRect(x: 110, y: 110, width: 804, height: 804), xRadius: 166, yRadius: 166)
innerPath.lineWidth = 4
NSColor.white.withAlphaComponent(0.09).setStroke()
innerPath.stroke()

let blue = NSColor(srgbRed: 0.23, green: 0.64, blue: 1.0, alpha: 1)
blue.setStroke()

let left = NSBezierPath()
left.move(to: NSPoint(x: 351, y: 694))
left.line(to: NSPoint(x: 190, y: 512))
left.line(to: NSPoint(x: 351, y: 330))
left.lineWidth = 68
left.lineCapStyle = .round
left.lineJoinStyle = .round
left.stroke()

let right = NSBezierPath()
right.move(to: NSPoint(x: 673, y: 694))
right.line(to: NSPoint(x: 834, y: 512))
right.line(to: NSPoint(x: 673, y: 330))
right.lineWidth = 68
right.lineCapStyle = .round
right.lineJoinStyle = .round
right.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let font = NSFont(name: "Menlo-Bold", size: 246) ?? .monospacedSystemFont(ofSize: 246, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(srgbRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
    .paragraphStyle: paragraph
]
NSAttributedString(string: "++", attributes: attributes)
    .draw(in: NSRect(x: 250, y: 383, width: 524, height: 290))
NSGraphicsContext.restoreGraphicsState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
try png.write(to: URL(fileURLWithPath: output), options: .atomic)
