//  RouteSearchService.swift
//  LiveActivity_Practice

import Foundation

@Observable
final class RouteSearchService {

    private(set) var route: WalkingRoute?
    private let repository: WalkingRouteRepositoryProtocol

    init(repository: WalkingRouteRepositoryProtocol = WalkingRouteRepository()) {
        self.repository = repository
    }

    func search(from start: Coordinate, to destination: Coordinate) async throws {
        route = try await repository.makeRoute(from: start, to: destination)
    }

    func replace(with newRoute: WalkingRoute) {
        route = newRoute
    }

    func dismiss() {
        route = nil
    }
}
