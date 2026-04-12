import Foundation
import UIKit

@MainActor
enum AppEnvironment {
  static func makeRootViewModel() -> VoiceCaptureViewModel {
    let processInfo = ProcessInfo.processInfo
    let captureService = makeVoiceCaptureService(processInfo: processInfo)
    let transcriptionScenario = transcriptionScenario(from: processInfo)
    let backendConfiguration = makeBackendConfiguration(
      processInfo: processInfo,
      transcriptionScenario: transcriptionScenario
    )

    return VoiceCaptureViewModel(
      service: captureService,
      transcriptionClient: makeTranscriptionClient(
        processInfo: processInfo,
        transcriptionScenario: transcriptionScenario
      ),
      backendConfiguration: backendConfiguration
    )
  }

  static func makePreviewViewModel(scenario: AppCaptureScenario) -> VoiceCaptureViewModel {
    VoiceCaptureViewModel(
      service: MockVoiceCaptureService(scenario: scenario),
      transcriptionClient: MockBackendTranscriptionClient(scenario: .success),
      backendConfiguration: BackendConfiguration(
        baseURL: URL(string: "http://jarvis.local")!,
        bearerToken: "preview-token",
        deviceName: "Preview iPhone"
      )
    )
  }

  private static func makeVoiceCaptureService(
    processInfo: ProcessInfo
  ) -> any VoiceCaptureServiceProtocol {
    let isUITestRun = isUITestRun(processInfo)

    guard isUITestRun else {
      return VoiceCaptureService()
    }

    return MockVoiceCaptureService(scenario: scenario(from: processInfo))
  }

  private static func scenario(from processInfo: ProcessInfo) -> AppCaptureScenario {
    if let rawValue = processInfo.environment["JARVIS_CAPTURE_SCENARIO"] {
      if let scenario = AppCaptureScenario(rawValue: rawValue) {
        return scenario
      }
    }

    let arguments = processInfo.arguments
    if let index = arguments.firstIndex(of: "-jarvis-capture-scenario") {
      if index + 1 < arguments.count {
        if let scenario = AppCaptureScenario(rawValue: arguments[index + 1]) {
          return scenario
        }
      }
    }

    return .ready
  }

  private static func transcriptionScenario(
    from processInfo: ProcessInfo
  ) -> AppTranscriptionScenario {
    if let rawValue = processInfo.environment["JARVIS_TRANSCRIPTION_SCENARIO"] {
      if let scenario = AppTranscriptionScenario(rawValue: rawValue) {
        return scenario
      }
    }

    return .success
  }

  private static func makeTranscriptionClient(
    processInfo: ProcessInfo,
    transcriptionScenario: AppTranscriptionScenario
  ) -> any BackendTranscriptionClientProtocol {
    guard isUITestRun(processInfo) else {
      return BackendTranscriptionClient()
    }

    return MockBackendTranscriptionClient(scenario: transcriptionScenario)
  }

  private static func makeBackendConfiguration(
    processInfo: ProcessInfo,
    transcriptionScenario: AppTranscriptionScenario
  ) -> BackendConfiguration? {
    if isUITestRun(processInfo) {
      guard transcriptionScenario != .misconfigured else {
        return nil
      }

      return BackendConfiguration(
        baseURL: URL(string: "http://jarvis.local")!,
        bearerToken: "ui-test-token",
        deviceName: "UI Test iPhone"
      )
    }

    guard
      let baseURLString = processInfo.environment["JARVIS_CORE_API_BASE_URL"],
      let baseURL = URL(string: baseURLString),
      let bearerToken = nonEmptyTrimmed(processInfo.environment["JARVIS_API_BEARER_TOKEN"])
    else {
      return nil
    }

    let deviceName =
      nonEmptyTrimmed(processInfo.environment["JARVIS_DEVICE_NAME"])
      ?? UIDevice.current.name
    return BackendConfiguration(baseURL: baseURL, bearerToken: bearerToken, deviceName: deviceName)
  }

  private static func nonEmptyTrimmed(_ value: String?) -> String? {
    guard let value else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func isUITestRun(_ processInfo: ProcessInfo) -> Bool {
    processInfo.arguments.contains("-ui-testing")
      || processInfo.environment["JARVIS_CAPTURE_SCENARIO"] != nil
  }
}
