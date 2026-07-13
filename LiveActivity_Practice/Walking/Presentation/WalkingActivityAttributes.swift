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
    }

    let destinationName: String
}
