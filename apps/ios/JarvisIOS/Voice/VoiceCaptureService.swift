import AVFoundation
import Foundation

enum VoiceCaptureServiceError: LocalizedError {
    case permissionDenied
    case runtime(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required before Jarvis can capture your voice."
        case let .runtime(message):
            return message
        }
    }
}

@MainActor
final class VoiceCaptureService: VoiceCaptureServiceProtocol {
    var eventHandler: ((VoiceCaptureEvent) -> Void)?

    private let audioSession: AVAudioSession
    private let engine: AVAudioEngine
    private var inputTapInstalled = false

    init(
        audioSession: AVAudioSession = .sharedInstance(),
        engine: AVAudioEngine = AVAudioEngine()
    ) {
        self.audioSession = audioSession
        self.engine = engine
    }

    func currentPermissionState() async -> VoiceCapturePermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    func currentCaptureState() -> VoiceCaptureState {
        engine.isRunning ? .recording : .idle
    }

    func requestPermission() async -> VoiceCapturePermissionState {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { result in
                continuation.resume(returning: result)
            }
        }

        let permissionState: VoiceCapturePermissionState = granted ? .granted : .denied
        eventHandler?(.permissionChanged(permissionState))

        return permissionState
    }

    func startCapture() async throws {
        let permissionState = await currentPermissionState()
        guard permissionState == .granted else {
            eventHandler?(.stateChanged(.permissionNeeded))
            throw VoiceCaptureServiceError.permissionDenied
        }

        guard !engine.isRunning else {
            eventHandler?(.stateChanged(.recording))
            return
        }

        do {
            try configureAudioSession()
            installTapIfNeeded()
            engine.prepare()
            try engine.start()
            eventHandler?(.stateChanged(.recording))
        } catch {
            let message = "Jarvis could not start the microphone input chain."
            eventHandler?(.stateChanged(.error(message)))
            throw VoiceCaptureServiceError.runtime(message)
        }
    }

    func stopCapture() async {
        if engine.isRunning {
            eventHandler?(.stateChanged(.stopping))
            engine.stop()
        }

        if inputTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }

        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        eventHandler?(.levelChanged(.silent))

        let permissionState = await currentPermissionState()
        eventHandler?(.stateChanged(permissionState == .granted ? .ready : .permissionNeeded))
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: [])
    }

    private func installTapIfNeeded() {
        guard !inputTapInstalled else {
            return
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        inputTapInstalled = true
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return
        }

        let channel = channelData[0]
        var total: Float = 0

        for index in 0..<frameLength {
            let sample = channel[index]
            total += sample * sample
        }

        let rms = sqrt(total / Float(frameLength))
        let normalizedLevel = VoiceCaptureLevel(normalized: min(Double(rms) * 5.0, 1.0))

        Task { [weak self] in
            await MainActor.run {
                self?.eventHandler?(.levelChanged(normalizedLevel))
            }
        }
    }
}
