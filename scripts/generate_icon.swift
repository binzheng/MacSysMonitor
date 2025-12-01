#!/usr/bin/swift

import AppKit
import CoreGraphics

// 円形のアイコンを生成
func generateRoundIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext

    // グラデーション背景（青系）
    let colors = [
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0).cgColor
    ]

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors as CFArray,
        locations: [0.0, 1.0]
    )!

    // 円形の背景を描画
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    context.addEllipse(in: rect)
    context.clip()

    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // 波形のアイコンを描画（システムモニターを表現）
    context.resetClip()

    let waveColor = NSColor.white.withAlphaComponent(0.9)
    context.setStrokeColor(waveColor.cgColor)
    context.setLineWidth(size * 0.08)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // 3つの波形を描画
    let padding = size * 0.2
    let waveHeight = size * 0.15
    let waveWidth = size - padding * 2

    for i in 0..<3 {
        let yOffset = padding + (size - padding * 2) / 4 * CGFloat(i + 1)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: padding, y: yOffset))

        // 波形を描画
        let segments = 6
        for j in 0...segments {
            let x = padding + waveWidth * CGFloat(j) / CGFloat(segments)
            let y = yOffset + waveHeight * sin(CGFloat(j) * .pi / 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        context.addPath(path)
        context.strokePath()
    }

    image.unlockFocus()

    return image
}

// PNG画像として保存
func savePNG(image: NSImage, path: String) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Failed to convert to CGImage")
        return
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    } catch {
        print("Failed to save: \(error)")
    }
}

// アイコンセットを生成
let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
let iconsetPath = "AppIcon.iconset"

// iconsetディレクトリを作成
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for size in sizes {
    let image = generateRoundIcon(size: size)

    // 1x
    savePNG(image: image, path: "\(iconsetPath)/icon_\(Int(size))x\(Int(size)).png")

    // 2x（Retinaディスプレイ用）
    if size <= 512 {
        let image2x = generateRoundIcon(size: size * 2)
        savePNG(image: image2x, path: "\(iconsetPath)/icon_\(Int(size))x\(Int(size))@2x.png")
    }
}

print("Icon set generated successfully!")
print("Run: iconutil -c icns AppIcon.iconset -o MacSysMonitor/AppIcon.icns")
