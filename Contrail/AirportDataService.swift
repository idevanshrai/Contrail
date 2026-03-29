//
//  AirportDataService.swift
//  Contrail
//

import Combine
import Foundation

/// Loads, parses, and searches the bundled OurAirports CSV file.
@MainActor
final class AirportDataService: ObservableObject {

    @Published private(set) var airports: [Airport] = []

    /// Allowed airport types — excludes heliports, seaplane bases, closed airports, etc.
    private static let allowedTypes: Set<String> = ["large_airport", "medium_airport"]

    init() {
        loadAirports()
    }

    // MARK: - Lookup

    /// Returns the airport matching the given IATA code, or nil.
    func airportByIATA(_ code: String) -> Airport? {
        airports.first { $0.iataCode.uppercased() == code.uppercased() }
    }

    // MARK: - Reachability

    /// Returns airports reachable from `origin` within `maxDuration` seconds,
    /// sorted by flight duration ascending.
    func airportsReachable(from origin: Airport, within maxDuration: TimeInterval) -> [Airport] {
        let maxRadiusKm = FlightCalculator.reachableRadiusKm(forDuration: maxDuration)

        return airports.compactMap { airport in
            guard airport.id != origin.id else { return nil as (Airport, Double)? }
            let dist = FlightCalculator.haversineDistance(
                lat1: origin.latitude, lon1: origin.longitude,
                lat2: airport.latitude, lon2: airport.longitude
            )
            guard dist <= maxRadiusKm, dist > 50 else { return nil }  // skip very close airports
            return (airport, dist)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    // MARK: - Search

    /// Returns airports matching the query against IATA code, name, municipality, or country.
    func search(query: String) -> [Airport] {
        guard !query.isEmpty else { return airports }

        let lowered = query.lowercased()
        return airports.filter { airport in
            airport.iataCode.lowercased().contains(lowered)
            || airport.name.lowercased().contains(lowered)
            || airport.municipality.lowercased().contains(lowered)
            || airport.country.lowercased().contains(lowered)
        }
    }

    // MARK: - CSV Parsing

    private func loadAirports() {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "csv") else {
            print("[AirportDataService] airports.csv not found in bundle.")
            return
        }

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            print("[AirportDataService] Failed to read airports.csv.")
            return
        }

        var results: [Airport] = []
        let lines = content.components(separatedBy: .newlines)

        // Skip the header row (index 0)
        for i in 1..<lines.count {
            let line = lines[i]
            guard !line.isEmpty else { continue }

            let columns = parseCSVLine(line)
            guard columns.count >= 14 else { continue }

            // Column indices (0-based):
            //  0: id, 2: type, 3: name, 4: latitude_deg, 5: longitude_deg
            //  8: iso_country, 10: municipality, 13: iata_code
            let type = unquote(columns[2])
            let iataCode = unquote(columns[13])

            // Filter: must have an IATA code and be a large/medium airport
            guard !iataCode.isEmpty, Self.allowedTypes.contains(type) else { continue }

            guard let id = Int(unquote(columns[0])),
                  let lat = Double(unquote(columns[4])),
                  let lon = Double(unquote(columns[5])) else { continue }

            let airport = Airport(
                id: id,
                name: unquote(columns[3]),
                iataCode: iataCode,
                latitude: lat,
                longitude: lon,
                country: unquote(columns[8]),
                municipality: unquote(columns[10])
            )

            results.append(airport)
        }

        // Sort alphabetically by IATA code
        results.sort { $0.iataCode < $1.iataCode }
        self.airports = results
    }

    // MARK: - CSV Helpers

    /// Parses a single CSV line respecting quoted fields (handles commas inside quotes).
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current) // last field
        return columns
    }

    /// Strips surrounding double-quotes from a CSV field value.
    private func unquote(_ value: String) -> String {
        var s = value
        if s.hasPrefix("\"") { s.removeFirst() }
        if s.hasSuffix("\"") { s.removeLast() }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
