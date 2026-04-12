import SwiftUI

enum JarvisTheme {
  static let backgroundTop = Color(red: 0.02, green: 0.05, blue: 0.12)
  static let backgroundBottom = Color(red: 0.0, green: 0.01, blue: 0.04)
  static let panelFill = Color(red: 0.03, green: 0.08, blue: 0.16).opacity(0.78)
  static let panelStroke = Color(red: 0.29, green: 0.8, blue: 0.98).opacity(0.35)
  static let accent = Color(red: 0.22, green: 0.86, blue: 1.0)
  static let accentStrong = Color(red: 0.46, green: 0.96, blue: 1.0)
  static let accentMuted = Color(red: 0.33, green: 0.64, blue: 0.82)
  static let warning = Color(red: 0.98, green: 0.76, blue: 0.29)
  static let error = Color(red: 0.99, green: 0.43, blue: 0.46)
  static let textPrimary = Color(red: 0.9, green: 0.98, blue: 1.0)
  static let textSecondary = Color(red: 0.61, green: 0.82, blue: 0.92)
  static let grid = Color(red: 0.26, green: 0.68, blue: 0.86).opacity(0.12)
  static let shadow = Color(red: 0.04, green: 0.68, blue: 0.84).opacity(0.32)

  static let appGradient = LinearGradient(
    colors: [backgroundTop, backgroundBottom],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let orbGradient = RadialGradient(
    colors: [accentStrong.opacity(0.95), accent.opacity(0.34), .clear],
    center: .center,
    startRadius: 8,
    endRadius: 150
  )

  static let panelGradient = LinearGradient(
    colors: [accentStrong.opacity(0.24), accent.opacity(0.02)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}
