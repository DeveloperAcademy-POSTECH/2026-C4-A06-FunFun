//  RouteTracker.swift
//  LiveActivity_Practice

import CoreLocation
import Foundation

@Observable
final class RouteTracker {

    enum DeviationState: Equatable {
        case onRoute
        case suspected(distance: CLLocationDistance)
        case offRoute(distance: CLLocationDistance)
        case offRouteChecked
        case rerouting
    }

    struct RouteMatch {
        let segmentIndex: Int
        let distance: CLLocationDistance
        let snappedCoordinate: Coordinate
    }

    // MARK: - 이탈 상태

    private(set) var deviationState: DeviationState = .onRoute
    private(set) var deviationPath: [Coordinate] = []
    private(set) var distanceFromRoute: CLLocationDistance = 0
    var shouldPresentReroutePrompt = false
    private(set) var isOffRouteBannerHidden = false

    // MARK: - 진행도

    private(set) var progress: WalkingProgress?
    private(set) var passedRouteIndex = -1

    // MARK: - Computed

    var isOffRoute: Bool {
        switch deviationState {
        case .offRoute, .rerouting, .offRouteChecked: true
        case .onRoute, .suspected: false
        }
    }

    var isRerouting: Bool { deviationState == .rerouting }

    // MARK: - 설정

    var approachingThreshold: Double
    private let walkingSpeed: Double

    // MARK: - Private

    private var consecutiveOffRouteUpdates = 0
    private var hasAskedForCurrentDeviation = false
    private var activeTurnManeuver: WalkingManeuver?
    private var lastManeuverID: Int?

    private static let passedZoneTurnTypes: Set<WalkingTurn> = [.left, .slightLeft, .right, .slightRight]
    private static let passedZoneDistance: Double = 15
    private static let passedZoneRadius: Double = 10

    // MARK: - Init

    init(approachingThreshold: Double = 20, walkingSpeed: Double = 1.25) {
        self.approachingThreshold = approachingThreshold
        self.walkingSpeed = walkingSpeed
    }

    // MARK: - Public

    /// 위치 업데이트 시 호출: 매칭 → 이탈 판정 → 진행도 계산을 순서대로 수행
    @discardableResult
    func update(
        at current: Coordinate,
        route: WalkingRoute,
        destination: Coordinate,
        horizontalAccuracy: CLLocationAccuracy,
        isNavigating: Bool
    ) -> RouteMatch? {
        let routeMatch = matchToRoute(current: current, routePath: route.path)

        if let routeMatch, isNavigating {
            updateDeviationState(
                at: current,
                routeMatch: routeMatch,
                destination: destination,
                horizontalAccuracy: horizontalAccuracy
            )

            if deviationState == .onRoute {
                passedRouteIndex = max(passedRouteIndex, routeMatch.segmentIndex)
            }
        }

        let newProgress = calculateProgress(at: current, route: route)
        progress = newProgress

        lastManeuverID = lastManeuverID != newProgress.nextManeuver?.id
            ? newProgress.nextManeuver?.id
            : lastManeuverID

        return routeMatch
    }

    func initialProgress(for route: WalkingRoute) -> WalkingProgress {
        let firstDistance = route.maneuvers.first.map {
            Int(route.path.first?.distance(to: $0.coordinate) ?? 0)
        } ?? route.totalDistance
        return WalkingProgress(
            remainingDistance: route.totalDistance,
            distanceToNextManeuver: firstDistance,
            nextManeuver: route.maneuvers.first,
            isOffRoute: false,
            isApproachingTurn: firstDistance < Int(approachingThreshold),
            distanceFromRoute: 0,
            estimatedArrival: .now.addingTimeInterval(Double(route.totalDistance) / walkingSpeed)
        )
    }

    func setInitialProgress(for route: WalkingRoute) {
        progress = initialProgress(for: route)
        passedRouteIndex = -1
        activeTurnManeuver = nil
    }

    func keepCurrentRoute() {
        shouldPresentReroutePrompt = false
        hasAskedForCurrentDeviation = true
        isOffRouteBannerHidden = true
    }

    func startRerouting() {
        deviationState = .rerouting
    }

