import Foundation
import SwiftUI

// swiftlint:disable type_body_length
@MainActor
final class VoiceCaptureViewModel: ObservableObject {
  @Published private(set) var permissionState: VoiceCapturePermissionState = .unknown
  @Published private(set) var captureState: VoiceCaptureState = .idle
  @Published private(set) var audioLevel: VoiceCaptureLevel = .silent
  @Published private(set) var transcriptionState: VoiceTranscriptionState = .idle

  private let service: any VoiceCaptureServiceProtocol
  private let transcriptionClient: any BackendTranscriptionClientProtocol
  private let backendConfiguration: BackendConfiguration?
  private var hasPrepared = false

  init(
    service: any VoiceCaptureServiceProtocol,
    transcriptionClient: any BackendTranscriptionClientProtocol,
    backendConfiguration: BackendConfiguration?
  ) {
    self.service = service
    self.transcriptionClient = transcriptionClient
    self.backendConfiguration = backendConfiguration
    self.service.eventHandler = { [weak self] event in
      self?.handle(event: event)
    }
  }

  func prepare() async {
    guard !hasPrepared else {
      return
    }

    hasPrepared = true
    await refreshFromService()
  }

  func handlePrimaryAction() {
    Task {
      await handlePrimaryActionAsync()
    }
  }

  func handlePrimaryActionAsync() async {
    switch captureState {
    case .recording:
      do {
        let clip = try await service.stopCapture()
        if let clip {
          await submitForTranscription(clip)
        }
      } catch {
        let message =
          (error as? LocalizedError)?.errorDescription
          ?? "Jarvis could not finalize the captured audio clip."
        captureState = .error(message)
      }
    case .stopping:
      break
    case .error:
      await resetAfterError()
    case .idle, .permissionNeeded, .ready:
      if permissionState != .granted {
        permissionState = await service.requestPermission()
        captureState = resolvedState(
          permission: permissionState, preferred: service.currentCaptureState())

        guard permissionState == .granted else {
          return
        }
      }

      do {
        transcriptionState = .idle
        try await service.startCapture()
      } catch {
        let message =
          (error as? LocalizedError)?.errorDescription
          ?? "Jarvis could not start microphone capture."
        captureState = .error(message)
      }
    }
  }

  var headline: String {
    if transcriptionState.isInFlight {
      return "Transcribing Latest Capture"
    }

    if case .failed = transcriptionState {
      return "Transcription Fault Detected"
    }

    switch captureState {
    case .idle, .ready:
      return "Capture System Ready"
    case .permissionNeeded:
      return "Microphone Access Required"
    case .recording:
      return "Listening For Input"
    case .stopping:
      return "Closing Audio Channel"
    case .error:
      return "Capture Fault Detected"
    }
  }

  var detailText: String {
    if transcriptionState.isInFlight {
      return
        "Jarvis is uploading the finalized clip to the backend and waiting for the offline transcription result."
    }

    if case .failed(let message) = transcriptionState {
      return message
    }

    switch captureState {
    case .idle, .ready:
      return
        "Push to talk whenever you are ready. Jarvis finalizes one clip on stop, "
        + "sends it to the backend, and renders the returned transcript here."
    case .permissionNeeded:
      return
        "Grant microphone access to arm the voice capture surface on iPhone and simulator test fixtures."
    case .recording:
      return
        "Capture is live. Jarvis is metering locally and writing one temporary WAV clip for upload after you stop."
    case .stopping:
      return "The microphone pipeline is winding down and returning the interface to standby."
    case .error(let message):
      return message
    }
  }

  var transcriptPanelTitle: String {
    if captureState == .recording {
      return "Incoming Signal"
    }

    return transcriptionState.isInFlight ? "Transcription Relay" : "Transcript Uplink"
  }

  var transcriptText: String {
    switch captureState {
    case .recording:
      return
        "Voice data is being captured locally. Jarvis will upload the finalized clip when you stop listening."
    case .permissionNeeded:
      return "Waiting for microphone permission before the capture channel can arm."
    case .error:
      return "Capture is unavailable. Reset the surface and try again."
    case .stopping, .idle, .ready:
      return resolvedTranscriptText
    }
  }

  var primaryButtonTitle: String {
    if transcriptionState.isInFlight {
      return "Transcribing"
    }

    switch captureState {
    case .permissionNeeded:
      return "Enable Microphone"
    case .recording:
      return "Stop Listening"
    case .stopping:
      return "Stopping"
    case .error:
      return "Reset Capture"
    case .idle, .ready:
      return "Start Listening"
    }
  }

