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
        lastNavigationAlignmentID = alignmentID
        return true
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
