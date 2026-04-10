import Foundation

@MainActor
enum AppEnvironment {
    static func makeRootViewModel() -> VoiceCaptureViewModel {
        VoiceCaptureViewModel(service: makeVoiceCaptureService())
    }

    static func makePreviewViewModel(scenario: AppCaptureScenario) -> VoiceCaptureViewModel {
        VoiceCaptureViewModel(service: MockVoiceCaptureService(scenario: scenario))
    }

    private static func makeVoiceCaptureService() -> any VoiceCaptureServiceProtocol {
        let processInfo = ProcessInfo.processInfo
        let isUITestRun = processInfo.arguments.contains("-ui-testing")
            || processInfo.environment["JARVIS_CAPTURE_SCENARIO"] != nil

        guard isUITestRun else {
            return VoiceCaptureService()
        }

        return MockVoiceCaptureService(scenario: scenario(from: processInfo))
    }

    private static func scenario(from processInfo: ProcessInfo) -> AppCaptureScenario {
        if let rawValue = processInfo.environment["JARVIS_CAPTURE_SCENARIO"],
           let scenario = AppCaptureScenario(rawValue: rawValue) {
            return scenario
        }

        let arguments = processInfo.arguments
        if let index = arguments.firstIndex(of: "-jarvis-capture-scenario"),
           index + 1 < arguments.count,
           let scenario = AppCaptureScenario(rawValue: arguments[index + 1]) {
            return scenario
        }

        return .ready
    }
}
