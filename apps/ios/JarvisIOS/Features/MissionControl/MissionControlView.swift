import SwiftUI

struct MissionControlView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var viewModel: VoiceCaptureViewModel

  init(viewModel: VoiceCaptureViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    ZStack {
      JarvisBackground()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 18) {
          headerPanel
          capturePanel
          transcriptPanel
          telemetryPanel
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
    }
    .preferredColorScheme(.dark)
    .task {
      await viewModel.prepare()
    }
  }

  private var headerPanel: some View {
    HUDPanel(title: "Identity") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 6) {
            Text("JARVIS")
              .font(.system(size: 34, weight: .black, design: .rounded))
              .foregroundStyle(JarvisTheme.textPrimary)
              .kerning(1.6)

            Text("Mission Control Interface")
              .font(.system(.subheadline, design: .monospaced).weight(.medium))
              .foregroundStyle(JarvisTheme.textSecondary)
          }

          Spacer(minLength: 16)

          StatusChip(title: viewModel.statusBannerText, tone: statusTone)
        }

        Text(
          "Current frontend milestone: finalized clip capture, Jarvis-style command response, "
            + "local playback, and mission-control rendering."
        )
        .font(.system(.body, design: .rounded))
        .foregroundStyle(JarvisTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var capturePanel: some View {
    HUDPanel(title: "Voice Capture") {
      VStack(spacing: 18) {
        JarvisOrb(
          audioLevel: viewModel.audioLevel.normalized,
          isRecording: viewModel.captureState == .recording,
          reduceMotion: reduceMotion
        )

        VStack(spacing: 8) {
          Text(viewModel.headline)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(JarvisTheme.textPrimary)
            .accessibilityIdentifier("mission-headline")

          Text(viewModel.detailText)
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(JarvisTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Button(action: viewModel.handlePrimaryAction) {
          VStack(spacing: 4) {
            Text(viewModel.primaryButtonTitle)
              .font(.system(.headline, design: .rounded).weight(.bold))
            Text(viewModel.primaryButtonSubtitle)
              .font(.system(.caption, design: .monospaced).weight(.semibold))
              .kerning(1.2)
              .foregroundStyle(JarvisTheme.textSecondary)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(JarvisPrimaryButtonStyle(tone: tone(for: viewModel.captureState)))
        .disabled(viewModel.isPrimaryButtonDisabled)
        .accessibilityIdentifier("primary-capture-button")
      }
    }
  }

  private var transcriptPanel: some View {
    HUDPanel(title: viewModel.responsePanelTitle) {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Summary")
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .foregroundStyle(JarvisTheme.textSecondary)
            .kerning(1.2)

          Text(viewModel.responseSummaryText)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(JarvisTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let spokenResponseText = viewModel.spokenResponseText {
          VStack(alignment: .leading, spacing: 6) {
            Text("Spoken Response")
              .font(.system(.caption, design: .monospaced).weight(.semibold))
              .foregroundStyle(JarvisTheme.textSecondary)
              .kerning(1.2)

            Text(spokenResponseText)
              .font(.system(.body, design: .rounded))
              .foregroundStyle(JarvisTheme.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        if viewModel.shouldShowTranscript {
          VStack(alignment: .leading, spacing: 6) {
            Text("Transcript")
              .font(.system(.caption, design: .monospaced).weight(.semibold))
              .foregroundStyle(JarvisTheme.textSecondary)
              .kerning(1.2)

            Text(viewModel.transcriptText)
              .font(.system(.body, design: .rounded))
              .foregroundStyle(JarvisTheme.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        if viewModel.shouldShowReplayButton {
          Button(action: viewModel.handleReplayAction) {
            Text(viewModel.replayButtonTitle)
              .font(.system(.subheadline, design: .rounded).weight(.bold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(JarvisPrimaryButtonStyle(tone: JarvisTheme.accentMuted))
          .accessibilityIdentifier("replay-response-button")
        }
      }
    }
  }

  private var telemetryPanel: some View {
    HUDPanel(title: "System Telemetry") {
      VStack(spacing: 12) {
        HStack(spacing: 12) {
          MetricCard(label: "Capture Mode", value: viewModel.captureModeLabel)
          MetricCard(label: "Input Level", value: viewModel.inputLevelLabel)
        }

        HStack(spacing: 12) {
          MetricCard(label: "Microphone", value: viewModel.permissionLabel)
          MetricCard(label: "Voice Link", value: viewModel.networkLabel)
        }

        HStack(spacing: 12) {
          MetricCard(label: "Playback", value: viewModel.playbackLabel)
        }
      }
    }
  }

  private func tone(for state: VoiceCaptureState) -> Color {
    switch state {
    case .recording:
      return JarvisTheme.accentStrong
    case .permissionNeeded:
      return JarvisTheme.warning
    case .error:
      return JarvisTheme.error
    case .stopping:
      return JarvisTheme.warning
    case .idle, .ready:
      return JarvisTheme.accent
    }
  }

  private var statusTone: Color {
    if viewModel.interactionState.isInFlight {
      return JarvisTheme.warning
    }

    if case .failed = viewModel.interactionState {
      return JarvisTheme.error
    }

    return tone(for: viewModel.captureState)
  }
}

private struct JarvisPrimaryButtonStyle: ButtonStyle {
  let tone: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .background(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(tone.opacity(configuration.isPressed ? 0.18 : 0.12))
          .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
              .stroke(tone.opacity(configuration.isPressed ? 0.95 : 0.6), lineWidth: 1.2)
          )
      )
      .foregroundStyle(JarvisTheme.textPrimary)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .shadow(color: tone.opacity(0.22), radius: 10, y: 4)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

#Preview("Ready") {
  MissionControlView(viewModel: AppEnvironment.makePreviewViewModel(scenario: .ready))
}

#Preview("Recording") {
  MissionControlView(viewModel: AppEnvironment.makePreviewViewModel(scenario: .recording))
}

#Preview("Permission Needed") {
  MissionControlView(viewModel: AppEnvironment.makePreviewViewModel(scenario: .permissionNeeded))
}
