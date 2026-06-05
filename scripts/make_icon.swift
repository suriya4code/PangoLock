#!/usr/bin/env swift
// Renders the PangoLock app icon: an armored pangolin curled into a protective
// ball (= "lock"), drawn with Core Graphics. Outputs a 1024×1024 PNG; the build
// script downsamples it into the AppIcon set.
//
// Usage: swift make_icon.swift <output.png>

import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let S = 1024
let size = CGFloat(S)

guard let ctx = CGContext(
    data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("ctx")
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// MARK: Rounded-rect background with a teal→green vertical gradient
let pad = size * 0.06
let rect = CGRect(x: pad, y: pad, width: size - 2*pad, height: size - 2*pad)
let radius = rect.width * 0.225
let bgPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [color(34, 196, 178), color(13, 110, 92)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: 0, y: 0), options: [])
// Soft top sheen
ctx.setFillColor(color(255, 255, 255, 0.06))
ctx.fillEllipse(in: CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height))
ctx.restoreGState()

let center = CGPoint(x: size/2, y: size*0.47)

// MARK: One armored scale (rounded, tapered teardrop) at a position/angle/scale
func drawScale(at p: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat,
               fill: CGColor, edge: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y)
    ctx.rotate(by: angle)
    let path = CGMutablePath()
    // Tip points "outward" (+y before rotation); rounded base.
    path.move(to: CGPoint(x: 0, y: length))
    path.addQuadCurve(to: CGPoint(x: 0, y: -length*0.55),
                      control: CGPoint(x: width, y: length*0.15))
    path.addQuadCurve(to: CGPoint(x: 0, y: length),
                      control: CGPoint(x: -width, y: length*0.15))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(fill); ctx.fillPath()
    ctx.addPath(path)
    ctx.setStrokeColor(edge); ctx.setLineWidth(length*0.07); ctx.strokePath()
    ctx.restoreGState()
}

// Amber/bronze palette for the keratin scales.
func scaleFill(_ t: CGFloat) -> CGColor {        // t: 0 light → 1 dark
    color(238 - 96*t, 182 - 92*t, 110 - 66*t)
}
let scaleEdge = color(110, 64, 26, 0.6)

// Solid amber disc underneath so no teal shows through the armored ball.
let ballR = size * 0.345
ctx.setFillColor(color(150, 100, 52))
ctx.fillEllipse(in: CGRect(x: center.x - ballR, y: center.y - ballR,
                           width: 2*ballR, height: 2*ballR))

// MARK: A dense spiral of overlapping scales — the curled-up pangolin body.
// Drawn outer→inner so each inner scale overlaps the one outside it (roof-tile
// effect), producing a rolled-up armored ball.
let turns: CGFloat = 2.7
let steps = 150
let aStart: CGFloat = .pi * 0.55          // body starts upper-left, curls in
for i in 0..<steps {
    let f = CGFloat(i) / CGFloat(steps - 1)         // 0 outer → 1 inner
    let a = aStart + turns * 2 * .pi * f
    let r = ballR * (0.97 - 0.95*f)
    let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
    let len = size * (0.090 - 0.060*f)
    drawScale(at: p, angle: a - .pi/2, length: len, width: len*0.82,
              fill: scaleFill(0.12 + 0.7*f), edge: scaleEdge)
}

// MARK: Tucked head — a small rounded snout where the body's outer end sits.
let headA = aStart - 0.10
let headP = CGPoint(x: center.x + cos(headA) * ballR * 0.84,
                    y: center.y + sin(headA) * ballR * 0.84)
ctx.setFillColor(color(150, 96, 48))
ctx.saveGState()
ctx.translateBy(x: headP.x, y: headP.y); ctx.rotate(by: headA)
ctx.fillEllipse(in: CGRect(x: -size*0.06, y: -size*0.045, width: size*0.14, height: size*0.09))
ctx.setFillColor(color(40, 24, 12))      // eye
ctx.fillEllipse(in: CGRect(x: size*0.015, y: size*0.006, width: size*0.018, height: size*0.018))
ctx.restoreGState()

// MARK: Write PNG
guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(S)×\(S))")
