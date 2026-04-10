import Foundation
import SwiftUI

@MainActor
final class VoiceCaptureViewModel: ObservableObject {
    @Published private(set) var permissionState: VoiceCapturePermissionState = .unknown
    @Published private(set) var captureState: VoiceCaptureState = .idle
    @Published private(set) var audioLevel: VoiceCaptureLevel = .silent

    private let service: any VoiceCaptureServiceProtocol
    private var hasPrepared = false

    init(service: any VoiceCaptureServiceProtocol) {
        self.service = service
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
            await service.stopCapture()
        case .stopping:
            break
        case .error(_):
            await resetAfterError()
        case .idle, .permissionNeeded, .ready:
            if permissionState != .granted {
                permissionState = await service.requestPermission()
                captureState = resolvedState(permission: permissionState, preferred: service.currentCaptureState())

                guard permissionState == .granted else {
                    return
                }
            }

            do {
                try await service.startCapture()
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Jarvis could not start microphone capture."
                captureState = .error(message)
            }
        }
    }

    var headline: String {
        switch captureState {
        case .idle, .ready:
            return "Capture System Ready"
        case .permissionNeeded:
            return "Microphone Access Required"
        case .recording:
            return "Listening For Input"
        case .stopping:
            return "Closing Audio Channel"
        case .error(_):
            return "Capture Fault Detected"
        }
    }

    var detailText: String {
        switch captureState {
        case .idle, .ready:
            return "Push to talk whenever you are ready. Audio stays on-device in this milestone."
        case .permissionNeeded:
            return "Grant microphone access to arm the voice capture surface on iPhone and simulator test fixtures."
        case .recording:
            return "Capture is live. Jarvis is only metering input right now and does not yet stream or transcribe."
        case .stopping:
            return "The microphone pipeline is winding down and returning the interface to standby."
        case let .error(message):
            return message
        }
    }

    var transcriptPanelTitle: String {
        captureState == .recording ? "Incoming Signal" : "Transcript Uplink"
    }

    var transcriptPlaceholder: String {
        switch captureState {
        case .recording:
            return "Voice data is being captured locally. Transcript rendering will connect here once the backend speech pipeline exists."
        case .permissionNeeded:
            return "Waiting for microphone permission before the capture channel can arm."
        case .error(_):
            return "Capture is unavailable. Reset the surface and try again."
        case .stopping:
            return "Capture session is shutting down cleanly."
        case .idle, .ready:
            return "Mission control is standing by for the first push-to-talk session."
        }
    }

    var primaryButtonTitle: String {
        switch captureState {
        case .permissionNeeded:
            return "Enable Microphone"
        case .recording:
            return "Stop Listening"
        case .stopping:
            return "Stopping"
        case .error(_):
            return "Reset Capture"
        case .idle, .ready:
            return "Start Listening"
        }
    }

    var primaryButtonSubtitle: String {
        switch captureState {
        case .permissionNeeded:
            return "Authorize capture"
        case .recording:
            return "End local input"
        case .stopping:
            return "Closing session"
        case .error(_):
            return "Return to standby"
        case .idle, .ready:
            return "Arm push-to-talk"
        }
    }

    var statusBannerText: String {
        switch captureState {
        case .recording:
            return "Live"
        case .error(_):
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
        captureState == .recording ? "Push-to-talk active" : "Push-to-talk armed"
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
        "Backend offline by design"
    }

    var inputLevelLabel: String {
        "\(Int(audioLevel.normalized * 100))%"
    }

    var isPrimaryButtonDisabled: Bool {
        captureState == .stopping
    }

    private func refreshFromService() async {
        permissionState = await service.currentPermissionState()
        let preferredState = service.currentCaptureState()
        captureState = resolvedState(permission: permissionState, preferred: preferredState)
    }

    private func resetAfterError() async {
        await service.stopCapture()
        await refreshFromService()
    }

    private func handle(event: VoiceCaptureEvent) {
        switch event {
        case let .permissionChanged(permission):
            permissionState = permission
        case let .stateChanged(state):
            captureState = state
        case let .levelChanged(level):
            audioLevel = level
        }
    }

    private func resolvedState(
        permission: VoiceCapturePermissionState,
        preferred: VoiceCaptureState
    ) -> VoiceCaptureState {
        switch preferred {
        case .recording, .stopping, .error(_):
            return preferred
        case .idle, .ready, .permissionNeeded:
            return permission == .granted ? .ready : .permissionNeeded
        }
    }
}
