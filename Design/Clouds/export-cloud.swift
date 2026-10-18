// Trim one generated cloud and export crisp black/white pixels with transparency.
// Usage: swift export-cloud.swift <source.png> <output.png>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Cannot read cloud")
}
let sourceWidth = image.width
let sourceHeight = image.height
var sourcePixels = [UInt8](repeating: 0, count: sourceWidth * sourceHeight * 4)
sourcePixels.withUnsafeMutableBytes { buffer in
    let context = CGContext(
        data: buffer.baseAddress, width: sourceWidth, height: sourceHeight,
        bitsPerComponent: 8, bytesPerRow: sourceWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
}
var minX = sourceWidth, minY = sourceHeight, maxX = -1, maxY = -1
for y in 0..<sourceHeight {
    for x in 0..<sourceWidth where sourcePixels[(y * sourceWidth + x) * 4 + 3] >= 128 {
        minX = min(minX, x); minY = min(minY, y)
        maxX = max(maxX, x); maxY = max(maxY, y)
    }
}
guard maxX >= minX, maxY >= minY else { fatalError("Cloud is empty") }
let crop = image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!
let scale = min(106.0 / Double(crop.width), 36.0 / Double(crop.height))
let contentWidth = max(1, Int((Double(crop.width) * scale).rounded()))
let contentHeight = max(1, Int((Double(crop.height) * scale).rounded()))
let width = contentWidth + 4, height = contentHeight + 4
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let result: CGImage = pixels.withUnsafeMutableBytes { buffer in
    let context = CGContext(
        data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.draw(crop, in: CGRect(x: 2, y: 2, width: contentWidth, height: contentHeight))
    let bytes = buffer.bindMemory(to: UInt8.self)
    for index in stride(from: 0, to: bytes.count, by: 4) {
        let alpha = Int(bytes[index + 3])
        if alpha < 128 {
            for channel in 0...3 { bytes[index + channel] = 0 }
        } else {
            let luminance = (299 * Int(bytes[index]) + 587 * Int(bytes[index + 1]) + 114 * Int(bytes[index + 2])) / 1000
            let value: UInt8 = luminance * 255 >= 128 * alpha ? 255 : 0
            bytes[index] = value; bytes[index + 1] = value; bytes[index + 2] = value
            bytes[index + 3] = 255
        }
    }
    return context.makeImage()!
}
guard !FileManager.default.fileExists(atPath: outputURL.path) else {
    fatalError("Refusing to overwrite \(outputURL.path)")
}
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, result, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save cloud") }
print("\(outputURL.lastPathComponent): \(width)x\(height)")
