import AppKit
// 「极简」的桌面图标：黑底，靠下放一个白色描边的搜索框，里面一个小放大镜和一根红色的输入光标。
// 画的就是这套界面本身：上面空着，搜索框沉在底下，唯一的颜色是那根红光标。
// 试过又放弃的：搜索框居中（像电量不足的电池）、白圈加红色手柄的放大镜（好看但像任何一个搜索 app）、
// 放大镜中间一个红点（像录像键）。
// 用法：swift tools/make-icon-d.swift 输出目录
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

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(_ c: CGContext) {
    // 底色跟界面深色模式的底色一样
    c.setFillColor(color(0x0A0A0A))
    c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // 搜索框：只有一圈线。左右留得比下面少一点，因为 iOS 裁掉的圆角会吃掉下面两个角的空间
    let bar = CGRect(x: 148, y: 200, width: 728, height: 248)
    c.setStrokeColor(color(0xFFFFFF))
    c.setLineWidth(36)
    c.addPath(roundedRect(bar, radius: 58))
    c.strokePath()

    // 框里的放大镜：线比外框细一档，个头收着一点，给光标让位；缩到很小也不会糊成一团
    c.setLineWidth(28)
    c.setLineCap(.round)
    c.strokeEllipse(in: CGRect(x: 240, y: bar.midY - 32, width: 84, height: 84))
    c.move(to: CGPoint(x: 315, y: bar.midY - 23))
    c.addLine(to: CGPoint(x: 345, y: bar.midY - 53))
    c.strokePath()

    // 红色的输入光标：小红书网页的那个红。它是唯一的颜色，画得粗一点，设置里那么小的图标上也看得见
    c.setFillColor(color(0xFF2442))
    c.addPath(roundedRect(CGRect(x: 420, y: bar.midY - 75, width: 44, height: 150), radius: 8))
    c.fillPath()
}

for size in [1024, 256] {
    try! render(size: size, draw: drawIcon).write(to: URL(fileURLWithPath: "\(out)/icon-\(size).png"))
}
print("wrote \(out)/icon-1024.png and icon-256.png")