    func resetAfterReroute(newRoute: WalkingRoute) {
        let newProgress = initialProgress(for: newRoute)
        progress = newProgress
        passedRouteIndex = -1
        activeTurnManeuver = nil
        lastManeuverID = nil
        resetDeviationState()
    }

    func rerouteFailed() {
        deviationState = .offRoute(distance: distanceFromRoute)
    }

    func reset() {
        resetDeviationState()
        progress = nil
        passedRouteIndex = -1
        activeTurnManeuver = nil
        lastManeuverID = nil
    }

    // MARK: - 경로 매칭

    private func matchToRoute(current: Coordinate, routePath: [Coordinate]) -> RouteMatch? {
        guard routePath.count >= 2 else { return nil }
        return zip(routePath.indices, routePath.indices.dropFirst())
            .map { indices in
                let (startIndex, endIndex) = indices
                return routeMatch(
                    current: current,
                    segmentStart: routePath[startIndex],
                    segmentEnd: routePath[endIndex],
                    segmentIndex: startIndex
                )
            }
            .min { $0.distance < $1.distance }
    }

    private func routeMatch(
        current: Coordinate,
        segmentStart: Coordinate,
        segmentEnd: Coordinate,
        segmentIndex: Int
    ) -> RouteMatch {
        let metersPerLatitudeDegree = 111_132.0
        let metersPerLongitudeDegree = 111_320.0 * cos(current.latitude * .pi / 180)
        let segmentX = (segmentEnd.longitude - segmentStart.longitude) * metersPerLongitudeDegree
        let segmentY = (segmentEnd.latitude - segmentStart.latitude) * metersPerLatitudeDegree
        let currentX = (current.longitude - segmentStart.longitude) * metersPerLongitudeDegree
        let currentY = (current.latitude - segmentStart.latitude) * metersPerLatitudeDegree
        let lengthSquared = segmentX * segmentX + segmentY * segmentY
        let projection = lengthSquared > 0
            ? max(0, min(1, (currentX * segmentX + currentY * segmentY) / lengthSquared))
            : 0
        let nearestX = segmentX * projection
        let nearestY = segmentY * projection
        let snappedCoordinate = Coordinate(
            latitude: segmentStart.latitude + (segmentEnd.latitude - segmentStart.latitude) * projection,
            longitude: segmentStart.longitude + (segmentEnd.longitude - segmentStart.longitude) * projection
        )
        return RouteMatch(
            segmentIndex: segmentIndex,
            distance: hypot(currentX - nearestX, currentY - nearestY),
            snappedCoordinate: snappedCoordinate
        )
    }

    // MARK: - 이탈 판정

    private func updateDeviationState(
        at current: Coordinate,
        routeMatch: RouteMatch,
        destination: Coordinate,
        horizontalAccuracy: CLLocationAccuracy
    ) {
        guard deviationState != .rerouting else { return }

        // 목적지 50m 이내에서는 경로 이탈 감지 비활성화
        let distToDestination = current.distance(to: destination)
        if distToDestination <= 50 {
            if isOffRoute { resetDeviationState() }
            return
        }

        distanceFromRoute = routeMatch.distance
        let validAccuracy = horizontalAccuracy >= 0 ? horizontalAccuracy : 0
        let deviationThreshold = max(25, min(validAccuracy * 1.5, 60))
        let recoveryThreshold: CLLocationDistance = 15

        if isOffRoute {
            if routeMatch.distance <= recoveryThreshold {
                resetDeviationState()
            } else {
                deviationState = .offRoute(distance: routeMatch.distance)
                appendDeviationCoordinate(current)
            }
            return
        }

        guard routeMatch.distance > deviationThreshold else {
            consecutiveOffRouteUpdates = 0
            deviationState = .onRoute
            return
        }

        consecutiveOffRouteUpdates += 1
        deviationState = .suspected(distance: routeMatch.distance)
        guard consecutiveOffRouteUpdates >= 3 else { return }

        deviationState = .offRoute(distance: routeMatch.distance)
        deviationPath = [routeMatch.snappedCoordinate]
        appendDeviationCoordinate(current)
        if !hasAskedForCurrentDeviation {
            hasAskedForCurrentDeviation = true
            shouldPresentReroutePrompt = true
        }
    }

