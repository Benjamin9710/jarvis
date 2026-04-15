import Foundation
import SwiftUI

// swiftlint:disable file_length type_body_length
@MainActor
final class VoiceCaptureViewModel: ObservableObject {
  @Published private(set) var permissionState: VoiceCapturePermissionState = .unknown
  @Published private(set) var captureState: VoiceCaptureState = .idle
  @Published private(set) var audioLevel: VoiceCaptureLevel = .silent
  @Published private(set) var interactionState: VoiceInteractionState = .idle
  @Published private(set) var playbackState: VoiceResponsePlaybackState = .idle

  private let service: any VoiceCaptureServiceProtocol
  private let interactionClient: any BackendVoiceInteractionClientProtocol
  private let playbackService: any VoiceResponsePlaybackServiceProtocol
  private let backendConfiguration: BackendConfiguration?
  private var hasPrepared = false
  private var latestResponseAudio: VoiceResponseAudio?

  init(
    service: any VoiceCaptureServiceProtocol,
    interactionClient: any BackendVoiceInteractionClientProtocol,
    playbackService: any VoiceResponsePlaybackServiceProtocol,
    backendConfiguration: BackendConfiguration?
  ) {
    self.service = service
    self.interactionClient = interactionClient
    self.playbackService = playbackService
    self.backendConfiguration = backendConfiguration
    self.service.eventHandler = { [weak self] event in
      self?.handle(event: event)
    }
    self.playbackService.eventHandler = { [weak self] event in
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

  func handleReplayAction() {
    Task {
      await replayLatestResponse()
    }
  }

  func handlePrimaryActionAsync() async {
    switch captureState {
    case .recording:
      do {
        let clip = try await service.stopCapture()
        if let clip {
          await submitForInteraction(clip)
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

      await playbackService.stopPlayback()
      playbackState = .idle
      latestResponseAudio = nil
      interactionState = .idle

      do {
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
    if interactionState.isInFlight {
      return "Processing Latest Capture"
    }

    if case .failed = interactionState {
      return "Response Fault Detected"
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
    if interactionState.isInFlight {
      return
        "Jarvis is uploading the finalized clip, preparing a command response, and synthesizing the spoken reply."
    }

    if case .failed(let message) = interactionState {
      return message
    }

    switch captureState {
    case .idle, .ready:
      return
        "Push to talk whenever you are ready. Jarvis finalizes one clip on stop, "
        + "sends it to the backend, and returns a spoken response plus a short summary."
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

  var responsePanelTitle: String {
    if captureState == .recording {
      return "Incoming Signal"
    }

    return interactionState.isInFlight ? "Jarvis Relay" : "Jarvis Response"
  }

  var responseSummaryText: String {
    switch captureState {
    case .recording:
      return
        "Voice data is being captured locally. Jarvis will upload the finalized clip when you stop listening."
    case .permissionNeeded:
      return "Waiting for microphone permission before the capture channel can arm."
    case .error:
      return "Capture is unavailable. Reset the surface and try again."
    case .stopping, .idle, .ready:
      return resolvedSummaryText
    }
  }

  var transcriptText: String {
    switch captureState {
    case .recording:
      return "Live capture in progress."
    case .permissionNeeded:
      return "Transcript uplink is idle."
    case .error:
      return "Transcript uplink unavailable."
    case .stopping, .idle, .ready:
      return resolvedTranscriptText
    }
  }

  var spokenResponseText: String? {
    guard case .succeeded(let result) = interactionState else {
      return nil
    }

    guard result.spokenText != result.summaryText else {
      return nil
    }

    return result.spokenText
  }

  var shouldShowTranscript: Bool {
    !transcriptText.isEmpty
  }

  var shouldShowReplayButton: Bool {
    latestResponseAudio != nil && !interactionState.isInFlight
  }

  var replayButtonTitle: String {
    if case .playing = playbackState {
      return "Playing Response"
    }

    return "Replay Response"
  }

  var primaryButtonTitle: String {
    if interactionState.isInFlight {
      return "Processing"
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
    if interactionState.isInFlight {
      return "Reply in progress"
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
    if interactionState.isInFlight {
      return "Processing"
    }

    if case .failed = interactionState {
      return "Fault"
    }

    if case .playing = playbackState {
      return "Speaking"
    }

    if case .succeeded(let result) = interactionState, result.commandStatus == "unsupported" {
      return "Limited"
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

    return interactionState.isInFlight ? "Reply forming" : "Push-to-talk armed"
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
    if interactionState.isInFlight {
      return "Processing"
    }

    if case .failed = interactionState {
      return "Fault"
    }

    return backendConfiguration == nil ? "Not configured" : "LAN ready"
  }

  var playbackLabel: String {
    switch playbackState {
    case .idle:
      return latestResponseAudio == nil ? "Text only" : "Ready"
    case .playing:
      return "Playing"
    case .failed:
      return "Fault"
    }
  }

  var inputLevelLabel: String {
    "\(Int(audioLevel.normalized * 100))%"
  }

  var isPrimaryButtonDisabled: Bool {
    captureState == .stopping || interactionState.isInFlight
  }

  private func refreshFromService() async {
    permissionState = await service.currentPermissionState()
    let preferredState = service.currentCaptureState()
    captureState = resolvedState(permission: permissionState, preferred: preferredState)
  }

  private func resetAfterError() async {
    _ = try? await service.stopCapture()
    await playbackService.stopPlayback()
    playbackState = .idle
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

  private func handle(event: VoiceResponsePlaybackEvent) {
    switch event {
    case .stateChanged(let state):
      playbackState = state
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

  private var resolvedSummaryText: String {
    switch interactionState {
    case .idle:
      return backendConfiguration == nil
        ? """
        Backend link is not configured. Add JARVIS_CORE_API_BASE_URL and \
        JARVIS_API_BEARER_TOKEN to the app launch environment.
        """
        : "Mission control is standing by for the next push-to-talk session."
    case .inFlight:
      return
        "Jarvis is transcribing your request, preparing the command reply, and synthesizing voice playback."
    case .succeeded(let result):
      return result.summaryText
    case .failed(let message):
      return message
    }
  }

  private var resolvedTranscriptText: String {
    switch interactionState {
    case .idle:
      return backendConfiguration == nil
        ? ""
        : "Transcript will appear here after the next completed capture."
    case .inFlight:
      return "Uploading the latest clip to the backend and waiting for Jarvis to respond."
    case .succeeded(let result):
      return result.transcriptText.isEmpty
        ? "No speech was detected in the latest capture."
        : result.transcriptText
    case .failed:
      return ""
    }
  }

  private func submitForInteraction(_ clip: RecordedAudioClip) async {
    interactionState = .inFlight
    let requestID = UUID().uuidString

    guard let backendConfiguration else {
      interactionState = .failed(
        """
        Backend link is not configured. Add JARVIS_CORE_API_BASE_URL and \
        JARVIS_API_BEARER_TOKEN to the app launch environment.
        """
      )
      deleteClip(at: clip.fileURL)
      return
    }

    do {
      let result = try await interactionClient.interact(
        clip: clip,
        configuration: backendConfiguration,
        clientRequestID: requestID
      )
      interactionState = .succeeded(result)
      latestResponseAudio = decodeResponseAudio(from: result)
      if let latestResponseAudio {
        try? await playbackService.play(responseAudio: latestResponseAudio)
      } else {
        playbackState = .idle
      }
    } catch {
      let message =
        (error as? LocalizedError)?.errorDescription
        ?? "Jarvis could not process the latest voice interaction."
      interactionState = .failed(message)
    }

    deleteClip(at: clip.fileURL)
  }

  private func replayLatestResponse() async {
    guard let latestResponseAudio else {
      return
    }

    do {
      try await playbackService.play(responseAudio: latestResponseAudio)
    } catch {
      let message =
        (error as? LocalizedError)?.errorDescription
        ?? "Jarvis could not replay the latest response."
      playbackState = .failed(message)
    }
  }

  private func decodeResponseAudio(
    from result: BackendVoiceInteractionResult
  ) -> VoiceResponseAudio? {
    guard
      let responseAudioBase64 = result.responseAudioBase64,
      let responseAudioContentType = result.responseAudioContentType
    else {
      return nil
    }

    guard let data = Data(base64Encoded: responseAudioBase64) else {
      playbackState = .failed("Jarvis returned unreadable response audio.")
      return nil
    }

    return VoiceResponseAudio(
      data: data,
      contentType: responseAudioContentType,
      sampleRateHZ: result.responseAudioSampleRateHZ
    )
  }

  private func deleteClip(at fileURL: URL) {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
// swiftlint:enable file_length type_body_length
