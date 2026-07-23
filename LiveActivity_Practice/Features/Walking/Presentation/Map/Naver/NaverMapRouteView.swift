//  NaverMapRouteView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import NMapsMap
import SwiftUI

struct NaverMapRouteView: UIViewRepresentable {
    let state: MapPresentationState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)
        let mapView = naverMapView.mapView
        naverMapView.showCompass = false
        naverMapView.showScaleBar = false
        naverMapView.showZoomControls = false
        naverMapView.showLocationButton = false
        mapView.locationOverlay.icon = NMFOverlayImage(name: "indicator")
        mapView.positionMode = .normal
        mapView.touchDelegate = context.coordinator
        mapView.addCameraDelegate(delegate:context.coordinator)
        mapView.logoAlign = .leftTop

        context.coordinator.onMapViewportChanged = state.onMapViewportChanged
        context.coordinator.updateCurrentLocation(state.currentLocation, on: mapView)
        context.coordinator.location.setupLocationButton(
            on: naverMapView,
            bottomInset: state.locationButtonBottomInset
        )
        context.coordinator.camera.prepareInitialCamera(location: state.currentLocation, on: mapView)
        return naverMapView
    }

    func updateUIView(_ naverMapView: NMFNaverMapView, context: Context) {
        context.coordinator.onMapTapped = state.onMapTapped
        context.coordinator.onMapViewportChanged = state.onMapViewportChanged
        context.coordinator.update(state: state, on: naverMapView.mapView)
    }

    static func dismantleUIView(_ naverMapView: NMFNaverMapView, coordinator: Coordinator) {
        naverMapView.mapView.removeCameraDelegate(delegate:coordinator)
        coordinator.tearDown()
    }

    final class Coordinator: NSObject, NMFMapViewTouchDelegate, NMFMapViewCameraDelegate {
        let camera = NaverCameraController()
        let route = NaverRouteRenderer()
        let landmark = NaverLandmarkRenderer()
        let turn = NaverTurnRenderer()
        let location = NaverLocationOverlay()
        let destinationPreview = NaverDestinationPreviewRenderer()
        var onMapTapped: ((Coordinate) -> Void)?
        var onMapViewportChanged: ((CLLocationDirection, CGPoint?) -> Void)?

        private var renderedRoute: WalkingRoute?
        private var renderedPassedRouteIndex = -1
        private var renderedShowLandmarks = true
        private var renderedLandmarkScale: Double = 50
        private var renderedShowTurnMarkers = false
        private var renderedApproachingThreshold: Double = 10
        private var currentLocation: Coordinate?
        private var lastReportedViewport: MapViewportSnapshot?

        func mapView(_ mapView: NMFMapView, didTapMap latlng: NMGLatLng, point: CGPoint) {
            onMapTapped?(Coordinate(latitude: latlng.lat, longitude: latlng.lng))
        }

        func mapView(_ mapView: NMFMapView, cameraIsChangingByReason reason: Int) {
            reportMapViewport(from: mapView)
        }

        func mapView(
            _ mapView: NMFMapView,
            cameraDidChangeByReason reason: Int,
            animated: Bool
        ) {
            reportMapViewport(from: mapView)
            refreshLandmarkPlacement(on: mapView)
        }

        private func reportMapViewport(from mapView: NMFMapView) {
            let heading = mapView.cameraPosition.heading
            let position = currentLocation.flatMap { location -> CGPoint? in
                let point = mapView.projection.point(
                    from: NMGLatLng(
                        lat: location.latitude,
                        lng: location.longitude
                    )
                )
                return point.x.isFinite && point.y.isFinite ? point : nil
            }
            let viewport = MapViewportSnapshot(
                heading: heading,
                indicatorPosition: position
            )
            guard viewport != lastReportedViewport else { return }
            lastReportedViewport = viewport
            onMapViewportChanged?(heading, position)
        }

        private func refreshLandmarkPlacement(on mapView: NMFMapView) {
            guard renderedShowLandmarks, let renderedRoute else { return }

            landmark.render(
                landmarks: renderedRoute.mapLandmarkSelections(),
                routePath: renderedRoute.path,
                passedRouteIndex: renderedPassedRouteIndex,
                scaleThreshold: renderedLandmarkScale,
                on: mapView
            )
        }

        func updateCurrentLocation(_ location: Coordinate?, on mapView: NMFMapView) {
            guard location != currentLocation else { return }
            currentLocation = location
            DispatchQueue.main.async { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.reportMapViewport(from: mapView)
            }
        }

        func update(state: MapPresentationState, on mapView: NMFMapView) {
            updateCurrentLocation(state.currentLocation, on: mapView)
            location.updateOverlay(
                location: state.currentLocation,
                heading: state.currentHeading,
                on: mapView
            )

            camera.centerOnInitialLocationIfNeeded(state.currentLocation, on: mapView)
            destinationPreview.render(place: state.previewDestination, on: mapView)

            if renderedRoute != state.route || renderedPassedRouteIndex != state.passedRouteIndex || renderedShowLandmarks != state.showLandmarks || renderedLandmarkScale != state.landmarkScaleThreshold || renderedShowTurnMarkers != state.showTurnMarkers || renderedApproachingThreshold != state.approachingThreshold {
                route.render(route: state.route, passedRouteIndex: state.passedRouteIndex, on: mapView)
                if state.showLandmarks {
                    let landmarks = state.route?.mapLandmarkSelections() ?? []
                    landmark.render(
                        landmarks: landmarks,
                        routePath: state.route?.path ?? [],
                        passedRouteIndex: state.passedRouteIndex,
                        scaleThreshold: state.landmarkScaleThreshold,
                        on: mapView
                    )
                } else {
                    landmark.clearAll()
                }
                if state.showTurnMarkers {
                    let maneuvers = state.route?.maneuvers ?? []
                    turn.render(maneuvers: maneuvers, passedRouteIndex: state.passedRouteIndex, approachingRadius: state.approachingThreshold, on: mapView)
                } else {
                    turn.clearAll()
                }
                renderedRoute = state.route
                renderedPassedRouteIndex = state.passedRouteIndex
                renderedShowLandmarks = state.showLandmarks
                renderedLandmarkScale = state.landmarkScaleThreshold
                renderedShowTurnMarkers = state.showTurnMarkers
                renderedApproachingThreshold = state.approachingThreshold
            }

            route.renderDeviationPath(state.deviationPath, on: mapView)
            location.updateButtonLayout(
                bottomInset: state.locationButtonBottomInset
            )

            if camera.handleNavigationAlignment(state: state, on: mapView) { return }
            camera.handleCameraCommand(state: state, on: mapView)
        }

        func tearDown() {
            route.clearAll()
            landmark.clearAll()
            turn.clearAll()
            location.tearDown()
            destinationPreview.clear()
        }
    }
}

private struct MapViewportSnapshot: Equatable {
    let heading: CLLocationDirection
    let indicatorPosition: CGPoint?
}
