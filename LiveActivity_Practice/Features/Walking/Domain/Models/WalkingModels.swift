//  WalkingModels.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import Foundation

nonisolated struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: Coordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

nonisolated enum WalkingTurn: String, Codable, Hashable, Sendable {
    case straight, left, right, slightLeft, slightRight, crosswalk, stairs, destination, unknown

    var symbolName: String {
        switch self {
        case .left, .slightLeft: "arrow.turn.up.left"
        case .right, .slightRight: "arrow.turn.up.right"
        case .destination: "flag.checkered"
        case .stairs: "figure.stairs"
        case .crosswalk: "figure.walk"
        default: "arrow.up"
        }
    }
    
    var instruction: String {
        switch self {
        case .straight: "앞으로 가세요"
        case .left, .slightLeft: "왼쪽길을 따라가세요"
        case .right, .slightRight: "오른쪽길을 따라가세요"
        case .stairs: "계단을 따라가세요"
        case .crosswalk: "교차로에서 건너세요"
        case .destination: "목적지 근처에 도착했어요"
        case .unknown: "알 수 없음"
        }
    }
}

nonisolated struct Landmark: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let category: String
    let coordinate: Coordinate
}

nonisolated struct PlaceSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: String
    let address: String
    let coordinate: Coordinate
}

nonisolated struct WalkingManeuver: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let coordinate: Coordinate
    let turn: WalkingTurn
    let description: String
    let routeIndex: Int
    var landmark: Landmark?

    var instruction: String {
        guard let landmark else { return description }
        return "\(landmark.name)을(를) 기준으로 \(turn.instruction)"
    }
}

nonisolated struct WalkingRoute: Codable, Hashable, Sendable {
    let totalDistance: Int
    let totalTime: Int
    let path: [Coordinate]
    var maneuvers: [WalkingManeuver]
}

nonisolated struct WalkingProgress: Hashable, Sendable {
    let remainingDistance: Int
    let distanceToNextManeuver: Int
    let nextManeuver: WalkingManeuver?
    let isOffRoute: Bool
    let isApproachingTurn: Bool
    let estimatedArrival: Date
}
