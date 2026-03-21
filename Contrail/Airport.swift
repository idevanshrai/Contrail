//
//  Airport.swift
//  Contrail
//

import Foundation

/// A lightweight model representing an airport parsed from the OurAirports CSV.
struct Airport: Identifiable, Hashable {
    let id: Int
    let name: String
    let iataCode: String
    let latitude: Double
    let longitude: Double
    let country: String       // ISO 3166-1 alpha-2
    let municipality: String

    /// Display string used in the airport picker, e.g. "JFK — John F Kennedy Intl, US"
    var displayName: String {
        "\(iataCode) — \(name), \(country)"
    }

    /// Shorter label for compact UI elements
    var shortLabel: String {
        "\(iataCode) · \(municipality.isEmpty ? country : municipality)"
    }
}
