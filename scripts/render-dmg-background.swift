import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "build/dmg-background/background.png"

let points = CGSize(width: 720, height: 540)
let scale: CGFloat = 2
let pixels = CGSize(width: points.width * scale, height: points.height * scale)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixels.width),
    pixelsHigh: Int(pixels.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("无法创建画布\n", stderr)
    exit(1)
}
rep.size = NSSize(width: points.width, height: points.height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func fromTop(_ top: CGFloat, height: CGFloat) -> CGFloat {
    points.height - top - height
}

func drawCentered(_ text: String, top: CGFloat, fontSize: CGFloat, weight: NSFont.Weight, paint: NSColor) -> CGFloat {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: paint,
        .paragraphStyle: style,
    ]
    let textHeight = (text as NSString).size(withAttributes: attributes).height
    let rect = CGRect(x: 0, y: fromTop(top, height: textHeight), width: points.width, height: textHeight)
    (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attributes)
    return textHeight
}

let bounds = CGRect(origin: .zero, size: points)
NSGradient(colors: [color(0xF7F8FC), color(0xEEF2FA)])!.draw(in: bounds, angle: 90)

let glowRect = CGRect(x: 140, y: fromTop(-20, height: 260), width: 440, height: 260)
NSGradient(colors: [color(0x3AA0FF, alpha: 0.18), color(0xF5C451, alpha: 0)])!
    .draw(in: glowRect, relativeCenterPosition: .zero)

_ = drawCentered("WageJump", top: 42, fontSize: 52, weight: .bold, paint: color(0x1C1E26))

let badgeText = "Universal · Apple Silicon & Intel"
let badgeFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
let badgeTextSize = (badgeText as NSString).size(withAttributes: [.font: badgeFont])
let badgeHeight: CGFloat = 30
let badgeWidth = badgeTextSize.width + 32
let badgeRect = CGRect(
    x: (points.width - badgeWidth) / 2,
    y: fromTop(116, height: 30),
    width: badgeWidth,
    height: badgeHeight
)
let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
NSGradient(colors: [color(0x2F9BFF), color(0x6B4DFF)])!.draw(in: badgePath, angle: 0)
let badgeStyle = NSMutableParagraphStyle()
badgeStyle.alignment = .center
let badgeTextRect = badgeRect.insetBy(dx: 0, dy: max(0, (badgeHeight - badgeTextSize.height) / 2))
(badgeText as NSString).draw(
    with: badgeTextRect,
    options: [.usesLineFragmentOrigin],
    attributes: [
        .font: badgeFont,
        .foregroundColor: NSColor.white,
        .paragraphStyle: badgeStyle,
    ]
)

_ = drawCentered(
    "把 WageJump 拖到右侧「应用程序」文件夹",
    top: 162,
    fontSize: 18,
    weight: .medium,
    paint: color(0x5C6370)
)

let iconCenterFromTop: CGFloat = 330
let leftX: CGFloat = 196
let rightX: CGFloat = 524
let arrowY = fromTop(iconCenterFromTop, height: 0)
let arrowStart = leftX + 84
let arrowEnd = rightX - 118
let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.move(to: CGPoint(x: arrowStart, y: arrowY))
arrow.line(to: CGPoint(x: arrowEnd - 10, y: arrowY))
let arrowContext = NSGraphicsContext.current!.cgContext
arrowContext.saveGState()
arrowContext.addPath(arrow.cgPath)
arrowContext.setLineWidth(5)
arrowContext.setLineCap(.round)
arrowContext.replacePathWithStrokedPath()
arrowContext.clip()
if let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0x2F9BFF).cgColor, color(0x6B4DFF).cgColor] as CFArray,
    locations: [0, 1]
) {
    arrowContext.drawLinearGradient(
        gradient,
        start: CGPoint(x: arrowStart, y: arrowY),
        end: CGPoint(x: arrowEnd, y: arrowY),
        options: []
    )
}
arrowContext.restoreGState()

let head = NSBezierPath()
head.lineWidth = 5
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: CGPoint(x: arrowEnd - 18, y: arrowY - 9))
head.line(to: CGPoint(x: arrowEnd, y: arrowY))
head.line(to: CGPoint(x: arrowEnd - 18, y: arrowY + 9))
color(0x6B4DFF).setStroke()
head.stroke()

_ = drawCentered(
    "首次打开请在「应用程序」里右键 WageJump，选择「打开」",
    top: 488,
    fontSize: 12,
    weight: .regular,
    paint: color(0x8A909A)
)
_ = drawCentered(
    "若仍被拦截，请到「系统设置 → 隐私与安全性」中点「仍要打开」",
    top: 508,
    fontSize: 12,
    weight: .regular,
    paint: color(0x8A909A)
)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("无法导出 PNG\n", stderr)
    exit(1)
}
let url = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: url)
print(url.path)
