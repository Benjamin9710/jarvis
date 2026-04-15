import Foundation

enum VoiceCapturePermissionState: String, Equatable {
  case unknown
  case denied
  case granted
}

enum VoiceCaptureState: Equatable {
  case idle
  case permissionNeeded
  case ready
  case recording
  case stopping
  case error(String)

  var errorMessage: String? {
    if case .error(let message) = self {
      return message
    }

    return nil
  }
}

struct VoiceCaptureLevel: Equatable {
  let normalized: Double

  init(normalized: Double) {
    self.normalized = min(max(normalized, 0), 1)
  }

  static let silent = VoiceCaptureLevel(normalized: 0)
}

struct RecordedAudioClip: Equatable {
  let fileURL: URL
  let filename: String
  let contentType: String
}

enum VoiceCaptureEvent: Equatable {
  case permissionChanged(VoiceCapturePermissionState)
  case stateChanged(VoiceCaptureState)
  case levelChanged(VoiceCaptureLevel)
}

struct VoiceResponseAudio: Equatable {
  let data: Data
  let contentType: String
  let sampleRateHZ: Int?
}

enum VoiceResponsePlaybackState: Equatable {
  case idle
  case playing
  case failed(String)
}

enum VoiceResponsePlaybackEvent: Equatable {
  case stateChanged(VoiceResponsePlaybackState)
}

@MainActor
protocol VoiceCaptureServiceProtocol: AnyObject {
  var eventHandler: ((VoiceCaptureEvent) -> Void)? { get set }

  func currentPermissionState() async -> VoiceCapturePermissionState
  func currentCaptureState() -> VoiceCaptureState
  func requestPermission() async -> VoiceCapturePermissionState
  func startCapture() async throws
  func stopCapture() async throws -> RecordedAudioClip?
}

@MainActor
protocol VoiceResponsePlaybackServiceProtocol: AnyObject {
  var eventHandler: ((VoiceResponsePlaybackEvent) -> Void)? { get set }

  func play(responseAudio: VoiceResponseAudio) async throws
  func stopPlayback() async
}
