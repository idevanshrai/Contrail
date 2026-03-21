//
//  Session.swift
//  Contrail
//

import Foundation
import SwiftData

/// A completed focus session persisted via SwiftData.
@Model
final class Session {
    var departureCode: String
    var departureName: String
    var destinationCode: String
    var destinationName: String
    var duration: TimeInterval      // seconds
    var date: Date

    init(
        departureCode: String,
        departureName: String,
        destinationCode: String,
        destinationName: String,
        duration: TimeInterval,
        date: Date = .now
    ) {
        self.departureCode = departureCode
        self.departureName = departureName
        self.destinationCode = destinationCode
        self.destinationName = destinationName
        self.duration = duration
        self.date = date
    }
}
