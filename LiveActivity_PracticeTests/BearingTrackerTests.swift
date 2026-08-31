//  BearingTrackerTests.swift
//  LiveActivity_PracticeTests

import CoreLocation
import Testing
@testable import LiveActivity_Practice

@Suite("BearingTracker 카메라 방향 계산")
struct BearingTrackerTests {

    // 테스트용 경로: 남→북 직선 (약 500m)
    private static let northRoute = WalkingRoute(
        totalDistance: 500,
        totalTime: 400,
        path: (0...50).map {
            Coordinate(latitude: 37.5000 + Double($0) * 0.0001, longitude: 127.0000)
        },
        maneuvers: []
    )

    // 테스트용 경로: 서→동 직선
    private static let eastRoute = WalkingRoute(
        totalDistance: 500,
        totalTime: 400,
        path: (0...50).map {
            Coordinate(latitude: 37.5000, longitude: 127.0000 + Double($0) * 0.0001)
        },
        maneuvers: []
    )

    // MARK: - 정상 동작

    @Test("정확도가 좋으면 bearing이 계산된다")
    func update_goodAccuracy_setsBearing() {
        let tracker = BearingTracker()
        let current = Self.northRoute.path[5]

        tracker.update(at: current, route: Self.northRoute, accuracy: 10)

        #expect(tracker.bearing != nil)
    }

    @Test("북쪽 직진 경로에서 bearing은 약 0도")
    func update_northRoute_bearingNearZero() {
        let tracker = BearingTracker()
        let current = Self.northRoute.path[5]

        tracker.update(at: current, route: Self.northRoute, accuracy: 5)

        guard let bearing = tracker.bearing else {
            Issue.record("bearing이 nil")
            return
        }
        // 북쪽 = 0도 (또는 360도 근처)
        let normalized = bearing < 180 ? bearing : bearing - 360
        #expect(abs(normalized) < 5, "북쪽 직진인데 bearing=\(bearing)")
    }

    @Test("동쪽 직진 경로에서 bearing은 약 90도")
    func update_eastRoute_bearingNear90() {
        let tracker = BearingTracker()
        let current = Self.eastRoute.path[5]

        tracker.update(at: current, route: Self.eastRoute, accuracy: 5)

        guard let bearing = tracker.bearing else {
            Issue.record("bearing이 nil")
            return
        }
        #expect(abs(bearing - 90) < 5, "동쪽 직진인데 bearing=\(bearing)")
    }

    // MARK: - 정확도 가드

    @Test("정확도가 30 초과이면 bearing이 nil")
    func update_poorAccuracy_returnsNil() {
        let tracker = BearingTracker()
        let current = Self.northRoute.path[5]

        tracker.update(at: current, route: Self.northRoute, accuracy: 50)

        #expect(tracker.bearing == nil)
    }

    @Test("정확도가 정확히 30이면 bearing이 계산된다")
    func update_borderlineAccuracy_setsBearing() {
        let tracker = BearingTracker()
        let current = Self.northRoute.path[5]

        tracker.update(at: current, route: Self.northRoute, accuracy: 30)

        #expect(tracker.bearing != nil)
    }

    // MARK: - 초기값

    @Test("updateFromRouteStart는 경로 시작점 기준으로 bearing을 설정한다")
    func updateFromRouteStart_setsBearing() {
        let tracker = BearingTracker()

        tracker.updateFromRouteStart(Self.northRoute)

        #expect(tracker.bearing != nil)
    }

    @Test("경로 포인트가 2개 미만이면 bearing이 설정되지 않는다")
    func updateFromRouteStart_tooFewPoints() {
        let tracker = BearingTracker()
        let shortRoute = WalkingRoute(
            totalDistance: 10,
            totalTime: 10,
            path: [Coordinate(latitude: 37.5, longitude: 127.0)],
            maneuvers: []
        )

        tracker.updateFromRouteStart(shortRoute)

        #expect(tracker.bearing == nil)
    }

    // MARK: - 리셋

    @Test("reset 후 bearing은 nil")
    func reset_clearsBearing() {
        let tracker = BearingTracker()
        tracker.updateFromRouteStart(Self.northRoute)
        #expect(tracker.bearing != nil)

        tracker.reset()

        #expect(tracker.bearing == nil)
    }

    // MARK: - 스무딩

    @Test("연속 업데이트 시 bearing이 급격히 변하지 않는다")
    func update_smoothing_preventsSuddenJump() {
        let tracker = BearingTracker()

        // 먼저 북쪽 방향으로 설정
        tracker.update(at: Self.northRoute.path[5], route: Self.northRoute, accuracy: 5)
        let firstBearing = tracker.bearing!

        // 갑자기 동쪽 경로로 변경
        tracker.update(at: Self.eastRoute.path[5], route: Self.eastRoute, accuracy: 5)
        let secondBearing = tracker.bearing!

        // 스무딩(0.35 비율) 때문에 90도까지 한번에 가지 않음
        let delta = abs(secondBearing - firstBearing)
        #expect(delta < 50, "스무딩이 적용되어야 하는데 delta=\(delta)")
    }
}
