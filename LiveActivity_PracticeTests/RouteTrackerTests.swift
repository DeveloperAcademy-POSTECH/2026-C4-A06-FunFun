//  RouteTrackerTests.swift
//  LiveActivity_PracticeTests

import CoreLocation
import Testing
@testable import LiveActivity_Practice

// MARK: - 테스트 공통 데이터

private enum TestData {
    // 직선 경로: 남→북 약 500m (10m 간격, 51개 포인트)
    static let path: [Coordinate] = (0...50).map {
        Coordinate(latitude: 37.5000 + Double($0) * 0.00009, longitude: 127.0000)
    }

    static let destination = path.last!

    static let maneuvers: [WalkingManeuver] = [
        WalkingManeuver(
            id: 1,
            coordinate: path[20],
            turn: .left,
            description: "좌회전",
            routeIndex: 20,
            landmark: nil
        ),
        WalkingManeuver(
            id: 2,
            coordinate: path[50],
            turn: .destination,
            description: "도착",
            routeIndex: 50,
            landmark: nil
        ),
    ]

    static let route = WalkingRoute(
        totalDistance: 500,
        totalTime: 400,
        path: path,
        maneuvers: maneuvers
    )

    /// 경로에서 동쪽으로 offset미터 벗어난 좌표
    static func offRoutePoint(baseIndex: Int, offsetMeters: Double) -> Coordinate {
        let base = path[baseIndex]
        // 경도 1도 ≈ 88km (위도 37.5 기준)
        let lonOffset = offsetMeters / 88_000
        return Coordinate(latitude: base.latitude, longitude: base.longitude + lonOffset)
    }
}

// MARK: - 경로 매칭

@Suite("RouteTracker 경로 매칭")
struct RouteTrackerMatchingTests {

    @Test("경로 위에 있으면 onRoute 상태")
    func onRoute_staysOnRoute() {
        let tracker = RouteTracker()
        let current = TestData.path[10]

        tracker.update(
            at: current,
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )

        #expect(tracker.deviationState == .onRoute)
    }

    @Test("경로 위 이동 시 passedRouteIndex가 증가한다")
    func onRoute_passedRouteIndexIncreases() {
        let tracker = RouteTracker()

        tracker.update(
            at: TestData.path[5],
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )
        let first = tracker.passedRouteIndex

        tracker.update(
            at: TestData.path[15],
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )

        #expect(tracker.passedRouteIndex > first)
    }
}

// MARK: - 이탈 판정 상태 머신

@Suite("RouteTracker 이탈 판정")
struct RouteTrackerDeviationTests {

    @Test("1회 이탈 → suspected 상태")
    func singleDeviation_suspected() {
        let tracker = RouteTracker()
        let offRoute = TestData.offRoutePoint(baseIndex: 10, offsetMeters: 40)

        tracker.update(
            at: offRoute,
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )

        if case .suspected = tracker.deviationState {
            // pass
        } else {
            Issue.record("expected suspected, got \(tracker.deviationState)")
        }
    }

    @Test("3회 연속 이탈 → offRoute 상태")
    func threeConsecutiveDeviations_offRoute() {
        let tracker = RouteTracker()

        for i in 0..<3 {
            let offRoute = TestData.offRoutePoint(baseIndex: 10 + i, offsetMeters: 40)
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }

        #expect(tracker.isOffRoute == true)
    }

    @Test("3회 연속 이탈 후 경로 복귀 → onRoute")
    func offRouteThenRecover_onRoute() {
        let tracker = RouteTracker()

        // 3회 이탈
        for i in 0..<3 {
            let offRoute = TestData.offRoutePoint(baseIndex: 10 + i, offsetMeters: 40)
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }
        #expect(tracker.isOffRoute == true)

        // 경로 위로 복귀 (recoveryThreshold 15m 이내)
        tracker.update(
            at: TestData.path[12],
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )

        #expect(tracker.deviationState == .onRoute)
        #expect(tracker.deviationPath.isEmpty)
    }

    @Test("목적지 50m 이내에서는 이탈 감지 비활성화")
    func nearDestination_noDeviation() {
        let tracker = RouteTracker()
        // 목적지 근처에서 경로 밖
        let nearDest = TestData.offRoutePoint(baseIndex: 49, offsetMeters: 40)

        for _ in 0..<3 {
            tracker.update(
                at: nearDest,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }

        #expect(tracker.isOffRoute == false)
    }

    @Test("GPS 정확도가 나쁘면 이탈 임계값이 높아진다")
    func poorAccuracy_higherThreshold() {
        let tracker = RouteTracker()
        // 30m 떨어진 지점 — 정확도 좋으면(10m) threshold=25m이므로 이탈
        // 정확도 나쁘면(40m) threshold=60m이므로 onRoute
        let point = TestData.offRoutePoint(baseIndex: 10, offsetMeters: 30)

        tracker.update(
            at: point,
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 40,
            isNavigating: true
        )

        #expect(tracker.deviationState == .onRoute)
    }

    @Test("isNavigating=false이면 이탈 판정하지 않음")
    func notNavigating_noDeviationCheck() {
        let tracker = RouteTracker()
        let offRoute = TestData.offRoutePoint(baseIndex: 10, offsetMeters: 40)

        for _ in 0..<3 {
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: false
            )
        }

        #expect(tracker.deviationState == .onRoute)
    }

