// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import CoreGraphics

struct NativeCoreError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum NativeRustCore {
    static func call(_ method: String, _ arguments: [String: Any] = [:], window: String = "") throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: ["method": method, "args": arguments, "window": window])
        guard let request = String(data: data, encoding: .utf8) else { throw NativeCoreError(message: "无法编码请求") }
        guard let pointer = request.withCString({ rd_ios_request($0) }) else { throw NativeCoreError(message: "连接引擎未响应") }
        defer { rd_ios_free_string(pointer) }
        let response = Data(String(cString: pointer).utf8)
        let value = try JSONSerialization.jsonObject(with: response, options: .fragmentsAllowed)
        let result = value as? [String: Any] ?? [:]
        if let error = result["error"] as? String { throw NativeCoreError(message: error) }
        return result
    }

    private static let resolutionQueue = DispatchQueue(label: "me.airefactor.swiftrust.resolution")
    static func changeResolution(session: String, display: Int, resolution: NativeResolution, window: String = "") async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            resolutionQueue.async {
                do {
                    _ = try call("resolution", ["session": session, "display": display, "width": resolution.width, "height": resolution.height], window: window)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func frame(window: String = "") -> (CGImage, Int)? {
        var frame = RDNativeFrame()
        let available = window.withCString { rd_ios_take_window_frame($0, &frame) }
        guard available, let pixels = frame.data else { return nil }
        guard frame.width > 0, frame.height > 0, frame.width <= Int.max / 4,
              frame.length / frame.height >= frame.width * 4,
              let provider = CGDataProvider(dataInfo: nil, data: pixels, size: frame.length,
                releaseData: { _, bytes, length in
                    rd_ios_free_bytes(UnsafeMutablePointer(mutating: bytes.assumingMemoryBound(to: UInt8.self)), length)
                }) else {
            rd_ios_free_bytes(pixels, frame.length)
            return nil
        }
        guard let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: frame.length / frame.height,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return (image, frame.display)
    }

    static func cursor(_ shape: [String: Any]) -> NativeCursor? {
        guard let width = shape["width"] as? Int, let height = shape["height"] as? Int,
              width > 0, height > 0, width <= 1024, height <= 1024,
              let encoded = shape["colors"] as? String,
              let data = Data(base64Encoded: encoded), data.count == width * height * 4,
              let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                  decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return NativeCursor(image: image, hotspot: CGPoint(x: shape["hotx"] as? Int ?? 0, y: shape["hoty"] as? Int ?? 0))
    }
}

struct NativeCursor {
    let image: CGImage
    let hotspot: CGPoint
}

struct NativeResolution: Hashable, Identifiable {
    let width: Int
    let height: Int
    var id: String { "\(width)x\(height)" }
    var title: String { "\(width) × \(height)" }
    static func decode(_ encoded: String) -> [NativeResolution] {
        guard let data = encoded.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let rows = value as? [[String: Any]] ?? (value as? [String: Any])?["resolutions"] as? [[String: Any]] ?? []
        return Array(Set(rows.compactMap { row -> NativeResolution? in
            guard let width = row["width"] as? Int, let height = row["height"] as? Int,
                  (64...8192).contains(width), (64...8192).contains(height) else { return nil }
            return NativeResolution(width: width, height: height)
        })).sorted { $0.width == $1.width ? $0.height > $1.height : $0.width > $1.width }
    }
    static func windowPixels(_ size: CGSize) -> NativeResolution? {
        guard size.width.isFinite, size.height.isFinite,
              (64...8192).contains(size.width.rounded()), (64...8192).contains(size.height.rounded()) else { return nil }
        return NativeResolution(width: Int(size.width.rounded()), height: Int(size.height.rounded()))
    }
}

struct NativeDisplay: Identifiable {
    static func cursorEmbedded(_ value: Any?, fallback: Bool = false) -> Bool {
        if let value = value as? String {
            switch value.lowercased() { case "1", "true": return true; case "0", "false": return false; default: return fallback }
        }
        if let value = value as? NSNumber {
            switch value.intValue { case 1: return true; case 0: return false; default: return fallback }
        }
        return fallback
    }
    let id: Int
    let origin: CGPoint
    let size: CGSize
    let embeddedCursor: Bool
    var originalResolution: NativeResolution?
    var customResolution = false
    var scale: CGFloat = 1
    var currentResolution: NativeResolution? {
        guard scale.isFinite, scale > 0 else { return nil }
        return NativeResolution.windowPixels(CGSize(width: size.width / scale, height: size.height / scale))
    }
}

struct NativeConnectionMessage: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let text: String
    var hasRetry = false
    var sourceTitle = ""
    var connectionError: Bool { !password && !twoFactor && !insecure && (hasRetry || sourceTitle == "Connection Error") }
    var password: Bool { type.contains("password") || type.contains("login") }
    var twoFactor: Bool { type.contains("2fa") }
    var insecure: Bool { type.contains("insecure-connection") }
}

struct NativeCoreChannel {
    let window: String
    init(window: String = "") { self.window = window }
    func call(_ method: String, _ arguments: [String: Any] = [:]) throws -> [String: Any] {
        try NativeRustCore.call(method, arguments, window: window)
    }
    func frame() -> (CGImage, Int)? { NativeRustCore.frame(window: window) }
    func changeResolution(session: String, display: Int, resolution: NativeResolution) async throws {
        try await NativeRustCore.changeResolution(session: session, display: display, resolution: resolution, window: window)
    }
}