  var primaryButtonSubtitle: String {
    if transcriptionState.isInFlight {
      return "Upload in progress"
    }

    switch captureState {
    case .permissionNeeded:
      return "Authorize capture"
    case .recording:
      return "End local input"
    case .stopping:
      return "Closing session"
    case .error:
      return "Return to standby"
    case .idle, .ready:
      return "Arm push-to-talk"
    }
  }

  var statusBannerText: String {
    if transcriptionState.isInFlight {
      return "Transcribing"
    }

    if case .failed = transcriptionState {
      return "Fault"
    }

    switch captureState {
    case .recording:
      return "Live"
    case .error:
      return "Fault"
    case .permissionNeeded:
      return "Permission"
    case .stopping:
      return "Stopping"
    case .idle, .ready:
      return "Standby"
    }
  }

  var captureModeLabel: String {
    if captureState == .recording {
      return "Push-to-talk active"
    }

    return transcriptionState.isInFlight ? "Upload in progress" : "Push-to-talk armed"
  }

  var permissionLabel: String {
    switch permissionState {
    case .granted:
      return "Microphone granted"
    case .denied:
      return "Microphone denied"
    case .unknown:
      return "Permission unresolved"
    }
  }

  var networkLabel: String {
    if transcriptionState.isInFlight {
      return "Transcribing"
    }

    if case .failed = transcriptionState {
      return "Fault"
    }

    return backendConfiguration == nil ? "Not configured" : "LAN ready"
  }

  var inputLevelLabel: String {
    "\(Int(audioLevel.normalized * 100))%"
  }

  var isPrimaryButtonDisabled: Bool {
    captureState == .stopping || transcriptionState.isInFlight
  }

  private func refreshFromService() async {
    permissionState = await service.currentPermissionState()
    let preferredState = service.currentCaptureState()
    captureState = resolvedState(permission: permissionState, preferred: preferredState)
  }

  private func resetAfterError() async {
    _ = try? await service.stopCapture()
    await refreshFromService()
  }

  private func handle(event: VoiceCaptureEvent) {
    switch event {
    case .permissionChanged(let permission):
      permissionState = permission
    case .stateChanged(let state):
      captureState = state
    case .levelChanged(let level):
      audioLevel = level
    }
  }

  private func resolvedState(
    permission: VoiceCapturePermissionState,
    preferred: VoiceCaptureState
  ) -> VoiceCaptureState {
    switch preferred {
    case .recording, .stopping, .error:
      return preferred
    case .idle, .ready, .permissionNeeded:
      return permission == .granted ? .ready : .permissionNeeded
    }
  }

  private var resolvedTranscriptText: String {
    switch transcriptionState {
    case .idle:
      return backendConfiguration == nil
        ? """
        Backend link is not configured. Add JARVIS_CORE_API_BASE_URL and \
        JARVIS_API_BEARER_TOKEN to the app launch environment.
        """
        : "Mission control is standing by for the next push-to-talk session."
    case .inFlight:
      return "Uploading the latest clip to the backend and waiting for the offline transcript."
    case .succeeded(let result):
      return result.transcriptText.isEmpty
        ? "No speech was detected in the latest capture."
        : result.transcriptText
    case .failed(let message):
      return message
    }
  }

  private func submitForTranscription(_ clip: RecordedAudioClip) async {
    transcriptionState = .inFlight
    let requestID = UUID().uuidString

    guard let backendConfiguration else {
      transcriptionState = .failed(
        """
        Backend link is not configured. Add JARVIS_CORE_API_BASE_URL and \
        JARVIS_API_BEARER_TOKEN to the app launch environment.
        """
      )
      deleteClip(at: clip.fileURL)
      return
    }

    do {
      let result = try await transcriptionClient.transcribe(
        clip: clip,
        configuration: backendConfiguration,
        clientRequestID: requestID
      )
      transcriptionState = .succeeded(result)
    } catch {
      let message =
        (error as? LocalizedError)?.errorDescription
        ?? "Jarvis could not transcribe the latest upload."
      transcriptionState = .failed(message)
    }

    deleteClip(at: clip.fileURL)
  }

  private func deleteClip(at fileURL: URL) {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
// swiftlint:enable type_body_length
