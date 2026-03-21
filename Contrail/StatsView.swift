//
//  StatsView.swift
//  Contrail
//

import SwiftUI
import SwiftData

/// Shows session history, total focus time, and current streak.
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
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(ContrailTheme.skyBlue)

            Text("Flight Log")
                .font(ContrailTheme.titleFont)
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text("Your focus journey at a glance")
                .font(ContrailTheme.bodyFont)
                .foregroundStyle(ContrailTheme.mutedText)
        }
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
                color: ContrailTheme.sunsetGold
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
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text(title)
                .font(ContrailTheme.captionFont)
                .foregroundStyle(ContrailTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .contrailCard()
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Flights")
                .font(ContrailTheme.headingFont)
                .foregroundStyle(ContrailTheme.contrailWhite)

            if sessions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 1) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 40))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.5))
            Text("No flights yet")
                .font(ContrailTheme.bodyFont)
                .foregroundStyle(ContrailTheme.mutedText)
            Text("Complete your first focus session to leave a contrail")
                .font(ContrailTheme.captionFont)
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .contrailCard()
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 16) {
            // Route
            HStack(spacing: 8) {
                Text(session.departureCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(ContrailTheme.mutedText)

                Text(session.destinationCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
            }
            .frame(width: 120, alignment: .leading)

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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(ContrailTheme.surfaceNavy)
    }

    // MARK: - Computed Stats

    private var totalFocusTime: String {
        let total = sessions.reduce(0.0) { $0 + $1.duration }
        return FlightCalculator.formattedDuration(total)
    }

    /// Calculates the current daily streak (consecutive days with at least one session).
    private var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Get unique session dates (start of day)
        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
            .sorted(by: >)

        // Check if the streak is active (today or yesterday has a session)
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
