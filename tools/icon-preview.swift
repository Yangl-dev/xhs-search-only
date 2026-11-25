import AppKit
// 看一个图标在桌面上的样子。用法：swift tools/icon-preview.swift 图标1024.png 输出.png
// 画出：按 iOS 的圆角裁好的大图，以及浅色、深色桌面上的实际大小（60pt@3x = 180px，旁边放一个纯红方块代表官方小红书图标，
// 看两个放在一起会不会认混），还有设置里的小尺寸（29pt@3x = 87px）
let args = CommandLine.arguments
guard args.count == 3, let icon = NSImage(contentsOfFile: args[1]) else { fatalError("usage: icon-preview.swift icon.png out.png") }
let width: CGFloat = 1500, height: CGFloat = 760
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func fill(_ rect: NSRect, _ color: NSColor) { color.setFill(); rect.fill() }
func tile(_ rect: NSRect, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237).addClip()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}
func app(_ rect: NSRect) { tile(rect) { icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1) } }
func red(_ rect: NSRect) { tile(rect) { fill(rect, NSColor(red: 1, green: 0x24 / 255, blue: 0x42 / 255, alpha: 1)) } }
func gray(_ rect: NSRect, _ white: CGFloat) { tile(rect) { fill(rect, NSColor(white: white, alpha: 1)) } }
fill(NSRect(x: 0, y: 0, width: width, height: height), NSColor(white: 0.5, alpha: 1))
app(NSRect(x: 40, y: 40, width: 680, height: 680))
// 右边上下两块：浅色桌面、深色桌面
for (index, (wallpaper, other)) in [(NSColor(red: 0.86, green: 0.89, blue: 0.94, alpha: 1), CGFloat(0.97)), (NSColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1), CGFloat(0.22))].enumerated() {
    let panel = NSRect(x: 760, y: index == 0 ? 400 : 40, width: 700, height: 320)
    fill(panel, wallpaper)
    let y = panel.minY + 100
    gray(NSRect(x: panel.minX + 40, y: y, width: 180, height: 180), other)
    app(NSRect(x: panel.minX + 260, y: y, width: 180, height: 180))
    red(NSRect(x: panel.minX + 480, y: y, width: 180, height: 180))
    app(NSRect(x: panel.minX + 40, y: panel.minY + 8, width: 87, height: 87).offsetBy(dx: 0, dy: 0))
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
