import XCTest
@testable import JarvisIOS

@MainActor
final class VoiceCaptureViewModelTests: XCTestCase {
    func testPrepareMapsUnknownPermissionToPermissionNeeded() async {
        let service = MockVoiceCaptureService(permissionState: .unknown, initialState: .idle)
        let viewModel = VoiceCaptureViewModel(service: service)

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
        let viewModel = VoiceCaptureViewModel(service: service)

        await viewModel.prepare()
        await viewModel.handlePrimaryActionAsync()

        XCTAssertEqual(viewModel.permissionState, .granted)
        XCTAssertEqual(viewModel.captureState, .recording)
    }

    func testStoppingCaptureReturnsViewModelToReadyState() async {
        let service = MockVoiceCaptureService(permissionState: .granted, initialState: .ready)
        let viewModel = VoiceCaptureViewModel(service: service)

        await viewModel.prepare()
        await viewModel.handlePrimaryActionAsync()
        XCTAssertEqual(viewModel.captureState, .recording)

        await viewModel.handlePrimaryActionAsync()
        XCTAssertEqual(viewModel.captureState, .ready)
        XCTAssertEqual(viewModel.audioLevel, .silent)
    }

    func testPrimaryActionSurfacesServiceError() async {
        let service = MockVoiceCaptureService(
            permissionState: .granted,
            initialState: .ready,
            startError: "Input node failed to initialize."
        )
        let viewModel = VoiceCaptureViewModel(service: service)

        await viewModel.prepare()
        await viewModel.handlePrimaryActionAsync()

        XCTAssertEqual(viewModel.captureState, .error("Input node failed to initialize."))
        XCTAssertEqual(viewModel.headline, "Capture Fault Detected")
    }
}
