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
        
        /// 분기점 타입
        let maneuver: WalkingTurn
        let landmarkName: String?
        let instruction: String
        let isOffRoute: Bool
        let isApproachingTurn: Bool
        let showTimeInsteadOfDistance: Bool

        /// 설정에 따라 거리(m) 또는 시간(분)으로 표시할 문자열
        var distanceToNextTurnText: String {
            if showTimeInsteadOfDistance {
                let minutes = max(1, Int(ceil(Double(distanceToNextTurn) / 75.0)))
                return "\(minutes)분"
            }
            return "\(distanceToNextTurn)m"
        }
    }

    let destinationName: String
}
