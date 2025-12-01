#!/usr/bin/swift

import AppKit
import CoreGraphics

// 画像を読み込み
func loadImage(path: String) -> NSImage? {
    return NSImage(contentsOfFile: path)
}

// 角丸の正方形にクロップして生成
func generateRoundedRectIcon(sourceImage: NSImage, size: CGFloat, cornerRadius: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext

    // 角丸の矩形パスを作成
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    // パスをクリップ
    context.addPath(path)
    context.clip()

    // 元の画像を正方形にクロップして描画
    let sourceSize = sourceImage.size
    let minDimension = min(sourceSize.width, sourceSize.height)
    let sourceRect = NSRect(
        x: (sourceSize.width - minDimension) / 2,
        y: (sourceSize.height - minDimension) / 2,
        width: minDimension,
        height: minDimension
    )

    sourceImage.draw(
        in: rect,
        from: sourceRect,
        operation: .copy,
        fraction: 1.0
    )

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

// 元の画像を読み込み
guard let sourceImage = loadImage(path: "image/icon.png") else {
    print("Failed to load source image")
    exit(1)
}

// アイコンセットを生成
let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
let iconsetPath = "AppIcon.iconset"

// iconsetディレクトリを作成
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for size in sizes {
    // 角丸の半径（macOSアイコンの標準的な角丸：サイズの約18-22%）
    let cornerRadius = size * 0.2

    let image = generateRoundedRectIcon(
        sourceImage: sourceImage,
        size: size,
        cornerRadius: cornerRadius
    )

    // 1x
    savePNG(image: image, path: "\(iconsetPath)/icon_\(Int(size))x\(Int(size)).png")

    // 2x（Retinaディスプレイ用）
    if size <= 512 {
        let image2x = generateRoundedRectIcon(
            sourceImage: sourceImage,
            size: size * 2,
            cornerRadius: cornerRadius * 2
        )
        savePNG(image: image2x, path: "\(iconsetPath)/icon_\(Int(size))x\(Int(size))@2x.png")
    }
}

print("Icon set generated successfully!")
print("Run: iconutil -c icns AppIcon.iconset -o MacSysMonitor/AppIcon.icns")
