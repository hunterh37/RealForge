import Foundation
import CoreGraphics
import CoreText
import ImageIO
import Vision
import CoreVideo

/// RGBA8 pixel buffer for compositing and metrics.
struct Pixels {
    var w: Int, h: Int
    var data: [UInt8]

    init(w: Int, h: Int, fill: (UInt8, UInt8, UInt8) = (0, 0, 0)) {
        self.w = w; self.h = h
        data = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) { data[i * 4] = fill.0; data[i * 4 + 1] = fill.1; data[i * 4 + 2] = fill.2 }
    }

    init(_ img: CGImage, width: Int? = nil, height: Int? = nil) {
        w = width ?? img.width; h = height ?? img.height
        data = [UInt8](repeating: 0, count: w * h * 4)
        let ww = w, hh = h
        data.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: ww, height: hh, bitsPerComponent: 8, bytesPerRow: ww * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.interpolationQuality = .high
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: ww, height: hh))
        }
    }

    static func load(_ path: String) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldAllowFloat: false] as CFDictionary) else {
            throw CLIError("cannot read image \(path)")
        }
        return img
    }

    func rgb(_ x: Int, _ y: Int) -> SIMD3<Float> {
        let i = (y * w + x) * 4
        return SIMD3(Float(data[i]), Float(data[i + 1]), Float(data[i + 2])) / 255
    }
    mutating func set(_ x: Int, _ y: Int, _ c: SIMD3<Float>) {
        let i = (y * w + x) * 4
        data[i] = UInt8(max(0, min(255, c.x * 255))); data[i + 1] = UInt8(max(0, min(255, c.y * 255))); data[i + 2] = UInt8(max(0, min(255, c.z * 255))); data[i + 3] = 255
    }

    var cgImage: CGImage {
        let prov = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: prov, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)!
    }
}

/// Drawing surface (top-left origin in the API; CoreGraphics flips internally).
final class Canvas {
    let ctx: CGContext
    let w: Int, h: Int
    init(_ w: Int, _ h: Int, bg: CGColor = CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)) {
        self.w = w; self.h = h
        ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(bg); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
    }
    func image(_ img: CGImage, x: Int, y: Int, w iw: Int, h ih: Int) {
        ctx.draw(img, in: CGRect(x: x, y: h - y - ih, width: iw, height: ih))
    }
    func rect(x: Int, y: Int, w rw: Int, h rh: Int, _ c: CGColor) {
        ctx.setFillColor(c); ctx.fill(CGRect(x: x, y: h - y - rh, width: rw, height: rh))
    }
    /// Text with its top-left at (x, y); returns the drawn width.
    @discardableResult
    func text(_ s: String, x: Int, y: Int, size: CGFloat = 16, color: CGColor = CGColor(gray: 1, alpha: 0.95), bold: Bool = false, pill: Bool = false) -> Int {
        let font = CTFontCreateWithName((bold ? "Menlo-Bold" : "Menlo-Regular") as CFString, size, nil)
        let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                             NSAttributedString.Key(kCTForegroundColorAttributeName as String): color])
        let line = CTLineCreateWithAttributedString(attr)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        if pill { rect(x: x - 6, y: y - 4, w: Int(width) + 12, h: Int(size * 1.35) + 8, CGColor(gray: 0, alpha: 0.6)) }
        ctx.textPosition = CGPoint(x: CGFloat(x), y: CGFloat(h - y) - size)
        CTLineDraw(line, ctx)
        return Int(width)
    }
    var cgImage: CGImage { ctx.makeImage()! }
}

// MARK: - masks and metrics

/// Foreground mask (0...1) of a render on a flat matte background, from the corner color.
func matteMask(_ p: Pixels) -> [Float] {
    let corners = [p.rgb(1, 1), p.rgb(p.w - 2, 1), p.rgb(1, p.h - 2), p.rgb(p.w - 2, p.h - 2)]
    let bg = corners.reduce(SIMD3<Float>.zero, +) / 4
    var m = [Float](repeating: 0, count: p.w * p.h)
    for y in 0..<p.h { for x in 0..<p.w {
        let d = simd_length(p.rgb(x, y) - bg)
        m[y * p.w + x] = max(0, min(1, (d - 0.06) / 0.1))
    }}
    return m
}

/// Foreground mask of a photo: Vision subject lifting, falling back to border-color keying (studio shots).
func subjectMask(_ img: CGImage, _ p: Pixels) -> [Float] {
    let req = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: img)
    if (try? handler.perform([req])) != nil, let obs = req.results?.first,
       let buf = try? obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler) {
        CVPixelBufferLockBaseAddress(buf, .readOnly); defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
        let bw = CVPixelBufferGetWidth(buf), bh = CVPixelBufferGetHeight(buf), row = CVPixelBufferGetBytesPerRow(buf)
        if let base = CVPixelBufferGetBaseAddress(buf), CVPixelBufferGetPixelFormatType(buf) == kCVPixelFormatType_OneComponent32Float {
            var m = [Float](repeating: 0, count: p.w * p.h)
            for y in 0..<p.h { for x in 0..<p.w {
                let sx = min(bw - 1, x * bw / p.w), sy = min(bh - 1, y * bh / p.h)
                m[y * p.w + x] = base.advanced(by: sy * row + sx * 4).assumingMemoryBound(to: Float.self).pointee
            }}
            return m
        }
    }
    // Border keying: median border color, distance threshold.
    var border: [SIMD3<Float>] = []
    for x in stride(from: 0, to: p.w, by: 4) { border.append(p.rgb(x, 0)); border.append(p.rgb(x, p.h - 1)) }
    for y in stride(from: 0, to: p.h, by: 4) { border.append(p.rgb(0, y)); border.append(p.rgb(p.w - 1, y)) }
    let bg = border.reduce(SIMD3<Float>.zero, +) / Float(border.count)
    var m = [Float](repeating: 0, count: p.w * p.h)
    for y in 0..<p.h { for x in 0..<p.w { m[y * p.w + x] = max(0, min(1, (simd_length(p.rgb(x, y) - bg) - 0.08) / 0.12)) } }
    return m
}

