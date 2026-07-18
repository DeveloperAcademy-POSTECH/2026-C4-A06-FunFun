//  WalkingActivityAttributes.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import ActivityKit
import Foundation

nonisolated struct WalkingActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        let remainingDistance: Int
        let estimatedArrival: Date
        let distanceToNextTurn: Int
        let maneuver: WalkingTurn
        let landmarkName: String?
        let instruction: String
        let isOffRoute: Bool
        let isApproachingTurn: Bool
        let showTimeInsteadOfDistance: Bool
    }

    let destinationName: String
}
