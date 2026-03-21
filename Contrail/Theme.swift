//
//  Theme.swift
//  Contrail
//

import SwiftUI

/// Central design system for the Contrail app.
/// Dark navy + sky blue + white palette — evoking contrails against a twilight sky.
enum ContrailTheme {

    // MARK: - Brand Colors

    /// Deep navy background — the night sky at altitude
    static let darkNavy = Color(red: 0.06, green: 0.09, blue: 0.16)

    /// Slightly lighter navy for cards and surfaces
    static let surfaceNavy = Color(red: 0.09, green: 0.13, blue: 0.22)

    /// Sky blue accent — clear high-altitude sky
    static let skyBlue = Color(red: 0.35, green: 0.68, blue: 0.95)

    /// Contrail white — clean, bright streaks
    static let contrailWhite = Color(red: 0.95, green: 0.96, blue: 0.98)

    /// Warm gold for highlights and streaks
    static let sunsetGold = Color(red: 0.96, green: 0.78, blue: 0.35)

    /// Muted text color
    static let mutedText = Color(red: 0.55, green: 0.60, blue: 0.70)

    /// Success green
    static let arrivedGreen = Color(red: 0.30, green: 0.78, blue: 0.55)

    // MARK: - Gradients

    /// Background gradient: deep navy to slightly lighter navy
    static let backgroundGradient = LinearGradient(
        colors: [darkNavy, Color(red: 0.08, green: 0.12, blue: 0.20)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Sky gradient for the timer screen
    static let skyGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.15, blue: 0.28),
            Color(red: 0.15, green: 0.25, blue: 0.45),
            Color(red: 0.25, green: 0.45, blue: 0.70)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Contrail streak gradient
    static let contrailGradient = LinearGradient(
        colors: [contrailWhite.opacity(0.8), contrailWhite.opacity(0.2)],
        startPoint: .leading,
        endPoint: .trailing
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

    /// Countdown timer display
    static let countdownFont = Font.system(size: 64, weight: .ultraLight, design: .monospaced)

    // MARK: - View Modifiers

    /// Standard card style with subtle border and shadow
    static func cardStyle() -> some ViewModifier {
        CardModifier()
    }
}

// MARK: - Card Modifier

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
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

extension View {
    func contrailCard() -> some View {
        modifier(CardModifier())
    }
}
