import AppKit
// 把几张截图拼成一张总览。用法：swift tools/contact-sheet.swift 输出.png 每行几张 图1.png 图2.png …
// 每张缩到同样的宽度，底下写文件名
let args = CommandLine.arguments
guard args.count > 3, let columns = Int(args[2]), columns > 0 else { fatalError("usage: contact-sheet.swift out.png columns images…") }
let paths = Array(args.dropFirst(3))
let images = paths.compactMap { path -> (String, NSImage)? in
    guard let image = NSImage(contentsOfFile: path), let rep = image.representations.first else { return nil }
    image.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh) // 按像素算，不按点
    return ((path as NSString).lastPathComponent.replacingOccurrences(of: ".png", with: ""), image)
}
guard !images.isEmpty else { fatalError("no images") }
let cellWidth: CGFloat = 390, gap: CGFloat = 24, labelHeight: CGFloat = 34
let cellHeight = images.map { cellWidth * $0.1.size.height / $0.1.size.width }.max()!
let rows = Int(ceil(Double(images.count) / Double(columns)))
let width = gap + CGFloat(columns) * (cellWidth + gap)
let height = gap + CGFloat(rows) * (cellHeight + labelHeight + gap)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.5, alpha: 1).setFill() // 中灰底：白底、黑底、米色底的界面都分得清边界
NSRect(x: 0, y: 0, width: width, height: height).fill()
let labelAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: NSColor.white]
for (index, (name, image)) in images.enumerated() {
    let column = index % columns, row = index / columns
    let x = gap + CGFloat(column) * (cellWidth + gap)
    let top = height - gap - CGFloat(row) * (cellHeight + labelHeight + gap) // AppKit 的 y 从下往上
    let h = cellWidth * image.size.height / image.size.width
    image.draw(in: NSRect(x: x, y: top - h, width: cellWidth, height: h), from: .zero, operation: .sourceOver, fraction: 1)
    (name as NSString).draw(at: NSPoint(x: x, y: top - cellHeight - labelHeight + 6), withAttributes: labelAttributes)
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
print("wrote \(args[1]) \(Int(width))x\(Int(height))")
