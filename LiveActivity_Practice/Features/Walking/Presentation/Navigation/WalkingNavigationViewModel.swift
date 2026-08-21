//  WalkingNavigationViewModel.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import Combine
import CoreLocation
import Foundation

@Observable
final class WalkingNavigationViewModel: NSObject {

    // MARK: - State & Properties

    enum ViewState: Equatable {
        case main // 기본 상태 : 기본 + 장소 선택
        case routePreview // 경로가 찾아진 상태 : 미리 보여줌
        case loading // API 응답 대기중
        case navigating // 경로를 따라가는 중
        case error(Error) // 에러 케이스

        static func == (lhs: WalkingNavigationViewModel.ViewState, rhs: WalkingNavigationViewModel.ViewState) -> Bool {
              switch (lhs, rhs) {
              case (.main, .main),
                   (.routePreview, .routePreview),
                   (.loading, .loading),
                   (.navigating, .navigating):
                  return true
              case (.error, .error):
                  return true
              default:
                  return false
              }
        }
    }
    
    enum RouteDeviationState: Equatable {
        case onRoute
        case suspected(distance: CLLocationDistance)
        case offRoute(distance: CLLocationDistance)
        case offRouteChecked
        case rerouting
    }
    
    private(set)var viewState: ViewState = .main
    
    var start: Place?
    var destination: Place?
    private(set) var selecedPlace: Place?
    
    private(set) var route: WalkingRoute?
    private(set) var progress: WalkingProgress?
    private(set) var currentLocation: Coordinate?
    private(set) var currentHeading: CLLocationDirection?
    
    // TODO: 이거 왜 쓰는거지?
    private(set) var currentLocationAccuracy: CLLocationAccuracy?
    private(set) var navigationBearing: CLLocationDirection?
    private(set) var navigationAlignmentID: Int?
    
    private(set) var deviationState: RouteDeviationState = .onRoute
    private(set) var deviationPath: [Coordinate] = []
    private(set) var distanceFromRoute: CLLocationDistance = 0
    private(set) var isOffRouteBannerHidden = false
    
    private(set) var passedRouteIndex = -1
    var shouldPresentReroutePrompt = false
    
    private(set) var isArrived = false
    var errorMessage: String?
    var showTimeInsteadOfDistance = false
    var showLandmarks = true

    var landmarkMinZoom: Double = 20
    var approachingThreshold: Double = 20

    // 개발자용
    var showTurnMarkers = false
    var showRoutePoints = false
    var routePointRadius: Double = 10
    var showGradientOverlay = true

    var landmarkCount: Int {
        guard let route else { return 0 }
        return Set(route.maneuvers.compactMap { $0.landmark?.id }).count
    }

    var isOffRoute: Bool {
        switch deviationState {
        case .offRoute, .rerouting, .offRouteChecked: true
        case .onRoute, .suspected: false
        }
    }

    var isRerouting: Bool { deviationState == .rerouting }

    private let repository: WalkingRouteRepositoryProtocol
    private let placeSearchClient: TMAPClientProtocol
    private let activityManager: WalkingLiveActivityManager
    private let locationManager = CLLocationManager()
    private var lastManeuverID: Int?
    private var shouldTrackLocation = false
    // 좌표 업데이트 때, true면 route의 시작 좌표로 사용 / false이면 무시
    private var shouldUseLocationAsStart = false
    private var consecutiveOffRouteUpdates = 0
    private var hasAskedForCurrentDeviation = false
    private var navigationAlignmentSequence = 0
    private static let passedZoneTurnTypes: Set<WalkingTurn> = [.left, .slightLeft, .right, .slightRight]
    private static let passedZoneDistance: Double = 15
    private static let passedZoneRadius: Double = 10
    private var activeTurnManeuver: WalkingManeuver?
    private let walkingSpeed = 1.25

    // MARK: - Init

    init(
        repository: WalkingRouteRepositoryProtocol = WalkingRouteRepository(),
        placeSearchClient: TMAPClientProtocol = TMAPClient(),
        activityManager: WalkingLiveActivityManager? = nil
    ) {
        self.repository = repository
        self.placeSearchClient = placeSearchClient
        self.activityManager = activityManager ?? WalkingLiveActivityManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 2
        locationManager.activityType = .fitness
    }
    
    // MARK: - 장소 선택
    
    func placeSelected(_ place: Place) {
        selecedPlace = place
    }
    
    func clearSelectedPlace() {
        selecedPlace = nil
    }
    
    func mainMode() {
        viewState = .main
        clearSelectedPlace()
    }
    
    func setStartFromCurrentLocation() {
        guard let location = currentLocation else {
            shouldTrackLocation = false
            shouldUseLocationAsStart = true
            requestLocationAccess()
            return
        }
        start = Place.init(id: "", name: "현재 위치", category: "", address: "",
                           coordinate: Coordinate(
                            latitude: location.latitude,
                            longitude: location.longitude))
    }
    
