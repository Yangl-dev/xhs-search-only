import AppKit
// 「圆润」这一套的桌面图标：淡粉的底上一个胖胖的放大镜，镜框和手柄是「珊瑚 → 红」的渐变（跟 app 里的搜索按钮、用量圆环一个颜色，
// 见 DesignC+Kit.swift 的 Palette.coral / red），镜片是白的，底下一圈淡淡的红晕。
// 底是明确的淡粉（太白的话在浅色壁纸和白色的设置列表上边缘会化掉）、红色只在放大镜上，跟官方那个整块红底的图标放一起不会认混。
// 用法：swift tools/make-icon-c.swift 输出目录
// 输出 icon-1024.png（桌面图标：1024×1024、不透明、不带圆角——圆角由 iOS 来裁）和 icon-256.png（设置里显示的小图）
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

/// 在 size×size 的不透明画布上画，坐标按 1024 写（左下角是原点）
func render(size: Int, draw: (CGContext) -> Void) -> Data {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(context)
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// 在一个形状里填一道渐变
func fill(_ c: CGContext, _ path: CGPath, from start: (UInt32, CGPoint), to end: (UInt32, CGPoint)) {
    c.saveGState()
    c.addPath(path)
    c.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [color(start.0), color(end.0)] as CFArray, locations: nil)!
    c.drawLinearGradient(gradient, start: start.1, end: end.1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    c.restoreGState()
}

let red: UInt32 = 0xFF2442      // 小红书的红
let coral: UInt32 = 0xFF7A5C    // 渐变里红色的搭档

func drawIcon(_ c: CGContext) {
    // 底：从上到下，淡粉到再深一点的粉
    fill(c, CGPath(rect: CGRect(x: 0, y: 0, width: 1024, height: 1024), transform: nil),
         from: (0xFFE4E8, CGPoint(x: 0, y: 1024)), to: (0xFFCDD6, CGPoint(x: 0, y: 0)))

    // 放大镜：一个粗圆环加一截圆头的手柄，合成一个形状
    let center = CGPoint(x: 462, y: 562), radius: CGFloat = 212, width: CGFloat = 118
    let lens = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
    let diagonal = CGFloat(0.5).squareRoot()
    let handle = CGMutablePath()
    handle.move(to: CGPoint(x: center.x + (radius + 32) * diagonal, y: center.y - (radius + 32) * diagonal))
    handle.addLine(to: CGPoint(x: center.x + (radius + 196) * diagonal, y: center.y - (radius + 196) * diagonal))
    let magnifier = CGMutablePath()
    magnifier.addPath(lens.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
    magnifier.addPath(handle.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))

    // 先画它的红晕（往下偏一点，像浮在底上）
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -38), blur: 72, color: color(red, alpha: 0.32))
    c.addPath(magnifier)
    c.setFillColor(color(red))
    c.fillPath()
    c.restoreGState()

    // 白镜片，再盖上渐变的镜框和手柄
    c.addPath(lens)
    c.setFillColor(color(0xFFFFFF))
    c.fillPath()
    fill(c, magnifier, from: (coral, CGPoint(x: 230, y: 820)), to: (red, CGPoint(x: 800, y: 230)))
}

for size in [1024, 256] {
    try! render(size: size, draw: drawIcon).write(to: URL(fileURLWithPath: "\(out)/icon-\(size).png"))
}
print("wrote \(out)/icon-1024.png and icon-256.png")
