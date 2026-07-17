//  NaverMapRouteView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

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
        mapView.positionMode = .normal

        context.coordinator.location.setupLocationButton(on: naverMapView, hasRoute: state.route != nil)
        context.coordinator.camera.prepareInitialCamera(location: state.currentLocation, on: mapView)
        return naverMapView
    }

    func updateUIView(_ naverMapView: NMFNaverMapView, context: Context) {
        context.coordinator.update(state: state, on: naverMapView.mapView)
    }

    static func dismantleUIView(_ naverMapView: NMFNaverMapView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class Coordinator {
        let camera = NaverCameraController()
        let route = NaverRouteRenderer()
        let landmark = NaverLandmarkRenderer()
        let location = NaverLocationOverlay()

        private var renderedRoute: WalkingRoute?
        private var renderedPassedRouteIndex = -1

        func update(state: MapPresentationState, on mapView: NMFMapView) {
            location.updateOverlay(
                location: state.currentLocation,
                heading: state.currentHeading,
                on: mapView
            )

            camera.centerOnInitialLocationIfNeeded(state.currentLocation, on: mapView)

            if renderedRoute != state.route || renderedPassedRouteIndex != state.passedRouteIndex {
                let landmarks = state.route?.mapLandmarkSelections() ?? []
                route.render(route: state.route, passedRouteIndex: state.passedRouteIndex, on: mapView)
                landmark.render(landmarks: landmarks, passedRouteIndex: state.passedRouteIndex, on: mapView)
                renderedRoute = state.route
                renderedPassedRouteIndex = state.passedRouteIndex
            }

            route.renderDeviationPath(state.deviationPath, on: mapView)
            location.updateButtonLayout(hasRoute: state.route != nil)

            if camera.handleNavigationAlignment(state: state, on: mapView) { return }
            camera.handleCameraCommand(state: state, on: mapView)
        }

        func tearDown() {
            route.clearAll()
            landmark.clearAll()
            location.tearDown()
        }
    }
}
