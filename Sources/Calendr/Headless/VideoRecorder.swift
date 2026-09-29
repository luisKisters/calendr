import AppKit
import AVFoundation
import CoreVideo

/// H.264 mp4 writer. Frames are supplied as CGImages; `hold` repeats the same frame so idle time costs nothing.
@MainActor
final class VideoRecorder {
    let width: Int, height: Int, fps: Int32
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private(set) var frameCount = 0

    init?(url: URL, width: Int = 1440, height: Int = 900, fps: Int32 = 30) {
        self.width = width; self.height = height; self.fps = fps
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)
        guard let w = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        writer = w
        w.shouldOptimizeForNetworkUse = true          // moov atom first: plays while downloading in browsers and chat viewers
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2, AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2, AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 60, AVVideoExpectedSourceFrameRateKey: 30],
        ])
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
    }

    var seconds: Double { Double(frameCount) / Double(fps) }

    func append(_ image: CGImage, hold frames: Int = 1) {
        guard frames > 0, let pool = adaptor.pixelBufferPool else { return }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let buf = pb else { return }
        CVPixelBufferLockBaseAddress(buf, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: width, height: height, bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buf, [])
        for _ in 0..<frames {
            while !input.isReadyForMoreMediaData { RunLoop.current.run(until: Date().addingTimeInterval(0.005)) }
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(frameCount), timescale: fps))
            frameCount += 1
        }
    }

    func finish() {
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        while sem.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    }
}

/// Draws the caption pill, key badge, mouse cursor and (for the menu bar tour) a faux menu bar into a frame.
/// All of this is video-only decoration; the app UI is untouched.
enum FrameComposer {
    struct Overlay {
        var caption: String?
        var keys: String?
        var cursor: CGPoint?          // window points, top-left origin
        var pressed = false
        var popover: CGImage?         // menu bar popover rendered offscreen
        var menuBarLabel: String?
        var dim = false
    }

    @MainActor
    static func compose(window: CGImage, size: CGSize, overlay o: Overlay) -> CGImage? {
        let w = Int(size.width), h = Int(size.height)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(window, in: CGRect(x: 0, y: 0, width: w, height: h))
        let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc

        if let pop = o.popover {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
            // faux menu bar
            ctx.setFillColor(NSColor(srgbRed: 0.55, green: 0.56, blue: 0.6, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: CGFloat(h - 32), width: CGFloat(w), height: 32))
            if let label = o.menuBarLabel {
                let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]
                let str = NSAttributedString(string: label, attributes: attrs)
                let tw = str.size().width
                let r = CGRect(x: 14, y: CGFloat(h - 28), width: tw + 26, height: 24)
                NSColor(srgbRed: 0.42, green: 0.43, blue: 0.5, alpha: 1).setFill()
                NSBezierPath(roundedRect: r, xRadius: 9, yRadius: 9).fill()
                NSColor.white.setFill()
                NSBezierPath(roundedRect: CGRect(x: r.minX + 8, y: r.minY + 5, width: 4, height: 14), xRadius: 2, yRadius: 2).fill()
                str.draw(at: CGPoint(x: r.minX + 18, y: r.minY + 4))
            }
            let pw = CGFloat(pop.width) / 2          // popover is rendered at 2x
            let ph = CGFloat(pop.height) / 2
            let drawH = min(ph, CGFloat(h) - 44)
            ctx.saveGState()
            let rect = CGRect(x: 14, y: CGFloat(h) - 38 - drawH, width: pw, height: drawH)
            let clip = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
            ctx.addPath(clip); ctx.clip()
            // Show the top of the popover image, cropped to the available height.
            let cropped = pop.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(pop.width), height: (CGFloat(pop.height) * drawH / ph).rounded()))
            if let cropped { ctx.draw(cropped, in: rect) }
            ctx.restoreGState()
            NSColor(white: 1, alpha: 0.12).setStroke()
            let border = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12); border.lineWidth = 1; border.stroke()
        }

        if let c = o.cursor {
            let p = CGPoint(x: c.x, y: CGFloat(h) - c.y)
            let path = NSBezierPath()
            path.move(to: p)
            path.line(to: CGPoint(x: p.x, y: p.y - 17))
            path.line(to: CGPoint(x: p.x + 4.5, y: p.y - 13))
            path.line(to: CGPoint(x: p.x + 7.5, y: p.y - 19.5))
            path.line(to: CGPoint(x: p.x + 10, y: p.y - 18.5))
            path.line(to: CGPoint(x: p.x + 7, y: p.y - 12))
            path.line(to: CGPoint(x: p.x + 12.5, y: p.y - 12))
            path.close()
            NSColor.black.setStroke(); NSColor.white.setFill()
            path.lineWidth = 1.2
            path.fill(); path.stroke()
            if o.pressed {
                NSColor(white: 1, alpha: 0.35).setFill()
                NSBezierPath(ovalIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)).fill()
            }
        }

        func pill(_ text: String, center: CGPoint, fontSize: CGFloat, bg: NSColor) {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold), .foregroundColor: NSColor.white]
            let s = NSAttributedString(string: text, attributes: attrs)
            let sz = s.size()
            let r = CGRect(x: center.x - sz.width / 2 - 14, y: center.y - sz.height / 2 - 6, width: sz.width + 28, height: sz.height + 12)
            bg.setFill()
            NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2).fill()
            s.draw(at: CGPoint(x: r.minX + 14, y: r.minY + 6))
        }
        if let cap = o.caption { pill(cap, center: CGPoint(x: CGFloat(w) / 2, y: 30), fontSize: 15, bg: NSColor(srgbRed: 0.36, green: 0.53, blue: 0.9, alpha: 0.96)) }
        if let k = o.keys { pill(k, center: CGPoint(x: CGFloat(w) / 2, y: 78), fontSize: 17, bg: NSColor(white: 0, alpha: 0.78)) }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }
}
