@preconcurrency import AVFoundation
import Foundation

// swiftlint:disable file_length type_body_length

enum VoiceCaptureServiceError: LocalizedError {
  case permissionDenied
  case captureFileUnavailable
  case runtime(String)

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Microphone access is required before Jarvis can capture your voice."
    case .captureFileUnavailable:
      return "Jarvis could not finalize the captured audio clip."
    case .runtime(let message):
      return message
    }
  }
}

enum VoiceResponsePlaybackServiceError: LocalizedError {
  case unsupportedAudioFormat
  case playbackFailed(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedAudioFormat:
      return "Jarvis returned an unsupported response audio format."
    case .playbackFailed(let message):
      return message
    }
  }
}

@MainActor
final class VoiceCaptureService: VoiceCaptureServiceProtocol {
  var eventHandler: ((VoiceCaptureEvent) -> Void)?

  private let audioSession: AVAudioSession
  private let engine: AVAudioEngine
  private let fileManager: FileManager
  private var inputTapInstalled = false
  private let recordingLock = NSLock()
  private var activeRecording: ActiveRecording?
  private var pendingRecordingError: String?

  private final class ActiveRecording {
    let fileURL: URL
    let filename: String
    let contentType: String
    let audioFile: AVAudioFile
    let outputFormat: AVAudioFormat

    init(
      fileURL: URL,
      filename: String,
      contentType: String,
      audioFile: AVAudioFile,
      outputFormat: AVAudioFormat
    ) {
      self.fileURL = fileURL
      self.filename = filename
      self.contentType = contentType
      self.audioFile = audioFile
      self.outputFormat = outputFormat
    }
  }

