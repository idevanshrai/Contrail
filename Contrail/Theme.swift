//
//  Theme.swift
//  Contrail
//

import SwiftUI
import AppKit

/// Premium design system for Contrail.
/// Deep nocturnal palette with warm amber accents — night flight at 35,000 ft.
enum ContrailTheme {

    // MARK: - Brand Colors

    /// Near-black background — the void at cruise altitude
    static let darkNavy = Color(red: 0.04, green: 0.04, blue: 0.06)

    /// Card/surface color — slightly lifted
    static let surfaceNavy = Color(red: 0.09, green: 0.09, blue: 0.13)

    /// Sidebar background
    static let sidebarBg = Color(red: 0.06, green: 0.06, blue: 0.09)

    /// Primary accent — warm amber glow (contrails at sunset)
    static let glowAmber = Color(red: 1.0, green: 0.76, blue: 0.28)

    /// Secondary accent — high-altitude sky blue
    static let skyBlue = Color(red: 0.40, green: 0.72, blue: 1.0)

    /// Primary text — clean white
    static let contrailWhite = Color(red: 0.95, green: 0.96, blue: 0.98)

    /// Muted/secondary text
    static let mutedText = Color(red: 0.50, green: 0.52, blue: 0.58)

    /// Success / arrived
    static let arrivedGreen = Color(red: 0.30, green: 0.82, blue: 0.55)

    /// Danger / destructive
    static let dangerRed = Color(red: 0.95, green: 0.30, blue: 0.30)

    /// Card background — solid dark for maximum readability
    static let cardBlack = Color(red: 0.07, green: 0.07, blue: 0.10)

    // MARK: - Gradients

    static let backgroundGradient = LinearGradient(
        colors: [darkNavy, Color(red: 0.06, green: 0.06, blue: 0.10)],
        startPoint: .top, endPoint: .bottom
    )

    static let skyGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.04, blue: 0.08),
            Color(red: 0.08, green: 0.12, blue: 0.22),
            Color(red: 0.12, green: 0.20, blue: 0.36)
        ],
        startPoint: .top, endPoint: .bottom
    )

    static let contrailGradient = LinearGradient(
        colors: [glowAmber.opacity(0.9), glowAmber.opacity(0.3)],
        startPoint: .leading, endPoint: .trailing
    )

    static let ambientGlow = RadialGradient(
        colors: [skyBlue.opacity(0.15), .clear],
        center: .center, startRadius: 0, endRadius: 200
    )

    // MARK: - Premium Typography (SF Pro Rounded)

    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headingFont = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 14, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 12, weight: .medium, design: .rounded)

    /// Large countdown — ultra-light monospaced for precision feel
    static let countdownFont = Font.system(size: 64, weight: .thin, design: .monospaced)

    /// IATA codes — bold monospaced for that airport-board look
    static let iataFont = Font.system(size: 20, weight: .black, design: .monospaced)

    /// City names — medium rounded for warmth
    static let cityFont = Font.system(size: 32, weight: .bold, design: .rounded)

    /// Greeting — light and airy
    static let greetingFont = Font.system(size: 16, weight: .regular, design: .rounded)

    /// Labels — small caps feel
    static let labelFont = Font.system(size: 10, weight: .semibold, design: .rounded)

    // MARK: - Helpers

    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    /// Trigger macOS haptic feedback
    static func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

// MARK: - View Modifiers

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var borderOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(ContrailTheme.cardBlack.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ContrailTheme.contrailWhite.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(ContrailTheme.surfaceNavy)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

struct HoverGlowModifier: ViewModifier {
    var glowColor: Color = ContrailTheme.skyBlue
    var radius: CGFloat = 8
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .shadow(color: isHovered ? glowColor.opacity(0.35) : .clear, radius: radius)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering { ContrailTheme.haptic(.alignment) }
            }
    }
}

extension View {
    func contrailCard() -> some View { modifier(CardModifier()) }
    func glassCard(cornerRadius: CGFloat = 14, borderOpacity: Double = 0.08) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
    func hoverGlow(_ color: Color = ContrailTheme.skyBlue, radius: CGFloat = 8) -> some View {
        modifier(HoverGlowModifier(glowColor: color, radius: radius))
    }
}