    @Test("이탈 시 deviationPath에 좌표가 추가된다")
    func offRoute_appendsDeviationPath() {
        let tracker = RouteTracker()

        for i in 0..<5 {
            let offRoute = TestData.offRoutePoint(baseIndex: 10 + i, offsetMeters: 40)
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }

        #expect(tracker.deviationPath.count > 0)
    }

    @Test("3회 연속 이탈 시 첫 번째에서만 shouldPresentReroutePrompt = true")
    func offRoute_reroutePromptOnce() {
        let tracker = RouteTracker()

        for i in 0..<3 {
            let offRoute = TestData.offRoutePoint(baseIndex: 10 + i, offsetMeters: 40)
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }

        #expect(tracker.shouldPresentReroutePrompt == true)
    }
}

// MARK: - 경로 유지 / 재탐색

@Suite("RouteTracker 경로 유지 및 재탐색")
struct RouteTrackerRerouteTests {

    @Test("keepCurrentRoute → shouldPresentReroutePrompt = false, isOffRouteBannerHidden = true")
    func keepCurrentRoute_hidesPrompt() {
        let tracker = RouteTracker()

        // 이탈 상태로 만들기
        for i in 0..<3 {
            let offRoute = TestData.offRoutePoint(baseIndex: 10 + i, offsetMeters: 40)
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }

        tracker.keepCurrentRoute()

        #expect(tracker.shouldPresentReroutePrompt == false)
        #expect(tracker.isOffRouteBannerHidden == true)
    }

    @Test("startRerouting → rerouting 상태")
    func startRerouting_setsState() {
        let tracker = RouteTracker()
        tracker.startRerouting()
        #expect(tracker.isRerouting == true)
    }

    @Test("resetAfterReroute → onRoute + 새 progress")
    func resetAfterReroute_cleansUp() {
        let tracker = RouteTracker()
        tracker.startRerouting()

        tracker.resetAfterReroute(newRoute: TestData.route)

        #expect(tracker.deviationState == .onRoute)
        #expect(tracker.progress != nil)
        #expect(tracker.passedRouteIndex == -1)
    }

    @Test("rerouteFailed → offRoute 상태 복원")
    func rerouteFailed_restoresOffRoute() {
        let tracker = RouteTracker()

        // 이탈 → rerouting → 실패
        for i in 0..<3 {
            let offRoute = TestData.offRoutePoint(baseIndex: 10 + i, offsetMeters: 40)
            tracker.update(
                at: offRoute,
                route: TestData.route,
                destination: TestData.destination,
                horizontalAccuracy: 10,
                isNavigating: true
            )
        }
        tracker.startRerouting()
        tracker.rerouteFailed()

        if case .offRoute = tracker.deviationState {
            // pass
        } else {
            Issue.record("expected offRoute, got \(tracker.deviationState)")
        }
    }
}

// MARK: - 진행도 계산

@Suite("RouteTracker 진행도 계산")
struct RouteTrackerProgressTests {

    @Test("initialProgress는 첫 maneuver까지의 거리를 반환한다")
    func initialProgress_firstManeuverDistance() {
        let tracker = RouteTracker()

        let progress = tracker.initialProgress(for: TestData.route)

        #expect(progress.remainingDistance == TestData.route.totalDistance)
        #expect(progress.nextManeuver?.id == 1)
    }

    @Test("경로 진행 시 remainingDistance가 줄어든다")
    func progressDecreases() {
        let tracker = RouteTracker()

        tracker.update(
            at: TestData.path[5],
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )
        let earlyRemaining = tracker.progress!.remainingDistance

        tracker.update(
            at: TestData.path[30],
            route: TestData.route,
            destination: TestData.destination,
            horizontalAccuracy: 10,
            isNavigating: true
        )
        let lateRemaining = tracker.progress!.remainingDistance

        #expect(earlyRemaining > lateRemaining)
    }

    @Test("reset 후 progress는 nil")
    func reset_clearsProgress() {
        let tracker = RouteTracker()
        tracker.setInitialProgress(for: TestData.route)
        #expect(tracker.progress != nil)

        tracker.reset()

        #expect(tracker.progress == nil)
        #expect(tracker.passedRouteIndex == -1)
    }
}
