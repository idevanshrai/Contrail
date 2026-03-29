//
//  Theme.swift
//  Contrail
//

import SwiftUI

/// Central design system for the Contrail app.
/// Near-black nocturnal palette inspired by FocusFlights — evoking night flight at altitude.
enum ContrailTheme {

    // MARK: - Brand Colors

    /// Near-black background — the void at cruise altitude
    static let darkNavy = Color(red: 0.04, green: 0.04, blue: 0.06)

    /// Slightly lighter surface for cards and sidebar
    static let surfaceNavy = Color(red: 0.08, green: 0.08, blue: 0.12)

    /// Sidebar background — a touch lighter than the main background
    static let sidebarBg = Color(red: 0.06, green: 0.06, blue: 0.09)

    /// Sky blue accent — high-altitude clarity
    static let skyBlue = Color(red: 0.40, green: 0.72, blue: 1.0)

    /// Contrail white — clean, bright text
    static let contrailWhite = Color(red: 0.95, green: 0.96, blue: 0.98)

    /// Warm amber glow for flight paths and highlights
    static let glowAmber = Color(red: 1.0, green: 0.76, blue: 0.28)

    /// Legacy alias
    static let sunsetGold = glowAmber

    /// Muted text color — soft grey
    static let mutedText = Color(red: 0.50, green: 0.52, blue: 0.58)

    /// Success / arrived green
    static let arrivedGreen = Color(red: 0.30, green: 0.82, blue: 0.55)

    // MARK: - Gradients

    /// Nocturnal background gradient
    static let backgroundGradient = LinearGradient(
        colors: [darkNavy, Color(red: 0.06, green: 0.06, blue: 0.10)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Sky gradient for the timer screen — deep nocturnal
    static let skyGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.04, blue: 0.08),
            Color(red: 0.08, green: 0.12, blue: 0.22),
            Color(red: 0.12, green: 0.20, blue: 0.36)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Amber glow gradient for contrail / flight path
    static let contrailGradient = LinearGradient(
        colors: [glowAmber.opacity(0.9), glowAmber.opacity(0.3)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Subtle ambient glow for active elements
    static let ambientGlow = RadialGradient(
        colors: [skyBlue.opacity(0.15), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 200
    )

    // MARK: - Typography

    /// Large title font
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Section heading
    static let headingFont = Font.system(size: 18, weight: .semibold, design: .rounded)

    /// Body text
    static let bodyFont = Font.system(size: 14, weight: .regular, design: .default)

    /// Caption / label
    static let captionFont = Font.system(size: 12, weight: .medium, design: .default)

    /// Countdown timer display — large ultralight
    static let countdownFont = Font.system(size: 72, weight: .ultraLight, design: .monospaced)

    /// Greeting city name — bold large
    static let cityFont = Font.system(size: 32, weight: .bold, design: .default)

    /// Greeting subtitle
    static let greetingFont = Font.system(size: 16, weight: .regular, design: .default)

    // MARK: - Helpers

    /// Time-of-day greeting string
    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning!"
        case 12..<17: return "Good afternoon!"
        case 17..<21: return "Good evening!"
        default:      return "Good night!"
        }
    }
}

// MARK: - Card Modifier (Glassmorphic)

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var borderOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.ultraThinMaterial.opacity(0.6))
            .background(ContrailTheme.surfaceNavy.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ContrailTheme.contrailWhite.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
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

extension View {
    func contrailCard() -> some View {
        modifier(CardModifier())
    }

    func glassCard(cornerRadius: CGFloat = 14, borderOpacity: Double = 0.08) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}
