// Usage: swift scripts/extract-frames.swift video.mp4 outDir t1 t2 ...   (times in seconds)
import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count >= 4 else { print("usage: extract-frames video outDir t..."); exit(2) }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.appliesPreferredTrackTransform = true
try? FileManager.default.createDirectory(atPath: args[2], withIntermediateDirectories: true)
let dur = CMTimeGetSeconds(asset.duration)
print("duration \(dur)s, size \(asset.tracks(withMediaType: .video).first.map { "\($0.naturalSize)" } ?? "?")")
for t in args[3...].compactMap(Double.init) {
    do {
        let img = try gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
        let rep = NSBitmapImageRep(cgImage: img)
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(args[2])/frame-\(Int(t)).png"))
        print("frame at \(t)s ok")
    } catch { print("frame at \(t)s failed: \(error)") }
}
