import AppKit
// 用法：swift px.swift 图片 x,y x,y …  → 打印这些点的颜色
let args = CommandLine.arguments
guard args.count > 2, let image = NSImage(contentsOfFile: args[1]), let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { fatalError("usage") }
for p in args.dropFirst(2) {
    let xy = p.split(separator: ",").compactMap { Int($0) }
    guard xy.count == 2, let c = rep.colorAt(x: xy[0], y: xy[1])?.usingColorSpace(.sRGB) else { continue }
    print(p, String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)), Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255))))
}
