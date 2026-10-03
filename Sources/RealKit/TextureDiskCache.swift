import Foundation
import Metal
import CryptoKit
import RealMaterials

/// On-disk cache of synthesized material textures (all mips, raw texels), keyed by a hash of the
/// spec, the pixel size and the Metal source. A hit replaces GPU synthesis with a file read and a
/// blit. Default location: ~/Library/Caches/RealForge/textures. Opt out with `isEnabled = false` or
/// the environment variable REALFORGE_NO_DISK_CACHE=1.
public enum RealTextureDiskCache {
    nonisolated(unsafe) public static var isEnabled = ProcessInfo.processInfo.environment["REALFORGE_NO_DISK_CACHE"] == nil
    nonisolated(unsafe) public static var directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RealForge/textures", isDirectory: true)
    /// Bump when the file layout changes.
    static let formatVersion = 1
    static let writer = DispatchQueue(label: "realforge.texture-disk-cache", qos: .utility)

    /// Texture order and bytes per texel inside a cache file.
    struct Layout {
        var n: Int
        var formats: [Int]   // bytes per texel per texture: albedo 4, normal 2, roughness 1, ao 1, metallic 1
        var levels: Int { TextureSynth.mipCount(n) }
        func levelBytes(_ bpp: Int, _ l: Int) -> Int { let w = max(1, n >> l); return w * w * bpp }
        var totalBytes: Int { formats.reduce(0) { acc, b in acc + (0..<levels).reduce(0) { $0 + levelBytes(b, $1) } } }
    }

    static func layout(_ s: MaterialSpec, n: Int) -> Layout {
        Layout(n: n, formats: [4, 2, 1] + (s.hasAOMap ? [1] : []) + (s.hasMetallicMap ? [1] : []))
    }

    static func key(_ s: MaterialSpec, n: Int) -> String {
        var c = s
        c.key = ""   // the key names the material; texels depend on the rest
        let text = "v\(formatVersion)|\(n)|\(TextureSynth.flipGreen)|\(TextureSynth.sourceFingerprint)|\(c)"
        return SHA256.hash(data: Data(text.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    static func url(_ key: String) -> URL { directory.appendingPathComponent(key + ".rftex") }

    static func load(_ s: MaterialSpec, n: Int) -> Data? {
        guard isEnabled else { return nil }
        guard let d = try? Data(contentsOf: url(key(s, n: n)), options: .alwaysMapped), d.count == layout(s, n: n).totalBytes else { return nil }
        return d
    }

    /// Encodes copies of every mip of `textures` into a shared buffer on `cb`; the file is written
    /// on a utility queue once the GPU finishes.
    static func encodeStore(_ s: MaterialSpec, n: Int, textures: [MTLTexture], device: MTLDevice, commandBuffer cb: MTLCommandBuffer) {
        guard isEnabled else { return }
        let lay = layout(s, n: n)
        guard textures.count == lay.formats.count, let buf = device.makeBuffer(length: lay.totalBytes, options: .storageModeShared),
              let blit = cb.makeBlitCommandEncoder() else { return }
        var off = 0
        for (t, bpp) in zip(textures, lay.formats) {
            for l in 0..<lay.levels {
                let w = max(1, n >> l)
                blit.copy(from: t, sourceSlice: 0, sourceLevel: l, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: w, height: w, depth: 1),
                          to: buf, destinationOffset: off, destinationBytesPerRow: w * bpp, destinationBytesPerImage: w * w * bpp)
                off += w * w * bpp
            }
        }
        blit.endEncoding()
        let target = url(key(s, n: n))
        cb.addCompletedHandler { _ in
            writer.async {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = Data(bytes: buf.contents(), count: buf.length)
                try? data.write(to: target, options: .atomic)
            }
        }
    }

    /// Encodes uploads of a cache file into `textures` (same order and sizes as when stored).
    static func encodeLoad(_ data: Data, _ s: MaterialSpec, n: Int, into textures: [MTLTexture], device: MTLDevice, commandBuffer cb: MTLCommandBuffer) -> Bool {
        let lay = layout(s, n: n)
        guard textures.count == lay.formats.count,
              let buf = data.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: data.count, options: .storageModeShared) }),
              let blit = cb.makeBlitCommandEncoder() else { return false }
        var off = 0
        for (t, bpp) in zip(textures, lay.formats) {
            for l in 0..<lay.levels {
                let w = max(1, n >> l)
                blit.copy(from: buf, sourceOffset: off, sourceBytesPerRow: w * bpp, sourceBytesPerImage: w * w * bpp, sourceSize: MTLSize(width: w, height: w, depth: 1),
                          to: t, destinationSlice: 0, destinationLevel: l, destinationOrigin: MTLOrigin())
                off += w * w * bpp
            }
        }
        blit.endEncoding()
        return true
    }

    /// Waits for pending cache writes (CLI commands that exit right after rendering).
    public static func flush() { writer.sync {} }

    /// Deletes every cached texture file.
    public static func clear() { try? FileManager.default.removeItem(at: directory) }

    /// Bytes currently on disk.
    public static var bytesOnDisk: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}
