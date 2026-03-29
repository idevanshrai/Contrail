//
//  TrendsView.swift
//  Contrail
//

import SwiftUI
import SwiftData
import Charts

/// Weekly focus trends and analytics.
struct TrendsView: View {

    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(ContrailTheme.skyBlue)
                        Text("Trends")
                            .font(ContrailTheme.titleFont)
                            .foregroundStyle(ContrailTheme.contrailWhite)
                        Text("Your focus patterns over time")
                            .font(ContrailTheme.bodyFont)
                            .foregroundStyle(ContrailTheme.mutedText)
                    }
                    .padding(.top, 20)

                    // Weekly chart
                    weeklyChart

                    // Summary stats
                    HStack(spacing: 16) {
                        summaryCard(
                            title: "This Week",
                            value: formattedDuration(thisWeekTotal),
                            icon: "calendar",
                            color: ContrailTheme.skyBlue
                        )
                        summaryCard(
                            title: "Total Distance",
                            value: totalDistanceFormatted,
                            icon: "arrow.triangle.swap",
                            color: ContrailTheme.glowAmber
                        )
                        summaryCard(
                            title: "Avg Session",
                            value: formattedDuration(averageSession),
                            icon: "timer",
                            color: ContrailTheme.arrivedGreen
                        )
                    }

                    // Top routes
                    topRoutesSection
                }
                .padding(40)
                .frame(maxWidth: 700)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Focus Time")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ContrailTheme.mutedText)
                .textCase(.uppercase)
                .tracking(1)

            Chart(weeklyData, id: \.day) { entry in
                BarMark(
                    x: .value("Day", entry.day),
                    y: .value("Minutes", entry.minutes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [ContrailTheme.skyBlue, ContrailTheme.skyBlue.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(ContrailTheme.mutedText)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(ContrailTheme.contrailWhite.opacity(0.06))
                    AxisValueLabel()
                        .foregroundStyle(ContrailTheme.mutedText)
                }
            }
            .frame(height: 180)
            .padding(.top, 8)
        }
        .contrailCard()
    }

    // MARK: - Summary Cards

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text(title)
                .font(ContrailTheme.captionFont)
                .foregroundStyle(ContrailTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .contrailCard()
    }

    // MARK: - Top Routes

    private var topRoutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequent Routes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ContrailTheme.mutedText)
                .textCase(.uppercase)
                .tracking(1)

            if topRoutes.isEmpty {
                Text("Complete some flights to see your top routes")
                    .font(ContrailTheme.bodyFont)
                    .foregroundStyle(ContrailTheme.mutedText.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                VStack(spacing: 0) {
                    ForEach(topRoutes, id: \.route) { entry in
                        HStack(spacing: 12) {
                            Text(entry.route)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(ContrailTheme.contrailWhite)

                            Spacer()

                            Text("\(entry.count) flight\(entry.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ContrailTheme.skyBlue)
                        }
                        .padding(.vertical, 10)

                        if entry.route != topRoutes.last?.route {
                            Divider()
                                .background(ContrailTheme.contrailWhite.opacity(0.06))
                        }
                    }
                }
            }
        }
        .contrailCard()
    }

    // MARK: - Computed Data

    private var weeklyData: [(day: String, minutes: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let weekday = calendar.component(.weekday, from: today)
        // Monday = 1 in ISO, but Calendar uses Sunday = 1
        let mondayOffset = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) else {
            return dayNames.map { ($0, 0.0) }
        }

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else {
                return (dayNames[offset], 0.0)
            }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayTotal = sessions.filter { $0.date >= day && $0.date < nextDay }
                .reduce(0.0) { $0 + $1.duration }
            return (dayNames[offset], dayTotal / 60.0) // minutes
        }
    }

    private var thisWeekTotal: TimeInterval {
        weeklyData.reduce(0.0) { $0 + $1.minutes } * 60 // back to seconds
    }

    private var averageSession: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0.0) { $0 + $1.duration } / Double(sessions.count)
    }

    private var totalDistanceFormatted: String {
        // Rough estimate: each session's duration * cruise speed
        let totalKm = sessions.reduce(0.0) { total, session in
            total + FlightCalculator.reachableRadiusKm(forDuration: session.duration)
        }
        if totalKm >= 1000 {
            return String(format: "%.0fk km", totalKm / 1000)
        }
        return String(format: "%.0f km", totalKm)
    }

    private var topRoutes: [(route: String, count: Int)] {
        var counts: [String: Int] = [:]
        for session in sessions {
            let route = "\(session.departureCode) → \(session.destinationCode)"
            counts[route, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { (route: $0.key, count: $0.value) }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        FlightCalculator.formattedDuration(seconds)
    }
}

#Preview {
    TrendsView()
        .modelContainer(for: Session.self, inMemory: true)
}
