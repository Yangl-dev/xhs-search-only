import AppKit
// 图标都用脚本画，改起来方便、随时能重画。这是个例子（画的就是现在的占位图标），每套设计照着写自己的 tools/make-icon-<a|b|c|d>.swift。
// 用法：swift tools/make-icon-example.swift 输出目录
// 输出 icon-1024.png（桌面图标：1024×1024、不透明、不带圆角——圆角由 iOS 来裁）和 icon-256.png（设置里显示的小图）
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

/// 在 size×size 的不透明画布上画，坐标按 1024 写（左下角是原点）
func render(size: Int, draw: (CGContext) -> Void) -> Data {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false) // 这样 NSBezierPath、NSString.draw 也能用
    draw(context)
    NSGraphicsContext.current = nil
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func drawIcon(_ c: CGContext) {
    c.setFillColor(color(0x34C759))
    c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    // 放大镜：一个圆环加一截圆头的手柄
    c.setStrokeColor(color(0xFFFFFF))
    c.setLineWidth(84)
    c.setLineCap(.round)
    c.strokeEllipse(in: CGRect(x: 262, y: 362, width: 400, height: 400))
    c.move(to: CGPoint(x: 618, y: 406))
    c.addLine(to: CGPoint(x: 772, y: 252))
    c.strokePath()
}

for size in [1024, 256] {
    try! render(size: size, draw: drawIcon).write(to: URL(fileURLWithPath: "\(out)/icon-\(size).png"))
}
print("wrote \(out)/icon-1024.png and icon-256.png")
