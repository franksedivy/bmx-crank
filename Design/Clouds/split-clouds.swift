// Splits the three clouds from the existing 400x240 far.png without resampling.
// Usage: swift split-clouds.swift <far.png> <output-directory>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 400, image.height == 240 else {
    fatalError("Expected the original 400x240 cloud layer")
}

var pixels = [UInt8](repeating: 0, count: 400 * 240 * 4)
pixels.withUnsafeMutableBytes { buffer in
    let context = CGContext(
        data: buffer.baseAddress, width: 400, height: 240,
        bitsPerComponent: 8, bytesPerRow: 400 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: 400, height: 240))
}

// These regions isolate the original left, upper-middle and right clouds.
// They partition the canvas, so every opaque pixel belongs to one export.
let regions = [
    ("cloud-a", 0, 0, 160, 240),
    ("cloud-b", 160, 0, 400, 100),
    ("cloud-c", 160, 100, 400, 240),
]
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for (name, startX, startY, endX, endY) in regions {
    var minX = endX
    var minY = endY
    var maxX = -1
    var maxY = -1
    for y in startY..<endY {
        for x in startX..<endX where pixels[(y * 400 + x) * 4 + 3] > 0 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { fatalError("No pixels found for \(name)") }
    let bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    let crop = image.cropping(to: bounds)!
    let outputURL = outputDirectory.appendingPathComponent(name + ".png")
    guard !FileManager.default.fileExists(atPath: outputURL.path) else {
        fatalError("Refusing to overwrite \(outputURL.path)")
    }
    let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, crop, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot export \(name)") }
    print("\(name): \(crop.width)x\(crop.height), original bounds \(bounds)")
}
