#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "./Bindu.png"

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Black background
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let center = CGPoint(x: size/2, y: size/2)
let binduRed = CGColor(red: 0.898, green: 0.322, blue: 0.306, alpha: 1)

// Outer glow rings (soft)
for ring in (0..<8).reversed() {
    let r: CGFloat = CGFloat(100 + ring * 40)
    let alpha: CGFloat = 0.22 - CGFloat(ring) * 0.025
    ctx.setFillColor(CGColor(red: 0.898, green: 0.322, blue: 0.306, alpha: max(0, alpha)))
    ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2))
}

// Core Bindu
let coreR: CGFloat = 100
ctx.setFillColor(binduRed)
ctx.fillEllipse(in: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR*2, height: coreR*2))

// Bright highlight at very center
let highlightR: CGFloat = 36
ctx.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.82, alpha: 0.65))
ctx.fillEllipse(in: CGRect(x: center.x - highlightR, y: center.y - highlightR, width: highlightR*2, height: highlightR*2))

guard let image = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("Wrote: \(outputPath)")
