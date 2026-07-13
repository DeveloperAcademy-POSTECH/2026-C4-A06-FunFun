import Combine
import CoreLocation
import Foundation

@MainActor
final class WalkingNavigationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum SearchTarget { case start, destination }

    @Published var startName = ""
    @Published var startLatitude = "37.497942"
    @Published var startLongitude = "127.027621"
    @Published var destinationLatitude = "37.491902"
    @Published var destinationLongitude = "127.031812"
    @Published var destinationName = ""
    @Published private(set) var placeSearchResults: [PlaceSearchResult] = []
    @Published private(set) var isSearchingPlaces = false
    @Published private(set) var hasSelectedStart = false
    @Published private(set) var hasSelectedDestination = false
    @Published private(set) var route: WalkingRoute?
    @Published private(set) var progress: WalkingProgress?
    @Published private(set) var currentLocation: Coordinate?
    @Published private(set) var currentHeading: CLLocationDirection?
    @Published private(set) var currentLocationAccuracy: CLLocationAccuracy?
    @Published private(set) var isLoading = false
    @Published private(set) var isNavigating = false
    @Published var errorMessage: String?

    private let repository: WalkingRouteRepositoryProtocol
    private let placeSearchClient: TMAPClientProtocol
    private let activityManager: WalkingLiveActivityManager
    private let locationManager = CLLocationManager()
    private var lastActivityUpdate = Date.distantPast
    private var lastManeuverID: Int?
    private var shouldTrackLocation = false
    private var shouldUseLocationAsStart = false

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
        locationManager.distanceFilter = 5
        locationManager.headingFilter = 5
        locationManager.activityType = .fitness
    }

    func useCurrentLocation() {
        shouldTrackLocation = false
        shouldUseLocationAsStart = true
        requestLocationAccess()
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
        errorMessage = nil
    }

    func searchPlaces(keyword: String) async {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword.count >= 2 else {
            placeSearchResults = []
            return
        }

        isSearchingPlaces = true
        defer { isSearchingPlaces = false }
        do {
            let response = try await placeSearchClient.searchPlaces(keyword: keyword, near: currentLocation)
            placeSearchResults = response.searchPoiInfo.pois.poi.compactMap(Self.mapPlaceSearchResult)
        } catch is CancellationError {
            return
        } catch {
            placeSearchResults = []
            errorMessage = "장소를 검색하지 못했습니다: \(error.localizedDescription)"
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
        }
        placeSearchResults = []
        errorMessage = nil
    }

    func clearPlaceSearchResults() {
        placeSearchResults = []
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startNavigation() async {
        guard let route else { return }
        do {
            try await activityManager.start(destinationName: destinationName, route: route)
            isNavigating = true
            locationManager.requestWhenInUseAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
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
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        currentLocation = coordinate
        currentLocationAccuracy = location.horizontalAccuracy
        if location.course >= 0 {
            currentHeading = location.course
        }

        if shouldUseLocationAsStart {
            startLatitude = String(location.coordinate.latitude)
            startLongitude = String(location.coordinate.longitude)
            startName = "현재 위치"
            hasSelectedStart = true
            shouldUseLocationAsStart = false
        }
        guard let route else { return }
        let newProgress = calculateProgress(at: coordinate, route: route)
        progress = newProgress

        let maneuverChanged = lastManeuverID != newProgress.nextManeuver?.id
        let enoughTimePassed = Date.now.timeIntervalSince(lastActivityUpdate) >= 15
        if maneuverChanged || enoughTimePassed || newProgress.isOffRoute {
            lastManeuverID = newProgress.nextManeuver?.id
            lastActivityUpdate = .now
            Task { await activityManager.update(newProgress) }
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

    private func initialProgress(_ route: WalkingRoute) -> WalkingProgress {
        WalkingProgress(
            remainingDistance: route.totalDistance,
            distanceToNextManeuver: route.maneuvers.first.map { Int(route.path.first?.distance(to: $0.coordinate) ?? 0) } ?? route.totalDistance,
            nextManeuver: route.maneuvers.first,
            isOffRoute: false
        )
    }

    private func calculateProgress(at current: Coordinate, route: WalkingRoute) -> WalkingProgress {
        guard let nearest = route.path.enumerated().min(by: {
            $0.element.distance(to: current) < $1.element.distance(to: current)
        }) else { return initialProgress(route) }

        let isOffRoute = nearest.element.distance(to: current) > 25
        let next = route.maneuvers.first { $0.routeIndex > nearest.offset }
        let nextDistance = next.map { Int(current.distance(to: $0.coordinate)) } ?? 0
        let remaining = zip(route.path[nearest.offset...], route.path.dropFirst(nearest.offset + 1))
            .reduce(0.0) { $0 + $1.0.distance(to: $1.1) }

        return WalkingProgress(
            remainingDistance: Int(remaining),
            distanceToNextManeuver: nextDistance,
            nextManeuver: next,
            isOffRoute: isOffRoute
        )
    }
}
