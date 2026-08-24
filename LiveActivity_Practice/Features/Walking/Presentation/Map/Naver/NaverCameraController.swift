//  NaverCameraController.swift
//  LiveActivity_Practice

import CoreLocation
import NMapsMap

final class NaverCameraController {
    private var lastCameraCommandID: Int?
    private var lastNavigationAlignmentID: Int?
    private(set) var hasCenteredInitialLocation = false

    func prepareInitialCamera(location: Coordinate?, on mapView: NMFMapView) {
        guard let location else { return }
        moveCamera(to: location, zoom: 15, on: mapView, animated: false)
        hasCenteredInitialLocation = true
    }

    func centerOnInitialLocationIfNeeded(_ location: Coordinate?, on mapView: NMFMapView) {
        guard !hasCenteredInitialLocation, let location else { return }
        moveCamera(to: location, zoom: 15, on: mapView, animated: false)
        hasCenteredInitialLocation = true
    }

    /// 네비게이션 중 사용자 방향에 맞춰 카메라를 회전한다.
    /// 처리했으면 `true`를 반환하여 이후 카메라 커맨드를 건너뛸 수 있도록 한다.
    func handleNavigationAlignment(state: MapPresentationState, on mapView: NMFMapView) -> Bool {
        guard state.isNavigating,
              let alignmentID = state.navigationAlignmentID,
              alignmentID != lastNavigationAlignmentID,
              let location = state.currentLocation,
              let bearing = state.navigationBearing else { return false }

        alignRoute(location: location, bearing: bearing, on: mapView)
        lastNavigationAlignmentID = alignmentID
        return true
    }

    @discardableResult
    func alignRoute(
        route: WalkingRoute,
        location: Coordinate,
        navigationBearing: CLLocationDirection?,
        on mapView: NMFMapView
    ) -> Bool {
        guard let bearing = navigationBearing ?? initialBearing(of: route) else { return false }
        alignRoute(location: location, bearing: bearing, on: mapView)
        return true
    }

    private func alignRoute(
        location: Coordinate,
        bearing: CLLocationDirection,
        on mapView: NMFMapView
    ) {
        let position = NMFCameraPosition(
            NMGLatLng(lat: location.latitude, lng: location.longitude),
            zoom: 16,
            tilt: 0,
            heading: bearing
        )
        let update = NMFCameraUpdate(position: position)
        update.animation = .easeOut
        update.animationDuration = 0.4
        mapView.moveCamera(update)
        hasCenteredInitialLocation = true
    }

    private func initialBearing(of route: WalkingRoute) -> CLLocationDirection? {
        guard route.path.count >= 2 else { return nil }

        let lookAheadDistance: CLLocationDistance = 20
        var targetIndex = 0
        var accumulatedDistance: CLLocationDistance = 0
        while targetIndex < route.path.count - 1, accumulatedDistance < lookAheadDistance {
            accumulatedDistance += route.path[targetIndex].distance(to: route.path[targetIndex + 1])
            targetIndex += 1
        }

        guard targetIndex > 0 else { return nil }
        let start = route.path[0]
        let end = route.path[targetIndex]
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    func handleCameraCommand(state: MapPresentationState, on mapView: NMFMapView) {
        guard let command = state.cameraCommand, command.id != lastCameraCommandID else { return }
        switch command.target {
        case .userLocation:
            guard let location = state.currentLocation else { return }
            moveCamera(to: location, zoom: 15, on: mapView, animated: true)
            hasCenteredInitialLocation = true
        case .route:
            if let route = state.route, route.path.count >= 2 {
                let points = route.path.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }
                let update = NMFCameraUpdate(
                    fit: NMGLatLngBounds(latLngs: points),
                    paddingInsets: UIEdgeInsets(top: 180, left: 45, bottom: 230, right: 45)
                )
                update.animation = .easeOut
                mapView.moveCamera(update)
            }
        case let .coordinate(coordinate):
            moveCamera(to: coordinate, zoom: 16, on: mapView, animated: true)
            hasCenteredInitialLocation = true
        }
        lastCameraCommandID = command.id
    }

    func moveCamera(to coordinate: Coordinate, zoom: Double, on mapView: NMFMapView, animated: Bool) {
        let update = NMFCameraUpdate(
            scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude),
            zoomTo: zoom
        )
        update.animation = animated ? .easeOut : .none
        mapView.moveCamera(update)
    }
}
