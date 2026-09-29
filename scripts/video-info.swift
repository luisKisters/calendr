import AVFoundation
import CoreMedia
for path in CommandLine.arguments.dropFirst() {
    let a = AVURLAsset(url: URL(fileURLWithPath: path))
    let sem = DispatchSemaphore(value: 0)
    Task {
        let tracks = try await a.loadTracks(withMediaType: .video)
        let t = tracks[0]
        let fmts = try await t.load(.formatDescriptions)
        let fd = fmts[0]
        let sub = CMFormatDescriptionGetMediaSubType(fd)
        let code = String(format: "%c%c%c%c", (sub>>24)&255,(sub>>16)&255,(sub>>8)&255,sub&255)
        let size = try await t.load(.naturalSize); let fps = try await t.load(.nominalFrameRate); let dur = try await a.load(.duration)
        let ext = CMFormatDescriptionGetExtensions(fd) as? [String: Any]
        print(path, "codec", code, "size", size, "fps", fps, "dur", CMTimeGetSeconds(dur), "playable", try await a.load(.isPlayable))
        print("  ", ext?["FullRangeVideo"] ?? "-", ext?["CVImageBufferYCbCrMatrix"] ?? "-", (ext?["SampleDescriptionExtensionAtoms"] as? [String: Any])?.keys.sorted() ?? [])
        sem.signal()
    }
    sem.wait()
}
