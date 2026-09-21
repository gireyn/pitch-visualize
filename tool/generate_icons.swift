// Reproducible vector app icon. Run: swift tool/generate_icons.swift
import AppKit
import Foundation

func renderIcon(size: Int, path: String) throws {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setFillColor(NSColor(red: 16/255, green: 20/255, blue: 25/255, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.setStrokeColor(NSColor(red: 53/255, green: 64/255, blue: 77/255, alpha: 1).cgColor)
    context.setLineWidth(8)
    for y in stride(from: 256, through: 768, by: 128) {
        context.move(to: CGPoint(x: 160, y: y)); context.addLine(to: CGPoint(x: 864, y: y)); context.strokePath()
    }
    context.setStrokeColor(NSColor(red: 141/255, green: 224/255, blue: 203/255, alpha: 1).cgColor)
    context.setLineWidth(48); context.setLineCap(.round); context.setLineJoin(.round)
    let points: [CGPoint] = [.init(x: 160, y: 384), .init(x: 272, y: 384), .init(x: 352, y: 640),
        .init(x: 432, y: 320), .init(x: 528, y: 704), .init(x: 608, y: 512), .init(x: 784, y: 512)]
    context.addLines(between: points); context.strokePath()
    context.setFillColor(NSColor(red: 255/255, green: 215/255, blue: 94/255, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: 764, y: 460, width: 104, height: 104))
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
for (density, size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
    try renderIcon(size: size, path: "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
let iconPath = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "\(iconPath)/Contents.json"))) as! [String: Any]
for icon in manifest["images"] as! [[String: Any]] {
    guard let filename = icon["filename"] as? String,
          let size = icon["size"] as? String, let scale = icon["scale"] as? String else { continue }
    let points = Double(size.split(separator: "x")[0])!
    let factor = Double(scale.replacingOccurrences(of: "x", with: ""))!
    try renderIcon(size: Int(points * factor), path: "\(iconPath)/\(filename)")
}