    // MARK: - 경로 탐색
    
    func searchRoute() async {
        setStartFromCurrentLocation()
        
        guard let start = start, let destination = destination else {
            errorMessage = "검색 결과에서 출발지와 목적지를 선택해 주세요."
            return
        }
        viewState = .loading
        errorMessage = nil
        defer { viewState = .main }
        do {
            route = try await repository.makeRoute(from: start.coordinate, to: destination.coordinate)
            progress = route.map(initialProgress)
            passedRouteIndex = -1
            activeTurnManeuver = nil
            selecedPlace = nil
            viewState = .routePreview
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func dismissRoute() async {
        if viewState == .navigating {
            await stopNavigation()
        }
        route = nil
        progress = nil
        selecedPlace = nil
        passedRouteIndex = -1
        activeTurnManeuver = nil
        destination = nil
        errorMessage = nil
        startLocationTracking()
    }
    
    // MARK: - 내비게이션
    
    func startNavigating() async {
        guard let route, destination != nil else { return }
        do {
            let startProgress = initialProgress(route)
            try await activityManager.start(destinationName: destination!.name, route: route, initialProgress: startProgress, showTime: showTimeInsteadOfDistance)
            viewState = .navigating
            passedRouteIndex = -1
            activeTurnManeuver = nil
            navigationBearing = nil
            if let currentLocation {
                updateNavigationBearing(at: currentLocation, route: route)
            }
            if navigationBearing == nil {
                updateNavigationBearingFromRouteStart(route)
            }
            navigationAlignmentSequence += 1
            navigationAlignmentID = navigationAlignmentSequence
            locationManager.requestWhenInUseAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            viewState = .navigating
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stopNavigation() async {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        await activityManager.end()
        isArrived = false
        navigationBearing = nil
        navigationAlignmentID = nil
        resetDeviationState()
    }
    
    func refreshLiveActivity() {
        guard let progress else { return }
        Task {
            await activityManager.update(progress, showTime: showTimeInsteadOfDistance)
        }
    }
    
    // MARK: - 경로 이탈
    
    func keepCurrentRoute() {
        shouldPresentReroutePrompt = false
        hasAskedForCurrentDeviation = true
        isOffRouteBannerHidden = true
    }
    
    func rerouteFromCurrentLocation() async {
        guard viewState == .navigating, !isRerouting, let currentLocation, let destination = destination else { return }
        
        shouldPresentReroutePrompt = false
        deviationState = .rerouting
        do {
            let newRoute = try await repository.makeRoute(from: currentLocation, to: destination.coordinate)
            route = newRoute
            let newProgress = initialProgress(newRoute)
            progress = newProgress
            passedRouteIndex = -1
            activeTurnManeuver = nil
            lastManeuverID = nil
            resetDeviationState()
            navigationBearing = nil
            updateNavigationBearing(at: currentLocation, route: newRoute)
            navigationAlignmentSequence += 1
            navigationAlignmentID = navigationAlignmentSequence
            await activityManager.update(newProgress, showTime: showTimeInsteadOfDistance)
        } catch {
            deviationState = .offRoute(distance: distanceFromRoute)
            errorMessage = "경로를 다시 찾지 못했습니다: \(error.localizedDescription)"
        }
    }
    
    // GPS 업데이트마다 호출되어 "경로 이탈 여부"를 판정하는 상태 머신
    private func updateDeviationState(at current: Coordinate, routeMatch: RouteMatch, horizontalAccuracy: CLLocationAccuracy) {
        guard viewState == .navigating, deviationState != .rerouting else { return }
        
        // 목적지 50m 이내에서는 경로 이탈 감지 비활성화
        if let destination = destination {
            let distToDestination = current.distance(to: destination.coordinate)
            if distToDestination <= 50 {
                if isOffRoute { resetDeviationState() }
                return
            }
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
    
    // MARK: - 경로 진행 계산
    
    private func initialProgress(_ route: WalkingRoute) -> WalkingProgress {
        let firstDistance = route.maneuvers.first.map { Int(route.path.first?.distance(to: $0.coordinate) ?? 0) } ?? route.totalDistance
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
    
    private func calculateProgress(at current: Coordinate, route: WalkingRoute) -> WalkingProgress {
        guard let nearest = route.path.enumerated().min(by: {
            $0.element.distance(to: current) < $1.element.distance(to: current)
        }) else { return initialProgress(route) }
        
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
    
    // MARK: - 경로 매칭
    
    private struct RouteMatch {
        let segmentIndex: Int
        let distance: CLLocationDistance
        let snappedCoordinate: Coordinate
    }
    
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
    
    private func routeMatch(current: Coordinate, segmentStart: Coordinate, segmentEnd: Coordinate, segmentIndex: Int) -> RouteMatch {
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
    
    // MARK: - 카메라 방향
    
    // 현재 위치에서 경로상 20m 앞 지점까지의 경로 방향을 계산
    private func updateNavigationBearing(at current: Coordinate, route: WalkingRoute) {
        guard viewState == .navigating,
              (currentLocationAccuracy ?? .greatestFiniteMagnitude) <= 30,
              route.path.count >= 2,
              let nearest = route.path.enumerated().min(by: {
                  $0.element.distance(to: current) < $1.element.distance(to: current)
              }) else {
            navigationBearing = nil
            return
        }
        
        let lookAheadDistance: CLLocationDistance = 20
        var targetIndex = nearest.offset
        var accumulatedDistance: CLLocationDistance = 0
        while targetIndex < route.path.count - 1, accumulatedDistance < lookAheadDistance {
            accumulatedDistance += route.path[targetIndex].distance(to: route.path[targetIndex + 1])
            targetIndex += 1
        }
        
        guard targetIndex > nearest.offset else { return }
        let candidate = bearing(from: route.path[nearest.offset], to: route.path[targetIndex])
        navigationBearing = smoothedBearing(from: navigationBearing, to: candidate)
    }
    
    // 경로 시작점에서 20m 앞까지의 방향 계산 (초기값용)
    private func updateNavigationBearingFromRouteStart(_ route: WalkingRoute) {
        guard route.path.count >= 2 else { return }
        
        let lookAheadDistance: CLLocationDistance = 20
        var targetIndex = 0
        var accumulatedDistance: CLLocationDistance = 0
        while targetIndex < route.path.count - 1, accumulatedDistance < lookAheadDistance {
            accumulatedDistance += route.path[targetIndex].distance(to: route.path[targetIndex + 1])
            targetIndex += 1
        }
        
        guard targetIndex > 0 else { return }
        navigationBearing = bearing(from: route.path[0], to: route.path[targetIndex])
    }
    
    // 두 좌표 간 지리적 방위각 계산 (Haversine 공식)
    private func bearing(from start: Coordinate, to end: Coordinate) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // 방위각 변화를 보간(0.35 비율)해서 카메라가 급격히 회전하지 않게 함
    private func smoothedBearing(from previous: CLLocationDirection?, to candidate: CLLocationDirection) -> CLLocationDirection {
        guard let previous else { return candidate }
        let shortestDelta = (candidate - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        guard abs(shortestDelta) >= 3 else { return previous }
        return (previous + shortestDelta * 0.35 + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - 위치 권한
    
    func startLocationTracking() {
        shouldTrackLocation = true
        requestLocationAccess()
    }
    
    private func requestLocationAccess() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            if shouldTrackLocation {
                locationManager.startUpdatingLocation()
                locationManager.startUpdatingHeading()
            } else {
                locationManager.requestLocation()
            }
        case .denied, .restricted:
            errorMessage = "현재 위치 권한을 허용해 주세요."
        @unknown default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WalkingNavigationViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        currentLocation = coordinate
        currentLocationAccuracy = location.horizontalAccuracy
        
        // 사용자가 "현재 위치"를 출발지로 사용하려 할 때, 아직 GPS 좌표를 못 받은 경우의 플래그
        if shouldUseLocationAsStart {
            // 장소 선택 → placeSelected → setStartFromCurrentLocation
            // 이 시점에 currentLocation이 nil이면 출발지를 바로 채울 수 없어
            // 플래그를 켜두고 GPS가 오면 그때 채움
            start = Place.init(id: "", name: "현재 위치", category: "", address: "",
                               coordinate: Coordinate(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude))
            shouldUseLocationAsStart = false
        }
        
        guard let route else { return }
        
        if let routeMatch = matchToRoute(current: coordinate, routePath: route.path) {
            updateDeviationState(
                at: coordinate,
                routeMatch: routeMatch,
                horizontalAccuracy: location.horizontalAccuracy
            )
            
            if viewState == .navigating, deviationState == .onRoute {
                passedRouteIndex = max(passedRouteIndex, routeMatch.segmentIndex)
            }
        }
        
        let newProgress = calculateProgress(at: coordinate, route: route)
        progress = newProgress
        
        if viewState == .navigating , navigationBearing == nil {
            updateNavigationBearing(at: coordinate, route: route)
        }
        
        lastManeuverID = lastManeuverID != newProgress.nextManeuver?.id ?  newProgress.nextManeuver?.id : lastManeuverID
        
        Task {
            await activityManager.update(newProgress, showTime: showTimeInsteadOfDistance)
        }
        
        // 도착 감지 → 5초 후 자동 종료
        if newProgress.nextManeuver?.turn == .destination,
           newProgress.isApproachingTurn,
           !isArrived {
            isArrived = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await dismissRoute()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "위치를 가져오지 못했습니다: \(error.localizedDescription)"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocationAccess()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}

private extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
