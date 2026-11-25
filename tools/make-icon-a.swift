import AppKit
// 「原味」这一套的桌面图标：白底上一个粗粗的红色放大镜，镜片不是圆的，是小红书图标那种圆角方块——
// 意思是「只在小红书里搜」；这个红色圆角方块和 app 底栏中间那个红色「＋」也是一家。
// 跟界面一个路子：白底、只有小红书那一种红（#FF2442）、平的、没有渐变和阴影；
// 官方小红书图标是红底白字的实心方块，这个反过来是白底上一个红色的空心方块加手柄，放在同一屏上一眼分得开。
// 试过又放下的方案：普通的圆镜片放大镜（干净，但跟随便哪个搜索图标都一样）、实心红镜片（像个乒乓球拍）、
// 灰色搜索框加红光标（缩小以后糊成一条）、红色小书上镂空放大镜（一大块红，跟官方图标太像）、
// 一个「搜」字（官方图标也是字，容易当成一家的）、镜片里加一个红点或一条短线（像靶子、像「缩小」）。
// 用法：swift tools/make-icon-a.swift 输出目录
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

func drawIcon(_ c: CGContext) {
    c.setFillColor(color(0xFFFFFF))
    c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // 放大镜：一个圆角方框加一截圆头的手柄，线宽一样。线粗，缩到设置里那么小也认得出
    let stroke: CGFloat = 104      // 线宽
    let half: CGFloat = 182        // 方框的半边长（到线的中心）
    let corner: CGFloat = 122      // 方框的圆角（线的中心）：够圆，一眼还是放大镜；又没圆到变成圆形
    let handle: CGFloat = 142      // 手柄末端比方框的右下角再往外伸多远
    let diagonal = CGFloat(0.5).squareRoot() // 手柄朝右下 45°
    // 整个图形（方框 + 手柄）的外框居中，再往右下挪 26：方框比手柄重，按外框居中会显得偏左上、右上和左下各空一块。
    // 挪完手柄尖到 843，还在中间 80% 以内
    let extent = 2 * half + stroke + handle
    let centerX = 512 - extent / 2 + half + stroke / 2 + 26
    let centerY = 1024 - centerX

    c.setStrokeColor(color(0xFF2442))
    c.setLineWidth(stroke)
    c.setLineCap(.round)
    c.addPath(CGPath(roundedRect: CGRect(x: centerX - half, y: centerY - half, width: 2 * half, height: 2 * half),
                     cornerWidth: corner, cornerHeight: corner, transform: nil))
    c.strokePath()
    // 手柄从右下那个圆角的外沿附近起笔：从线的中心起笔的话，圆头会在镜片里面鼓出一个小包
    let cornerCenter = CGPoint(x: centerX + half - corner, y: centerY - half + corner)
    let start = corner + stroke * 0.35
    c.move(to: CGPoint(x: cornerCenter.x + start * diagonal, y: cornerCenter.y - start * diagonal))
    c.addLine(to: CGPoint(x: centerX + half + handle, y: centerY - half - handle))
    c.strokePath()
}

for size in [1024, 256] {
    try! render(size: size, draw: drawIcon).write(to: URL(fileURLWithPath: "\(out)/icon-\(size).png"))
}
print("wrote \(out)/icon-1024.png and icon-256.png")
