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
    
    private(set) var viewState: ViewState = .main
    
    // 모듈
    let bearingTracker = BearingTracker()
    let routeTracker: RouteTracker
    let routeSearchService: RouteSearchService
    let navigationSession: NavigationSession
    let mockLocation = MockLocationController()

    // 장소 선택
    var start: Place?
    var destination: Place?
    private(set) var selectedPlace: Place?
    
    // 위치
    private(set) var currentLocation: Coordinate?
    private(set) var currentHeading: CLLocationDirection?
    private(set) var currentLocationAccuracy: CLLocationAccuracy?
    private(set) var navigationAlignmentID: Int?
    
    var errorMessage: String?
    
    // UI 설정
    var showTimeInsteadOfDistance = false
    var showLandmarks = true
    var landmarkMinZoom: Double = 20
    var approachingThreshold: Double = 20 {
        didSet { routeTracker.approachingThreshold = approachingThreshold }
    }

    // 개발자용
    var showTurnMarkers = false
    var showRoutePoints = false
    var routePointRadius: Double = 10
    var showGradientOverlay = true
    
    var landmarkCount: Int {
        guard let route = routeSearchService.route else { return 0 }
        return Set(route.maneuvers.compactMap { $0.landmark?.id }).count
    }
    
    private let locationManager = CLLocationManager()
    private var shouldTrackLocation = false
    private var navigationAlignmentSequence = 0
    
    // MARK: - Init
    
    init(
        repository: WalkingRouteRepositoryProtocol = WalkingRouteRepository(),
        activityManager: WalkingLiveActivityManager? = nil
    ) {
        self.routeTracker = RouteTracker(approachingThreshold: 20)
        self.routeSearchService = RouteSearchService(repository: repository)
        self.navigationSession = NavigationSession(activityManager: activityManager)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 2
        locationManager.activityType = .fitness

        mockLocation.routePathProvider = { [weak self] in
            self?.routeSearchService.route?.path ?? []
        }
        mockLocation.onUpdate = { [weak self] coordinate, heading in
            guard let self else { return }
            self.currentHeading = heading
            self.applyLocation(coordinate, accuracy: 5)
        }
    }
    
    // MARK: - 장소 선택
    
    func placeSelected(_ place: Place) {
        selectedPlace = place
    }
    
    func clearSelectedPlace() {
        selectedPlace = nil
    }
    
    func mainMode() {
        viewState = .main
        clearSelectedPlace()
    }
    
    func setStartFromCurrentLocation() {
        guard let location = currentLocation else { return }
        start = Place(id: "", name: "현재 위치", category: "", address: "",
                      coordinate: Coordinate(
                        latitude: location.latitude,
                        longitude: location.longitude))
    }
    
    // MARK: - 경로 탐색 (조합)
    
    func searchRoute() async {
        setStartFromCurrentLocation()
        if destination == nil, let selectedPlace {
            destination = selectedPlace
        }
        
        guard let start = start, let destination = destination else {
            errorMessage = "검색 결과에서 출발지와 목적지를 선택해 주세요."
            return
        }
        viewState = .loading
        errorMessage = nil
        do {
            try await routeSearchService.search(from: start.coordinate, to: destination.coordinate)
            if let route = routeSearchService.route {
                routeTracker.setInitialProgress(for: route)
            }
            selectedPlace = nil
            viewState = .routePreview
        } catch {
            errorMessage = error.localizedDescription
            viewState = .main
        }
    }

    func dismissRoute() async {
        if viewState == .navigating {
            await stopNavigation()
        }
        routeSearchService.dismiss()
        routeTracker.reset()
        bearingTracker.reset()
        selectedPlace = nil
        destination = nil
        errorMessage = nil
        startLocationTracking()
    }

    // MARK: - 내비게이션 (조합)

    func startNavigating() async {
        guard let route = routeSearchService.route, let destination = destination else { return }
        do {
            let startProgress = routeTracker.initialProgress(for: route)
            try await navigationSession.start(
                destinationName: destination.name,
                route: route,
                initialProgress: startProgress,
                showTime: showTimeInsteadOfDistance
            )
            routeTracker.setInitialProgress(for: route)
            bearingTracker.reset()
            if let currentLocation {
                bearingTracker.update(
                    at: currentLocation,
                    route: route,
                    accuracy: currentLocationAccuracy ?? .greatestFiniteMagnitude
                )
            }
            if bearingTracker.bearing == nil {
                bearingTracker.updateFromRouteStart(route)
            }
            navigationAlignmentSequence += 1
            navigationAlignmentID = navigationAlignmentSequence
            locationManager.requestWhenInUseAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.pausesLocationUpdatesAutomatically = false
            if !mockLocation.isEnabled {
                locationManager.startUpdatingLocation()
                locationManager.startUpdatingHeading()
            }
            viewState = .navigating
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stopNavigation() async {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        await navigationSession.stop()
        bearingTracker.reset()
        navigationAlignmentID = nil
        routeTracker.reset()
    }
    
    func refreshLiveActivity() {
        guard let progress = routeTracker.progress else { return }
        Task {
            await navigationSession.updateActivity(progress, showTime: showTimeInsteadOfDistance)
        }
    }
    
    // MARK: - 경로 이탈 (조합)
    
    func keepCurrentRoute() {
        routeTracker.keepCurrentRoute()
    }
    
    func rerouteFromCurrentLocation() async {
        guard viewState == .navigating,
              !routeTracker.isRerouting,
              let currentLocation,
              let destination = destination else { return }
        
        routeTracker.shouldPresentReroutePrompt = false
        routeTracker.startRerouting()
        do {
            try await routeSearchService.search(from: currentLocation, to: destination.coordinate)
            guard let route = routeSearchService.route else { return }
            routeTracker.resetAfterReroute(newRoute: route)
            bearingTracker.reset()
            bearingTracker.update(
                at: currentLocation,
                route: route,
                accuracy: currentLocationAccuracy ?? .greatestFiniteMagnitude
            )
            navigationAlignmentSequence += 1
            navigationAlignmentID = navigationAlignmentSequence
            if let progress = routeTracker.progress {
                await navigationSession.updateActivity(progress, showTime: showTimeInsteadOfDistance)
            }
        } catch {
            routeTracker.rerouteFailed()
            errorMessage = "경로를 다시 찾지 못했습니다: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 위치 갱신 (실제 GPS / 리모콘 공통)

    /// 실제 GPS와 디버그 리모콘이 공유하는 위치 반영 지점
    private func applyLocation(_ coordinate: Coordinate, accuracy: CLLocationAccuracy) {
        currentLocation = coordinate
        currentLocationAccuracy = accuracy

        guard let route = routeSearchService.route else { return }

        routeTracker.update(
            at: coordinate,
            route: route,
            destination: destination?.coordinate ?? route.path.last ?? coordinate,
            horizontalAccuracy: accuracy,
            isNavigating: viewState == .navigating
        )

        if viewState == .navigating, bearingTracker.bearing == nil {
            bearingTracker.update(
                at: coordinate,
                route: route,
                accuracy: accuracy
            )
        }

        if let progress = routeTracker.progress {
            Task {
                await navigationSession.updateActivity(progress, showTime: showTimeInsteadOfDistance)
            }
        }

        // 도착 감지 → 5초 후 자동 종료
        if let progress = routeTracker.progress,
           progress.nextManeuver?.turn == .destination,
           progress.isApproachingTurn,
           !navigationSession.isArrived {
            navigationSession.markArrived()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await dismissRoute()
            }
        }
    }

    // MARK: - 디버그 위치 리모콘

    /// 실내 테스트용. 실제 GPS 대신 리모콘으로 위치를 조작한다.
    func enableMockLocation() {
        guard !mockLocation.isEnabled else { return }
        let seed = currentLocation
            ?? routeSearchService.route?.path.first
            ?? Coordinate(latitude: 36.0141, longitude: 129.3225) // 포스텍
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        mockLocation.enable(at: seed, heading: currentHeading ?? 0)
    }

    func disableMockLocation() {
        guard mockLocation.isEnabled else { return }
        mockLocation.disable()
        requestLocationAccess()
    }

    func toggleMockLocation() {
        mockLocation.isEnabled ? disableMockLocation() : enableMockLocation()
    }

    // MARK: - 위치 권한

    func startLocationTracking() {
        shouldTrackLocation = true
        requestLocationAccess()
    }
    
    private func requestLocationAccess() {
        guard !mockLocation.isEnabled else { return } // 리모콘 사용 중에는 실제 위치 추적을 켜지 않는다
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
        guard !mockLocation.isEnabled else { return } // 리모콘 조작 중에는 실제 GPS를 무시
        guard let location = locations.last else { return }

        applyLocation(
            Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            accuracy: location.horizontalAccuracy
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !mockLocation.isEnabled else { return }
        errorMessage = "위치를 가져오지 못했습니다: \(error.localizedDescription)"
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocationAccess()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard !mockLocation.isEnabled else { return }
        currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}

private extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
