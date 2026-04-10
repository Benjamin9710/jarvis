import SwiftUI

struct JarvisBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                JarvisTheme.appGradient
                    .ignoresSafeArea()

                Circle()
                    .fill(JarvisTheme.accent.opacity(0.09))
                    .frame(width: geometry.size.width * 0.95)
                    .blur(radius: 40)
                    .offset(x: geometry.size.width * 0.24, y: -geometry.size.height * 0.25)

                Circle()
                    .fill(JarvisTheme.accentStrong.opacity(0.08))
                    .frame(width: geometry.size.width * 0.62)
                    .blur(radius: 30)
                    .offset(x: -geometry.size.width * 0.3, y: geometry.size.height * 0.18)

                Path { path in
                    let spacing: CGFloat = 36

                    for x in stride(from: 0, through: geometry.size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }

                    for y in stride(from: 0, through: geometry.size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(JarvisTheme.grid, style: StrokeStyle(lineWidth: 0.6, dash: [2, 8]))
            }
        }
    }
}

struct HUDPanel<Content: View>: View {
    private let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(title.uppercased())
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .kerning(2.2)
                    .foregroundStyle(JarvisTheme.textSecondary)

                Rectangle()
                    .fill(JarvisTheme.accent.opacity(0.5))
                    .frame(height: 1)
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(JarvisTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(JarvisTheme.panelStroke, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(JarvisTheme.panelGradient)
                )
        )
        .shadow(color: JarvisTheme.shadow, radius: 16, y: 10)
    }
}

struct StatusChip: View {
    let title: String
    let tone: Color

    var body: some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .kerning(1.6)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.opacity(0.18))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(tone.opacity(0.55), lineWidth: 1)
                    )
            )
            .foregroundStyle(tone)
    }
}

struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .kerning(1.4)
                .foregroundStyle(JarvisTheme.textSecondary)

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(JarvisTheme.panelStroke.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

struct JarvisOrb: View {
    let audioLevel: Double
    let isRecording: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.02))
                .frame(width: 286, height: 286)
                .overlay(
                    Circle()
                        .stroke(JarvisTheme.panelStroke.opacity(0.65), lineWidth: 1)
                )

            ForEach([1.0, 1.18, 1.36], id: \.self) { scale in
                Circle()
                    .trim(from: 0.14, to: 0.86)
                    .stroke(
                        AngularGradient(
                            colors: [
                                JarvisTheme.accent.opacity(isRecording ? 0.9 : 0.35),
                                JarvisTheme.accentStrong.opacity(isRecording ? 0.3 : 0.12),
                                .clear
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 206, height: 206)
                    .scaleEffect(scale + (isRecording ? audioLevel * 0.05 : 0))
                    .rotationEffect(.degrees(isRecording ? audioLevel * 70 : scale * 48))
            }

            Circle()
                .fill(JarvisTheme.orbGradient)
                .frame(width: 172, height: 172)
                .blur(radius: isRecording ? 3 : 7)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            JarvisTheme.accentStrong.opacity(0.95),
                            JarvisTheme.accent.opacity(0.52),
                            JarvisTheme.backgroundBottom
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 88
                    )
                )
                .frame(
                    width: 90 + audioLevel * 48,
                    height: 90 + audioLevel * 48
                )

            Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: 56, weight: .light, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(JarvisTheme.textPrimary)
        }
        .frame(width: 300, height: 300)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: audioLevel)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: isRecording)
        .accessibilityHidden(true)
    }
}
