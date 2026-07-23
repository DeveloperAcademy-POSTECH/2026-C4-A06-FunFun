//  WalkingNavigationViewModel.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class WalkingNavigationViewModel: NSObject, ObservableObject {
    enum SearchTarget { case start, destination }

    enum RouteDeviationState: Equatable {
        case onRoute
        case suspected(distance: CLLocationDistance)
        case offRoute(distance: CLLocationDistance)
        case rerouting
    }

    @Published var startName = ""
    @Published var startLatitude = "37.497942"
    @Published var startLongitude = "127.027621"
    @Published var destinationLatitude = "37.491902"
    @Published var destinationLongitude = "127.031812"
    @Published var destinationName = ""
    @Published private(set) var placeSearchResults: [PlaceSearchResult] = []
    @Published private(set) var previewDestination: PlaceSearchResult?
    @Published private(set) var isSearchingPlaces = false
    @Published private(set) var canLoadMoreSearchResults = false
    private var currentSearchPage = 1
    private var lastSearchKeyword = ""
    @Published private(set) var hasSelectedStart = false
    @Published private(set) var hasSelectedDestination = false
    @Published private(set) var route: WalkingRoute?
    @Published private(set) var progress: WalkingProgress?
    @Published private(set) var currentLocation: Coordinate?
    @Published private(set) var currentHeading: CLLocationDirection?
    
    // TODO: 이거 왜 쓰는거지?
    @Published private(set) var currentLocationAccuracy: CLLocationAccuracy?
    @Published private(set) var navigationBearing: CLLocationDirection?
    @Published private(set) var navigationAlignmentID: Int?
    @Published private(set) var deviationState: RouteDeviationState = .onRoute
    @Published private(set) var deviationPath: [Coordinate] = []
    @Published private(set) var passedRouteIndex = -1
    @Published private(set) var distanceFromRoute: CLLocationDistance = 0
    @Published var shouldPresentReroutePrompt = false
    @Published private(set) var isLoading = false
    @Published private(set) var isNavigating = false
    @Published var errorMessage: String?
    @Published var showTimeInsteadOfDistance = false
    @Published var showLandmarks = true
    @Published var landmarkMinZoom: Double = 50
    @Published var approachingThreshold: Double = 10
    @Published var showTurnMarkers = false
    @Published var showGradientOverlay = true

    var landmarkCount: Int {
        guard let route else { return 0 }
        return Set(route.maneuvers.compactMap { $0.landmark?.id }).count
    }

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

    var isOffRoute: Bool {
        switch deviationState {
        case .offRoute, .rerouting: true
        case .onRoute, .suspected: false
        }
    }

    var isRerouting: Bool { deviationState == .rerouting }

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

    func useCurrentLocation() {
        shouldTrackLocation = false
        shouldUseLocationAsStart = true
        requestLocationAccess()
    }

    @Published private(set) var tappedCoordinate: Coordinate?

    func selectCoordinateAsDestination(_ coordinate: Coordinate) {
        previewDestination = nil
        tappedCoordinate = coordinate
        destinationName = String(format: "(%.4f, %.4f)", coordinate.latitude, coordinate.longitude)
        destinationLatitude = String(coordinate.latitude)
        destinationLongitude = String(coordinate.longitude)
        hasSelectedDestination = true
        setStartFromCurrentLocation()
    }

    func refreshLiveActivity() {
        guard let progress else { return }
        Task {
            await activityManager.update(progress,
                                         showTime: showTimeInsteadOfDistance)
        }
    }

    func clearTappedCoordinate() {
        previewDestination = nil
        tappedCoordinate = nil
        destinationName = ""
        destinationLatitude = ""
        destinationLongitude = ""
        hasSelectedDestination = false
        route = nil
        progress = nil
        passedRouteIndex = -1
        errorMessage = nil
    }

    func setStartFromCurrentLocation() {
        guard let location = currentLocation else {
            useCurrentLocation()
            return
        }
        startLatitude = String(location.latitude)
        startLongitude = String(location.longitude)
        startName = "현재 위치"
        hasSelectedStart = true
    }

    func updateSearchQuery(_ query: String, for target: SearchTarget) {
        switch target {
        case .start:
            guard query != startName else { return }
            startName = query
            hasSelectedStart = false
        case .destination:
            guard query != destinationName else { return }
            destinationName = query
            hasSelectedDestination = false
        }
        route = nil
        progress = nil
        passedRouteIndex = -1
        errorMessage = nil
    }

    func searchPlaces(keyword: String) async {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword.count >= 2 else {
            placeSearchResults = []
            canLoadMoreSearchResults = false
            return
        }

        currentSearchPage = 1
        lastSearchKeyword = keyword
        isSearchingPlaces = true
        defer { isSearchingPlaces = false }
        do {
            let response = try await placeSearchClient.searchPlaces(keyword: keyword, page: 1, near: currentLocation)
            let results = response.searchPoiInfo.pois.poi.compactMap(Self.mapPlaceSearchResult)
            placeSearchResults = results.uniqued(by: \.id)
            let totalCount = Int(response.searchPoiInfo.totalCount ?? "0") ?? 0
            canLoadMoreSearchResults = results.count < totalCount
        } catch is CancellationError {
            return
        } catch {
            placeSearchResults = []
            canLoadMoreSearchResults = false
            errorMessage = "장소를 검색하지 못했습니다: \(error.localizedDescription)"
        }
    }

    func loadMoreSearchResults() async {
        guard canLoadMoreSearchResults, !isSearchingPlaces, !lastSearchKeyword.isEmpty else { return }

        let nextPage = currentSearchPage + 1
        isSearchingPlaces = true
        defer { isSearchingPlaces = false }
        do {
            let response = try await placeSearchClient.searchPlaces(keyword: lastSearchKeyword, page: nextPage, near: currentLocation)
            let newResults = response.searchPoiInfo.pois.poi.compactMap(Self.mapPlaceSearchResult)
            let existingIDs = Set(placeSearchResults.map(\.id))
            let uniqueNewResults = newResults.filter { !existingIDs.contains($0.id) }
            placeSearchResults.append(contentsOf: uniqueNewResults)
            currentSearchPage = nextPage
            let totalCount = Int(response.searchPoiInfo.totalCount ?? "0") ?? 0
            canLoadMoreSearchResults = placeSearchResults.count < totalCount
        } catch is CancellationError {
            return
        } catch {
            canLoadMoreSearchResults = false
        }
    }

    func selectPlace(_ place: PlaceSearchResult, for target: SearchTarget) {
        switch target {
        case .start:
            startName = place.name
            startLatitude = String(place.coordinate.latitude)
            startLongitude = String(place.coordinate.longitude)
            hasSelectedStart = true
        case .destination:
            destinationName = place.name
            destinationLatitude = String(place.coordinate.latitude)
            destinationLongitude = String(place.coordinate.longitude)
            hasSelectedDestination = true
            tappedCoordinate = nil
            previewDestination = place
        }
        placeSearchResults = []
        errorMessage = nil
    }

    func clearPlaceSearchResults() {
        placeSearchResults = []
        canLoadMoreSearchResults = false
        currentSearchPage = 1
        lastSearchKeyword = ""
    }

    func dismissRoute() async {
        if isNavigating {
            await stopNavigation()
        }
        route = nil
        progress = nil
        previewDestination = nil
        passedRouteIndex = -1
        destinationName = ""
        destinationLatitude = ""
        destinationLongitude = ""
        hasSelectedDestination = false
        hasSelectedStart = false
        errorMessage = nil
        startLocationTracking()
    }

    func startLocationTracking() {
        shouldTrackLocation = true
        requestLocationAccess()
    }

    func searchRoute() async {
        guard hasSelectedStart, hasSelectedDestination else {
            errorMessage = "검색 결과에서 출발지와 목적지를 선택해 주세요."
            return
        }
        guard let start = startCoordinate, let destination = destinationCoordinate else {
            errorMessage = "출발지와 목적지 좌표를 확인해 주세요."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            route = try await repository.makeRoute(from: start, to: destination)
            progress = route.map(initialProgress)
            passedRouteIndex = -1
            previewDestination = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startNavigation() async {
        guard let route else { return }
        do {
            let startProgress = initialProgress(route)
            try await activityManager.start(destinationName: destinationName, route: route, initialProgress: startProgress, showTime: showTimeInsteadOfDistance)
            isNavigating = true
            passedRouteIndex = -1
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopNavigation() async {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        await activityManager.end()
        isNavigating = false
        navigationBearing = nil
        navigationAlignmentID = nil
        resetDeviationState()
    }

    func rerouteFromCurrentLocation() async {
        guard isNavigating,
              !isRerouting,
              let currentLocation,
              let destination = destinationCoordinate else { return }

        shouldPresentReroutePrompt = false
        deviationState = .rerouting
        do {
            let newRoute = try await repository.makeRoute(from: currentLocation, to: destination)
            route = newRoute
            let newProgress = initialProgress(newRoute)
            progress = newProgress
            passedRouteIndex = -1
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

    func keepCurrentRoute() {
        shouldPresentReroutePrompt = false
        hasAskedForCurrentDeviation = true
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

    private static func mapPlaceSearchResult(_ poi: LandmarkPoiDTO) -> PlaceSearchResult? {
        let coordinatePairs = [
            (poi.pnsLat, poi.pnsLon),
            (poi.noorLat, poi.noorLon)
        ]
        guard let coordinate = coordinatePairs.compactMap({ pair -> Coordinate? in
            let (latitudeText, longitudeText) = pair
            guard let latitudeText, let longitudeText,
                  let latitude = Double(latitudeText),
                  let longitude = Double(longitudeText),
                  (33...39).contains(latitude),
                  (124...132).contains(longitude) else { return nil }
            return Coordinate(latitude: latitude, longitude: longitude)
        }).first else { return nil }
        let address = [poi.upperAddrName, poi.middleAddrName, poi.lowerAddrName, poi.detailAddrName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return PlaceSearchResult(
            id: poi.id ?? "\(poi.name)-\(coordinate.latitude)-\(coordinate.longitude)",
            name: poi.name,
            category: poi.lowerBizName ?? poi.middleBizName ?? poi.upperBizName ?? "장소",
            address: address,
            coordinate: coordinate
        )
    }

    private var startCoordinate: Coordinate? {
        guard let lat = Double(startLatitude), let lon = Double(startLongitude) else { return nil }
        return Coordinate(latitude: lat, longitude: lon)
    }

    private var destinationCoordinate: Coordinate? {
        guard let lat = Double(destinationLatitude), let lon = Double(destinationLongitude) else { return nil }
        return Coordinate(latitude: lat, longitude: lon)
    }

    private let walkingSpeed = 1.25

    private func initialProgress(_ route: WalkingRoute) -> WalkingProgress {
        let firstDistance = route.maneuvers.first.map { Int(route.path.first?.distance(to: $0.coordinate) ?? 0) } ?? route.totalDistance
        return WalkingProgress(
            remainingDistance: route.totalDistance,
            distanceToNextManeuver: firstDistance,
            nextManeuver: route.maneuvers.first,
            isOffRoute: false,
            isApproachingTurn: firstDistance < Int(approachingThreshold),
            estimatedArrival: .now.addingTimeInterval(Double(route.totalDistance) / walkingSpeed)
        )
    }

    private func calculateProgress(at current: Coordinate, route: WalkingRoute) -> WalkingProgress {
        guard let nearest = route.path.enumerated().min(by: {
            $0.element.distance(to: current) < $1.element.distance(to: current)
        }) else { return initialProgress(route) }

        // 목적지 좌표 10m 이내 근접 시 도착 처리
        if let destination = route.path.last {
            let distanceToDestination = Int(current.distance(to: destination))
            if distanceToDestination <= Int(approachingThreshold) {
                return WalkingProgress(
                    remainingDistance: distanceToDestination,
                    distanceToNextManeuver: distanceToDestination,
                    nextManeuver: route.maneuvers.last,
                    isOffRoute: self.isOffRoute,
                    isApproachingTurn: true,
                    estimatedArrival: .now.addingTimeInterval(Double(distanceToDestination) / walkingSpeed)
                )
            }
        }

        let next = route.maneuvers.first { $0.routeIndex >= max(nearest.offset, passedRouteIndex + 1) }
            ?? route.maneuvers.last
        let nextDistance = next.map { Int(current.distance(to: $0.coordinate)) } ?? 0
        let remaining = zip(route.path[nearest.offset...], route.path.dropFirst(nearest.offset + 1))
            .reduce(0.0) { $0 + $1.0.distance(to: $1.1) }

        return WalkingProgress(
            remainingDistance: Int(remaining),
            distanceToNextManeuver: nextDistance,
            nextManeuver: next,
            isOffRoute: self.isOffRoute,
            isApproachingTurn: nextDistance < Int(approachingThreshold),
            estimatedArrival: .now.addingTimeInterval(remaining / walkingSpeed)
        )
    }

    private struct RouteMatch {
        let segmentIndex: Int
        let distance: CLLocationDistance
        let snappedCoordinate: Coordinate
    }
    
    //
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

    private func updateDeviationState(
        at current: Coordinate,
        routeMatch: RouteMatch,
        horizontalAccuracy: CLLocationAccuracy
    ) {
        guard isNavigating, deviationState != .rerouting else { return }

        // 목적지 50m 이내에서는 경로 이탈 감지 비활성화
        if let destination = destinationCoordinate {
            let distToDestination = current.distance(to: destination)
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

    private func appendDeviationCoordinate(_ coordinate: Coordinate) {
        guard deviationPath.last?.distance(to: coordinate) ?? .greatestFiniteMagnitude >= 3 else { return }
        deviationPath.append(coordinate)
    }

    private func resetDeviationState() {
        deviationState = .onRoute
        deviationPath = []
        distanceFromRoute = 0
        consecutiveOffRouteUpdates = 0
        hasAskedForCurrentDeviation = false
        shouldPresentReroutePrompt = false
    }

    private func updateNavigationBearing(at current: Coordinate, route: WalkingRoute) {
        guard isNavigating,
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

    private func bearing(from start: Coordinate, to end: Coordinate) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func smoothedBearing(
        from previous: CLLocationDirection?,
        to candidate: CLLocationDirection
    ) -> CLLocationDirection {
        guard let previous else { return candidate }
        let shortestDelta = (candidate - previous + 540).truncatingRemainder(dividingBy: 360) - 180
        guard abs(shortestDelta) >= 3 else { return previous }
        return (previous + shortestDelta * 0.35 + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension WalkingNavigationViewModel: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 새로 갱신된 좌표
        let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        currentLocation = coordinate
        currentLocationAccuracy = location.horizontalAccuracy
        
        // 사용자가 "현재 위치"를 출발지로 사용하려 할 때, 아직 GPS 좌표를 못 받은 경우의 플래그
        if shouldUseLocationAsStart {
            // 필요 이유
            // 앱을 처음 열었을 때 GPS 좌표가 아직 도착하지 않은 상태에서 사용자가 지도를 탭해 목적지를 선택할 수 있기 떄문
            /// 목적지 선택
            /// → selectCoordinateAsDestination
            /// → setStartFromCurrentLocation
            /// → 이 시점에 currentLocation이 nil
            /// → 출발지를 바로 채울 수 없음
            /// → 플래그를 켜두고 GPS가 오면 그때 채움
            startLatitude = String(location.coordinate.latitude)
            startLongitude = String(location.coordinate.longitude)
            startName = "현재 위치"
            hasSelectedStart = true
            shouldUseLocationAsStart = false
        }
        
        /// 경로를 따라 가는 상황임을 판단
        guard let route else { return }
        
        
        if let routeMatch = matchToRoute(current: coordinate, routePath: route.path) {
            updateDeviationState(
                at: coordinate,
                routeMatch: routeMatch,
                horizontalAccuracy: location.horizontalAccuracy
            )
            
            /// deviation
            if isNavigating, deviationState == .onRoute {
                passedRouteIndex = max(passedRouteIndex, routeMatch.segmentIndex)
            }
        }
        
        // 현재 위치 기준으로 경로 진행 상황(다음 턴, 남은 거리 등) 계산
        let newProgress = calculateProgress(at: coordinate, route: route)
        progress = newProgress
        
        // 내비게이션 중인데 베어링이 아직 없으면 경로 기반으로 카메라 방향 계산
        if isNavigating, navigationBearing == nil {
            updateNavigationBearing(at: coordinate, route: route)
        }
        
        lastManeuverID = lastManeuverID != newProgress.nextManeuver?.id ?  newProgress.nextManeuver?.id : lastManeuverID
        
        Task {
            await activityManager.update(newProgress,
                                         showTime: showTimeInsteadOfDistance)
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
