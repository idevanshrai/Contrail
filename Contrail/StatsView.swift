//
//  StatsView.swift
//  Contrail
//

import SwiftUI
import SwiftData

/// Flight history — session log with glassmorphic cards in the nocturnal theme.
struct StatsView: View {

    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    statsCards
                    historySection
                }
                .padding(40)
                .frame(maxWidth: 700)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(ContrailTheme.skyBlue)

            Text("History")
                .font(ContrailTheme.titleFont)
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text("Your flight log at a glance")
                .font(ContrailTheme.bodyFont)
                .foregroundStyle(ContrailTheme.mutedText)
        }
        .padding(.top, 20)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Flights",
                value: "\(sessions.count)",
                icon: "airplane",
                color: ContrailTheme.skyBlue
            )

            statCard(
                title: "Focus Time",
                value: totalFocusTime,
                icon: "timer",
                color: ContrailTheme.glowAmber
            )

            statCard(
                title: "Streak",
                value: "\(currentStreak)d",
                icon: "flame.fill",
                color: ContrailTheme.arrivedGreen
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text(title)
                .font(ContrailTheme.captionFont)
                .foregroundStyle(ContrailTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Flights")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ContrailTheme.mutedText)
                .textCase(.uppercase)
                .tracking(1)

            if sessions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 40))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.4))
            Text("No flights yet")
                .font(ContrailTheme.bodyFont)
                .foregroundStyle(ContrailTheme.mutedText)
            Text("Complete your first focus session to leave a contrail")
                .font(ContrailTheme.captionFont)
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassCard()
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 16) {
            // Route
            HStack(spacing: 8) {
                Text(session.departureCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)

                Image(systemName: "airplane")
                    .font(.system(size: 9))
                    .foregroundStyle(ContrailTheme.glowAmber)

                Text(session.destinationCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
            }
            .frame(width: 130, alignment: .leading)

            // Duration
            Text(FlightCalculator.formattedDuration(session.duration))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(ContrailTheme.skyBlue)

            Spacer()

            // Date
            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundStyle(ContrailTheme.mutedText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.3))
        .background(ContrailTheme.surfaceNavy.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Computed Stats

    private var totalFocusTime: String {
        let total = sessions.reduce(0.0) { $0 + $1.duration }
        return FlightCalculator.formattedDuration(total)
    }

    private var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)

        guard let mostRecent = sessionDays.first,
              calendar.dateComponents([.day], from: mostRecent, to: today).day! <= 1 else {
            return 0
        }

        var streak = 1
        for i in 1..<sessionDays.count {
            let diff = calendar.dateComponents([.day], from: sessionDays[i], to: sessionDays[i - 1]).day!
            if diff == 1 {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }
}

#Preview {
    StatsView()
        .modelContainer(for: Session.self, inMemory: true)
}