    private func resetDeviationState() {
        deviationState = .onRoute
        deviationPath = []
        distanceFromRoute = 0
        consecutiveOffRouteUpdates = 0
        hasAskedForCurrentDeviation = false
        shouldPresentReroutePrompt = false
        isOffRouteBannerHidden = false
    }

    private func appendDeviationCoordinate(_ coordinate: Coordinate) {
        guard deviationPath.last?.distance(to: coordinate) ?? .greatestFiniteMagnitude >= 3 else { return }
        deviationPath.append(coordinate)
    }

    // MARK: - 진행도 계산

    private func calculateProgress(at current: Coordinate, route: WalkingRoute) -> WalkingProgress {
        guard let nearest = route.path.enumerated().min(by: {
            $0.element.distance(to: current) < $1.element.distance(to: current)
        }) else { return initialProgress(for: route) }

        // 목적지 좌표 근접 시 도착 처리
        if let destination = route.path.last {
            let distanceToDestination = Int(current.distance(to: destination))
            if distanceToDestination <= Int(approachingThreshold) {
                activeTurnManeuver = nil
                return WalkingProgress(
                    remainingDistance: distanceToDestination,
                    distanceToNextManeuver: distanceToDestination,
                    nextManeuver: route.maneuvers.last,
                    isOffRoute: self.isOffRoute,
                    isApproachingTurn: true,
                    distanceFromRoute: Int(self.distanceFromRoute),
                    estimatedArrival: .now.addingTimeInterval(Double(distanceToDestination) / walkingSpeed)
                )
            }
        }

        // 회전 maneuver의 passed zone 체크
        if let activeTurn = activeTurnManeuver {
            if let center = Self.passedZoneCenter(for: activeTurn, routePath: route.path) {
                let distToZone = current.distance(to: center)
                if distToZone <= Self.passedZoneRadius {
                    activeTurnManeuver = nil
                } else {
                    let remaining = zip(route.path[nearest.offset...], route.path.dropFirst(nearest.offset + 1))
                        .reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
                    return WalkingProgress(
                        remainingDistance: Int(remaining),
                        distanceToNextManeuver: Int(current.distance(to: activeTurn.coordinate)),
                        nextManeuver: activeTurn,
                        isOffRoute: self.isOffRoute,
                        isApproachingTurn: true,
                        distanceFromRoute: Int(self.distanceFromRoute),
                        estimatedArrival: .now.addingTimeInterval(remaining / walkingSpeed)
                    )
                }
            }
        }

        let next = route.maneuvers.first { $0.routeIndex >= max(nearest.offset, passedRouteIndex + 1) }
            ?? route.maneuvers.last
        let nextDistance = next.map { Int(current.distance(to: $0.coordinate)) } ?? 0
        let remaining = zip(route.path[nearest.offset...], route.path.dropFirst(nearest.offset + 1))
            .reduce(0.0) { $0 + $1.0.distance(to: $1.1) }

        let isApproaching = nextDistance < Int(approachingThreshold)

        // 회전 maneuver approaching 진입 시 active turn 설정
        if isApproaching, let maneuver = next, Self.passedZoneTurnTypes.contains(maneuver.turn),
           activeTurnManeuver == nil {
            activeTurnManeuver = maneuver
        }

        return WalkingProgress(
            remainingDistance: Int(remaining),
            distanceToNextManeuver: nextDistance,
            nextManeuver: next,
            isOffRoute: self.isOffRoute,
            isApproachingTurn: isApproaching,
            distanceFromRoute: Int(self.distanceFromRoute),
            estimatedArrival: .now.addingTimeInterval(remaining / walkingSpeed)
        )
    }

    private static func passedZoneCenter(for maneuver: WalkingManeuver, routePath: [Coordinate]) -> Coordinate? {
        let idx = maneuver.routeIndex
        guard idx + 1 < routePath.count else { return nil }
        let from = maneuver.coordinate
        let to = routePath[idx + 1]
        let dist = from.distance(to: to)
        guard dist > 0 else { return nil }
        let ratio = min(passedZoneDistance / dist, 1.0)
        return Coordinate(
            latitude: from.latitude + (to.latitude - from.latitude) * ratio,
            longitude: from.longitude + (to.longitude - from.longitude) * ratio
        )
    }
}
