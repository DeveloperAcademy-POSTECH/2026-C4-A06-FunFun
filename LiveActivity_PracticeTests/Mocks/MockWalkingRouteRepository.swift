//  MockWalkingRouteRepository.swift
//  LiveActivity_PracticeTests

import Foundation
@testable import LiveActivity_Practice

final class MockWalkingRouteRepository: WalkingRouteRepositoryProtocol, @unchecked Sendable {
    var makeRouteHandler: ((Coordinate, Coordinate) async throws -> WalkingRoute)?

    func makeRoute(from start: Coordinate, to end: Coordinate) async throws -> WalkingRoute {
        guard let handler = makeRouteHandler else {
            return WalkingRoute(
                totalDistance: 1000,
                totalTime: 600,
                path: [start, end],
                maneuvers: []
            )
        }
        return try await handler(start, end)
    }
}
