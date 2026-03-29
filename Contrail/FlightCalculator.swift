//
//  FlightCalculator.swift
//  Contrail
//

import Foundation

/// Computes great-circle distance and estimated flight duration between airports.
enum FlightCalculator {

    /// Average cruising speed in km/h
    private static let cruisingSpeedKmH: Double = 900.0

    /// Earth's mean radius in kilometres
    private static let earthRadiusKm: Double = 6_371.0

    // MARK: - Public API

    /// Returns the great-circle distance in kilometres between two airports
    /// using the Haversine formula.
    static func haversineDistance(from origin: Airport, to destination: Airport) -> Double {
        let lat1 = origin.latitude.radians
        let lon1 = origin.longitude.radians
        let lat2 = destination.latitude.radians
        let lon2 = destination.longitude.radians

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }

    /// Returns the estimated flight duration as a `TimeInterval` (seconds).
    static func flightDuration(from origin: Airport, to destination: Airport) -> TimeInterval {
        let distanceKm = haversineDistance(from: origin, to: destination)
        let hours = distanceKm / cruisingSpeedKmH
        return hours * 3600  // convert to seconds
    }

    /// Returns the maximum reachable distance in kilometres for a given focus duration.
    static func reachableRadiusKm(forDuration duration: TimeInterval) -> Double {
        let hours = duration / 3600.0
        return cruisingSpeedKmH * hours
    }

    /// Returns the great-circle distance in km between two coordinate pairs.
    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let la1 = lat1.radians, lo1 = lon1.radians
        let la2 = lat2.radians, lo2 = lon2.radians

        let dLat = la2 - la1
        let dLon = lo2 - lo1

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }

    /// Formats a `TimeInterval` into a human-readable string, e.g. "2h 35m".
    static func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formats a `TimeInterval` as a countdown string, e.g. "02:35:10".
    static func countdownString(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Helpers

private extension Double {
    /// Converts degrees to radians.
    var radians: Double {
        self * .pi / 180.0
    }
}
