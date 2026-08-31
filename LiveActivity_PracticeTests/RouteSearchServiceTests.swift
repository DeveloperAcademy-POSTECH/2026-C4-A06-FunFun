//  RouteSearchServiceTests.swift
//  LiveActivity_PracticeTests

import Testing
@testable import LiveActivity_Practice

@Suite("RouteSearchService 경로 탐색")
struct RouteSearchServiceTests {

    private static let start = Coordinate(latitude: 37.5000, longitude: 127.0000)
    private static let end = Coordinate(latitude: 37.5050, longitude: 127.0000)

    @Test("검색 성공 시 route가 저장된다")
    func search_success_storesRoute() async throws {
        let mockRepo = MockWalkingRouteRepository()
        let service = RouteSearchService(repository: mockRepo)

        try await service.search(from: Self.start, to: Self.end)

        #expect(service.route != nil)
        #expect(service.route?.path.count == 2)
    }

    @Test("검색 실패 시 route가 nil이다")
    func search_failure_routeIsNil() async {
        let mockRepo = MockWalkingRouteRepository()
        mockRepo.makeRouteHandler = { _, _ in
            throw TMAPError.noWalkingRoute
        }
        let service = RouteSearchService(repository: mockRepo)

        do {
            try await service.search(from: Self.start, to: Self.end)
            Issue.record("에러가 발생해야 한다")
        } catch {
            #expect(service.route == nil)
        }
    }

    @Test("dismiss 후 route가 nil이다")
    func dismiss_clearsRoute() async throws {
        let mockRepo = MockWalkingRouteRepository()
        let service = RouteSearchService(repository: mockRepo)

        try await service.search(from: Self.start, to: Self.end)
        #expect(service.route != nil)

        service.dismiss()

        #expect(service.route == nil)
    }

    @Test("replace로 route를 교체할 수 있다")
    func replace_swapsRoute() async throws {
        let mockRepo = MockWalkingRouteRepository()
        let service = RouteSearchService(repository: mockRepo)

        try await service.search(from: Self.start, to: Self.end)
        let original = service.route

        let newRoute = WalkingRoute(
            totalDistance: 2000,
            totalTime: 1200,
            path: [Self.start, Self.end],
            maneuvers: []
        )
        service.replace(with: newRoute)

        #expect(service.route?.totalDistance == 2000)
        #expect(service.route?.totalDistance != original?.totalDistance)
    }

    @Test("연속 검색 시 최신 route로 갱신된다")
    func search_twice_updatesRoute() async throws {
        let mockRepo = MockWalkingRouteRepository()
        var callCount = 0
        mockRepo.makeRouteHandler = { start, end in
            callCount += 1
            return WalkingRoute(
                totalDistance: callCount * 100,
                totalTime: 60,
                path: [start, end],
                maneuvers: []
            )
        }
        let service = RouteSearchService(repository: mockRepo)

        try await service.search(from: Self.start, to: Self.end)
        #expect(service.route?.totalDistance == 100)

        try await service.search(from: Self.start, to: Self.end)
        #expect(service.route?.totalDistance == 200)
    }
}
