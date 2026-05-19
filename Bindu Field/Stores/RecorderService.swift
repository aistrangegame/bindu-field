import AVFoundation

@MainActor
final class RecorderService: NSObject {
    static let shared = RecorderService()

    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    var isRecording: Bool { recorder?.isRecording ?? false }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    func start() throws -> URL {
        let filename = "\(UUID().uuidString).m4a"
        let url = Letter.lettersDirectory.appendingPathComponent(filename)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        startTime = Date()

        return url
    }

    func stop() -> Double {
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        recorder?.stop()
        recorder = nil
        startTime = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        return duration
    }

    func cancel() {
        if let url = recorder?.url {
            recorder?.stop()
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        startTime = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    func peakLevel() -> Float {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        return max(0, min(1, (db + 60) / 60))
    }
}
