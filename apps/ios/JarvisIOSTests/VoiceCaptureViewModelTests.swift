import XCTest

@testable import JarvisIOS

@MainActor
final class VoiceCaptureViewModelTests: XCTestCase {
  func testPrepareMapsUnknownPermissionToPermissionNeeded() async {
    let service = MockVoiceCaptureService(permissionState: .unknown, initialState: .idle)
    let viewModel = VoiceCaptureViewModel(
      service: service,
      interactionClient: MockBackendTranscriptionClient(delayNanoseconds: 0),
      playbackService: MockVoiceResponsePlaybackService(),
      backendConfiguration: nil
    )

    await viewModel.prepare()

    XCTAssertEqual(viewModel.permissionState, .unknown)
    XCTAssertEqual(viewModel.captureState, .permissionNeeded)
  }

  func testPrimaryActionRequestsPermissionAndStartsCapture() async {
    let service = MockVoiceCaptureService(
      permissionState: .unknown,
      initialState: .permissionNeeded,
      permissionRequestResult: .granted
    )
    let viewModel = VoiceCaptureViewModel(
      service: service,
      interactionClient: MockBackendTranscriptionClient(delayNanoseconds: 0),
      playbackService: MockVoiceResponsePlaybackService(),
      backendConfiguration: BackendConfiguration(
        baseURL: URL(string: "http://jarvis.local")!,
        bearerToken: "test-token",
        deviceName: "CI iPhone"
      )
    )

    await viewModel.prepare()
    await viewModel.handlePrimaryActionAsync()

    XCTAssertEqual(viewModel.permissionState, .granted)
    XCTAssertEqual(viewModel.captureState, .recording)
  }

  func testStoppingCaptureUploadsClipAndRendersResponseAndPlayback() async {
    let service = MockVoiceCaptureService(permissionState: .granted, initialState: .ready)
    let interactionClient = MockBackendTranscriptionClient(delayNanoseconds: 0)
    let playbackService = MockVoiceResponsePlaybackService()
    let viewModel = VoiceCaptureViewModel(
      service: service,
      interactionClient: interactionClient,
      playbackService: playbackService,
      backendConfiguration: BackendConfiguration(
        baseURL: URL(string: "http://jarvis.local")!,
        bearerToken: "test-token",
        deviceName: "CI iPhone"
      )
    )

    await viewModel.prepare()
    await viewModel.handlePrimaryActionAsync()
    XCTAssertEqual(viewModel.captureState, .recording)

    await viewModel.handlePrimaryActionAsync()
    XCTAssertEqual(viewModel.captureState, .ready)
    XCTAssertEqual(viewModel.audioLevel, .silent)
    XCTAssertEqual(
      viewModel.interactionState,
      .succeeded(
        BackendVoiceInteractionResult(
          requestID: interactionClient.requestIDs[0],
          transcriptText: "Turn on the kitchen lights",
          normalizedText: "turn on the kitchen lights",
          commandStatus: "succeeded",
          commandAction: "turn_on",
          commandTarget: "kitchen",
          summaryText: "Kitchen lights turned on",
          spokenText: "Certainly. The kitchen lights are now on.",
          responseAudioBase64: Data("mock-audio".utf8).base64EncodedString(),
          responseAudioContentType: "audio/wav",
          responseAudioSampleRateHZ: 24_000,
          sttProvider: "mock-backend",
          ttsProvider: "mock-tts",
          ttsStatus: "succeeded"
        )
      )
    )
    XCTAssertEqual(viewModel.responseSummaryText, "Kitchen lights turned on")
    XCTAssertEqual(viewModel.transcriptText, "Turn on the kitchen lights")
    XCTAssertEqual(playbackService.playedResponses.count, 1)
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: interactionClient.uploadedClipURLs[0].path
      )
    )
  }

  func testPrimaryActionSurfacesServiceError() async {
    let service = MockVoiceCaptureService(
      permissionState: .granted,
      initialState: .ready,
      startError: "Input node failed to initialize."
    )
    let viewModel = VoiceCaptureViewModel(
      service: service,
      interactionClient: MockBackendTranscriptionClient(delayNanoseconds: 0),
      playbackService: MockVoiceResponsePlaybackService(),
      backendConfiguration: BackendConfiguration(
        baseURL: URL(string: "http://jarvis.local")!,
        bearerToken: "test-token",
        deviceName: "CI iPhone"
      )
    )

    await viewModel.prepare()
    await viewModel.handlePrimaryActionAsync()

    XCTAssertEqual(viewModel.captureState, .error("Input node failed to initialize."))
    XCTAssertEqual(viewModel.headline, "Capture Fault Detected")
  }

  func testStopCaptureWithoutBackendConfigurationShowsDeterministicErrorAndDeletesClip() async {
    let service = MockVoiceCaptureService(permissionState: .granted, initialState: .ready)
    let interactionClient = MockBackendTranscriptionClient(delayNanoseconds: 0)
    let viewModel = VoiceCaptureViewModel(
      service: service,
      interactionClient: interactionClient,
      playbackService: MockVoiceResponsePlaybackService(),
      backendConfiguration: nil
    )

    await viewModel.prepare()
    await viewModel.handlePrimaryActionAsync()
    await viewModel.handlePrimaryActionAsync()

    XCTAssertEqual(
      viewModel.interactionState,
      .failed(
        """
        Backend link is not configured. Add JARVIS_CORE_API_BASE_URL and \
        JARVIS_API_BEARER_TOKEN to the app launch environment.
        """
      )
    )
    XCTAssertTrue(interactionClient.requestIDs.isEmpty)
  }

  func testSuccessfulInteractionWithoutAudioKeepsTextAndReplayHidden() async {
    let service = MockVoiceCaptureService(permissionState: .granted, initialState: .ready)
    let interactionClient = MockBackendTranscriptionClient(scenario: .missingAudio)
    let playbackService = MockVoiceResponsePlaybackService()
    let viewModel = VoiceCaptureViewModel(
      service: service,
      interactionClient: interactionClient,
      playbackService: playbackService,
      backendConfiguration: BackendConfiguration(
        baseURL: URL(string: "http://jarvis.local")!,
        bearerToken: "test-token",
        deviceName: "CI iPhone"
      )
    )

    await viewModel.prepare()
    await viewModel.handlePrimaryActionAsync()
    await viewModel.handlePrimaryActionAsync()

    XCTAssertEqual(viewModel.responseSummaryText, "Kitchen lights turned on")
    XCTAssertFalse(viewModel.shouldShowReplayButton)
    XCTAssertTrue(playbackService.playedResponses.isEmpty)
  }
}