  init(
    audioSession: AVAudioSession = .sharedInstance(),
    engine: AVAudioEngine = AVAudioEngine(),
    fileManager: FileManager = .default
  ) {
    self.audioSession = audioSession
    self.engine = engine
    self.fileManager = fileManager
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
      try prepareRecordingFile()
      installTapIfNeeded()
      engine.prepare()
      try engine.start()
      eventHandler?(.stateChanged(.recording))
    } catch {
      cleanupActiveRecording()
      let message = "Jarvis could not start the microphone input chain."
      eventHandler?(.stateChanged(.error(message)))
      throw VoiceCaptureServiceError.runtime(message)
    }
  }

  func stopCapture() async throws -> RecordedAudioClip? {
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

    let recordingResult = try finalizeRecording()

    let permissionState = await currentPermissionState()
    eventHandler?(.stateChanged(permissionState == .granted ? .ready : .permissionNeeded))
    return recordingResult
  }

  private func configureAudioSession() throws {
    try audioSession.setCategory(
      .playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
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

  private func prepareRecordingFile() throws {
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
      )
    else {
      throw VoiceCaptureServiceError.captureFileUnavailable
    }

    let filename = "jarvis-capture-\(UUID().uuidString).wav"
    let fileURL = fileManager.temporaryDirectory.appending(path: filename)
    let audioFile = try AVAudioFile(
      forWriting: fileURL,
      settings: outputFormat.settings,
      commonFormat: outputFormat.commonFormat,
      interleaved: outputFormat.isInterleaved
    )

    recordingLock.lock()
    pendingRecordingError = nil
    activeRecording = ActiveRecording(
      fileURL: fileURL,
      filename: filename,
      contentType: "audio/wav",
      audioFile: audioFile,
      outputFormat: outputFormat
    )
    recordingLock.unlock()
  }

  private func process(buffer: AVAudioPCMBuffer) {
    write(buffer: buffer)

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

  private func write(buffer: AVAudioPCMBuffer) {
    recordingLock.lock()
    let recording = activeRecording
    recordingLock.unlock()

    guard let recording else {
      return
    }

    do {
      let convertedBuffer = try convert(buffer: buffer, for: recording)
      if convertedBuffer.frameLength > 0 {
        try recording.audioFile.write(from: convertedBuffer)
      }
    } catch {
      recordingLock.lock()
      pendingRecordingError = "Jarvis could not write the captured audio clip."
      recordingLock.unlock()
    }
  }

  private func convert(
    buffer: AVAudioPCMBuffer,
    for recording: ActiveRecording
  ) throws -> AVAudioPCMBuffer {
    guard let converter = AVAudioConverter(from: buffer.format, to: recording.outputFormat) else {
      throw VoiceCaptureServiceError.captureFileUnavailable
    }

    let sampleRateRatio = recording.outputFormat.sampleRate / buffer.format.sampleRate
    let outputCapacity = AVAudioFrameCount(
      max(1, ceil(Double(buffer.frameLength) * sampleRateRatio) + 1)
    )

    guard
      let convertedBuffer = AVAudioPCMBuffer(
        pcmFormat: recording.outputFormat,
        frameCapacity: outputCapacity
      )
    else {
      throw VoiceCaptureServiceError.captureFileUnavailable
    }

    var sourceBuffer: AVAudioPCMBuffer? = buffer
    var conversionError: NSError?
    // swiftlint:disable closure_parameter_position
    let status = converter.convert(to: convertedBuffer, error: &conversionError) {
      _, outStatus in
      guard let currentSourceBuffer = sourceBuffer else {
        outStatus.pointee = .endOfStream
        return nil
      }

      outStatus.pointee = .haveData
      sourceBuffer = nil
      return currentSourceBuffer
    }
    // swiftlint:enable closure_parameter_position

    if let conversionError {
      throw conversionError
    }

    if status == .error {
      throw VoiceCaptureServiceError.captureFileUnavailable
    }

    return convertedBuffer
  }

  private func finalizeRecording() throws -> RecordedAudioClip? {
    recordingLock.lock()
    let recording = activeRecording
    let pendingError = pendingRecordingError
    activeRecording = nil
    pendingRecordingError = nil
    recordingLock.unlock()

    guard pendingError == nil else {
      if let recording {
        try? fileManager.removeItem(at: recording.fileURL)
      }
      throw VoiceCaptureServiceError.captureFileUnavailable
    }

    guard let recording else {
      return nil
    }

    return RecordedAudioClip(
      fileURL: recording.fileURL,
      filename: recording.filename,
      contentType: recording.contentType
    )
  }

  private func cleanupActiveRecording() {
    recordingLock.lock()
    let recording = activeRecording
    activeRecording = nil
    pendingRecordingError = nil
    recordingLock.unlock()

    if let recording {
      try? fileManager.removeItem(at: recording.fileURL)
    }
  }
}
@MainActor
// swiftlint:disable opening_brace
final class VoiceResponsePlaybackService: NSObject, AVAudioPlayerDelegate,
  VoiceResponsePlaybackServiceProtocol
{
  var eventHandler: ((VoiceResponsePlaybackEvent) -> Void)?

  private let audioSession: AVAudioSession
  private var player: AVAudioPlayer?

  init(audioSession: AVAudioSession = .sharedInstance()) {
    self.audioSession = audioSession
    super.init()
  }

  func play(responseAudio: VoiceResponseAudio) async throws {
    guard responseAudio.contentType == "audio/wav" else {
      let error = VoiceResponsePlaybackServiceError.unsupportedAudioFormat
      eventHandler?(.stateChanged(.failed(error.errorDescription ?? "Playback failed.")))
      throw error
    }

    await stopPlayback()

    do {
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true, options: [])

      let player = try AVAudioPlayer(data: responseAudio.data)
      player.delegate = self
      player.prepareToPlay()

      guard player.play() else {
        throw VoiceResponsePlaybackServiceError.playbackFailed(
          "Jarvis could not start playback for the response audio."
        )
      }

      self.player = player
      eventHandler?(.stateChanged(.playing))
    } catch {
      let message =
        (error as? LocalizedError)?.errorDescription
        ?? "Jarvis could not start playback for the response audio."
      eventHandler?(.stateChanged(.failed(message)))
      throw VoiceResponsePlaybackServiceError.playbackFailed(message)
    }
  }

  func stopPlayback() async {
    if let player {
      player.stop()
      self.player = nil
    }

    try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    eventHandler?(.stateChanged(.idle))
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor [weak self] in
      guard let self else {
        return
      }

      self.player = nil
      try? self.audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
      self.eventHandler?(.stateChanged(.idle))
      _ = flag
      _ = player
    }
  }

  nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    Task { @MainActor [weak self] in
      guard let self else {
        return
      }

      self.player = nil
      let message =
        (error as? LocalizedError)?.errorDescription
        ?? "Jarvis encountered an error while decoding the response audio."
      self.eventHandler?(.stateChanged(.failed(message)))
      _ = player
    }
  }
}
// swiftlint:enable opening_brace
// swiftlint:enable file_length type_body_length
