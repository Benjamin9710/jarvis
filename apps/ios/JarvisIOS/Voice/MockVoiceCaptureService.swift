import Foundation

enum AppCaptureScenario: String {
  case ready
  case permissionNeeded = "permission-needed"
  case recording
  case error
}

@MainActor
final class MockVoiceCaptureService: VoiceCaptureServiceProtocol {
  var eventHandler: ((VoiceCaptureEvent) -> Void)?

  private let fileManager: FileManager
  private(set) var permissionState: VoiceCapturePermissionState
  private(set) var captureState: VoiceCaptureState
  private let permissionRequestResult: VoiceCapturePermissionState
  private let startError: String?
  private var meterTask: Task<Void, Never>?

  init(
    permissionState: VoiceCapturePermissionState,
    initialState: VoiceCaptureState,
    permissionRequestResult: VoiceCapturePermissionState? = nil,
    startError: String? = nil,
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    self.permissionState = permissionState
    self.captureState = initialState
    self.permissionRequestResult = permissionRequestResult ?? permissionState
    self.startError = startError

    if initialState == .recording {
      startMeteringIfNeeded()
    }
  }

  convenience init(scenario: AppCaptureScenario) {
    switch scenario {
    case .ready:
      self.init(permissionState: .granted, initialState: .ready)
    case .permissionNeeded:
      self.init(
        permissionState: .denied, initialState: .permissionNeeded, permissionRequestResult: .denied)
    case .recording:
      self.init(permissionState: .granted, initialState: .recording)
    case .error:
      self.init(
        permissionState: .granted,
        initialState: .error("Audio engine unavailable in the test fixture."),
        startError: "Audio engine unavailable in the test fixture."
      )
    }
  }

  func currentPermissionState() async -> VoiceCapturePermissionState {
    permissionState
  }

  func currentCaptureState() -> VoiceCaptureState {
    captureState
  }

  func requestPermission() async -> VoiceCapturePermissionState {
    permissionState = permissionRequestResult
    captureState = permissionState == .granted ? .ready : .permissionNeeded
    eventHandler?(.permissionChanged(permissionState))
    eventHandler?(.stateChanged(captureState))
    return permissionState
  }

  func startCapture() async throws {
    guard permissionState == .granted else {
      captureState = .permissionNeeded
      eventHandler?(.stateChanged(captureState))
      throw VoiceCaptureServiceError.permissionDenied
    }

    if let startError {
      captureState = .error(startError)
      eventHandler?(.stateChanged(captureState))
      throw VoiceCaptureServiceError.runtime(startError)
    }

    captureState = .recording
    eventHandler?(.stateChanged(captureState))
    startMeteringIfNeeded()
  }

  func stopCapture() async throws -> RecordedAudioClip? {
    captureState = .stopping
    eventHandler?(.stateChanged(captureState))
    meterTask?.cancel()
    meterTask = nil
    eventHandler?(.levelChanged(.silent))

    captureState = permissionState == .granted ? .ready : .permissionNeeded
    eventHandler?(.stateChanged(captureState))

    let filename = "jarvis-mock-capture-\(UUID().uuidString).wav"
    let fileURL = fileManager.temporaryDirectory.appending(path: filename)
    try? Data("mock-audio".utf8).write(to: fileURL)
    return RecordedAudioClip(
      fileURL: fileURL,
      filename: filename,
      contentType: "audio/wav"
    )
  }

  private func startMeteringIfNeeded() {
    guard meterTask == nil else {
      return
    }

    meterTask = Task { [weak self] in
      let levels = [0.12, 0.32, 0.54, 0.38, 0.7, 0.28]
      var index = 0

      while !Task.isCancelled {
        let currentLevel = VoiceCaptureLevel(normalized: levels[index % levels.count])
        await MainActor.run {
          self?.eventHandler?(.levelChanged(currentLevel))
        }
        index += 1

        try? await Task.sleep(nanoseconds: 180_000_000)
      }
    }
  }
}