struct BBox { var x0: Int, y0: Int, x1: Int, y1: Int
    var w: Int { x1 - x0 + 1 }; var h: Int { y1 - y0 + 1 }
}

func bbox(_ m: [Float], _ w: Int, _ h: Int) -> BBox? {
    var b = BBox(x0: w, y0: h, x1: -1, y1: -1)
    for y in 0..<h { for x in 0..<w where m[y * w + x] > 0.5 {
        b.x0 = min(b.x0, x); b.x1 = max(b.x1, x); b.y0 = min(b.y0, y); b.y1 = max(b.y1, y)
    }}
    return b.x1 < 0 ? nil : b
}

/// Square crop around the mask bbox (padding 6 percent), resampled to n x n. Background replaced by grey
/// when `matte` is true. Returns pixels and the mask in the same frame.
func normalizedCrop(_ p: Pixels, _ m: [Float], n: Int, matte: Bool) -> (Pixels, [Float])? {
    guard let b = bbox(m, p.w, p.h) else { return nil }
    let side = Float(max(b.w, b.h)) * 1.12
    let cx = Float(b.x0 + b.x1) / 2, cy = Float(b.y0 + b.y1) / 2
    var out = Pixels(w: n, h: n, fill: (128, 128, 128))
    var mm = [Float](repeating: 0, count: n * n)
    for y in 0..<n { for x in 0..<n {
        let sx = Int(cx + (Float(x) / Float(n) - 0.5) * side), sy = Int(cy + (Float(y) / Float(n) - 0.5) * side)
        guard sx >= 0, sy >= 0, sx < p.w, sy < p.h else { continue }
        let a = m[sy * p.w + sx]
        mm[y * n + x] = a
        let c = p.rgb(sx, sy)
        out.set(x, y, matte ? (a > 0.85 ? c : SIMD3(repeating: 0.5)) : c)
    }}
    return (out, mm)
}

func iou(_ a: [Float], _ b: [Float]) -> Float {
    var i: Float = 0, u: Float = 0
    for k in a.indices { let x = a[k] > 0.5, y = b[k] > 0.5; if x && y { i += 1 }; if x || y { u += 1 } }
    return u > 0 ? i / u : 0
}

func lab(_ c: SIMD3<Float>) -> SIMD3<Float> {
    func lin(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    let r = lin(c.x), g = lin(c.y), b = lin(c.z)
    let X = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.9505, Y = 0.2126 * r + 0.7152 * g + 0.0722 * b, Z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.089
    func f(_ t: Float) -> Float { t > 0.008856 ? pow(t, 1.0 / 3) : 7.787 * t + 16.0 / 116 }
    return SIMD3(116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z)))
}

/// Mean Lab color inside a mask.
func meanLab(_ p: Pixels, _ m: [Float]) -> SIMD3<Float> {
    var s = SIMD3<Float>.zero, n: Float = 0
    for y in 0..<p.h { for x in 0..<p.w { let a = m[y * p.w + x]; if a > 0.5 { s += lab(p.rgb(x, y)); n += 1 } } }
    return n > 0 ? s / n : .zero
}

/// Mean absolute Laplacian of luminance inside a mask (surface detail energy).
func detailEnergy(_ p: Pixels, _ m: [Float]) -> Float {
    func l(_ x: Int, _ y: Int) -> Float { let c = p.rgb(x, y); return 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z }
    var s: Float = 0, n: Float = 0
    for y in 1..<(p.h - 1) { for x in 1..<(p.w - 1) where m[y * p.w + x] > 0.9 && m[(y - 1) * p.w + x] > 0.9 && m[(y + 1) * p.w + x] > 0.9 {
        s += abs(4 * l(x, y) - l(x - 1, y) - l(x + 1, y) - l(x, y - 1) - l(x, y + 1)); n += 1
    }}
    return n > 0 ? s / n : 0
}

/// Vision feature-print distance between two images (0 = identical; ~1+ unrelated).
func featureDistance(_ a: CGImage, _ b: CGImage) -> Float? {
    func fp(_ img: CGImage) -> VNFeaturePrintObservation? {
        let r = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cgImage: img).perform([r])
        return r.results?.first
    }
    guard let x = fp(a), let y = fp(b) else { return nil }
    var d: Float = 0
    do { try x.computeDistance(&d, to: y) } catch { return nil }
    return d
}

/// Overlay of two masks: white both, red reference only, cyan render only.
func overlay(_ ref: [Float], _ ren: [Float], n: Int) -> Pixels {
    var p = Pixels(w: n, h: n, fill: (24, 24, 26))
    for y in 0..<n { for x in 0..<n {
        let a = ref[y * n + x] > 0.5, b = ren[y * n + x] > 0.5
        if a && b { p.set(x, y, SIMD3(0.92, 0.92, 0.92)) } else if a { p.set(x, y, SIMD3(0.95, 0.25, 0.2)) } else if b { p.set(x, y, SIMD3(0.2, 0.85, 0.95)) }
    }}
    return p
}
