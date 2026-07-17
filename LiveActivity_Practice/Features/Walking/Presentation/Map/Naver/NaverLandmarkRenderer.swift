//  NaverLandmarkRenderer.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

final class NaverLandmarkRenderer {
    private var landmarkAreas: [NMFCircleOverlay] = []
    private var landmarkConnectors: [NMFPolylineOverlay] = []
    private var landmarkMarkers: [NMFMarker] = []

    func render(landmarks: [MapLandmarkSelection], passedRouteIndex: Int, on mapView: NMFMapView) {
        clearAll()

        for (offset, selection) in landmarks.enumerated() {
            addLandmark(
                index: offset + 1,
                selection: selection,
                isPassed: selection.maneuver.routeIndex <= passedRouteIndex,
                on: mapView
            )
        }
    }

    func clearAll() {
        landmarkAreas.forEach { $0.mapView = nil }
        landmarkConnectors.forEach { $0.mapView = nil }
        landmarkMarkers.forEach { $0.mapView = nil }
        landmarkAreas.removeAll()
        landmarkConnectors.removeAll()
        landmarkMarkers.removeAll()
    }

    private func addLandmark(
        index: Int,
        selection: MapLandmarkSelection,
        isPassed: Bool,
        on mapView: NMFMapView
    ) {
        let landmarkPosition = NMGLatLng(
            lat: selection.landmark.coordinate.latitude,
            lng: selection.landmark.coordinate.longitude
        )
        let maneuverPosition = NMGLatLng(
            lat: selection.maneuver.coordinate.latitude,
            lng: selection.maneuver.coordinate.longitude
        )

        let area = NMFCircleOverlay()
        area.center = landmarkPosition
        area.radius = 15
        let landmarkColor: UIColor = isPassed ? .systemGray : .systemOrange
        area.fillColor = landmarkColor.withAlphaComponent(0.32)
        area.outlineColor = landmarkColor.withAlphaComponent(0.9)
        area.outlineWidth = 2
        area.mapView = mapView
        landmarkAreas.append(area)

        if let connector = NMFPolylineOverlay([maneuverPosition, landmarkPosition]) {
            connector.color = landmarkColor.withAlphaComponent(0.75)
            connector.width = 2
            connector.pattern = [4, 4]
            connector.capType = .round
            connector.joinType = .round
            connector.mapView = mapView
            landmarkConnectors.append(connector)
        }

        let turnMarker = NMFMarker(position: maneuverPosition)
        let turnConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        if let turnImage = UIImage(
            systemName: selection.maneuver.turn.symbolName,
            withConfiguration: turnConfiguration
        )?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal) {
            turnMarker.iconImage = NMFOverlayImage(image: turnImage)
        }
        turnMarker.width = 24
        turnMarker.height = 24
        turnMarker.anchor = CGPoint(x: 0.5, y: 0.5)
        turnMarker.zIndex = 9_000
        turnMarker.mapView = mapView
        landmarkMarkers.append(turnMarker)

        let landmarkMarker = NMFMarker(position: landmarkPosition)
        landmarkMarker.iconImage = NMFOverlayImage(
            image: Self.landmarkBubbleImage(index: index, name: selection.landmark.name, isPassed: isPassed),
            reuseIdentifier: "naver-landmark-\(selection.landmark.id)-\(index)-\(isPassed)"
        )
        landmarkMarker.width = 148
        landmarkMarker.height = 61
        landmarkMarker.anchor = CGPoint(x: 0.5, y: 1)
        landmarkMarker.isForceShowIcon = true
        landmarkMarker.isHideCollidedSymbols = true
        landmarkMarker.zIndex = 10_000 - index
        landmarkMarker.mapView = mapView
        landmarkMarkers.append(landmarkMarker)
    }

    private static func landmarkBubbleImage(index: Int, name: String, isPassed: Bool) -> UIImage {
        let bubble = LandmarkBubbleView(index: index, name: name, isPassed: isPassed)
        bubble.layoutIfNeeded()
        return UIGraphicsImageRenderer(bounds: bubble.bounds).image { context in
            bubble.layer.render(in: context.cgContext)
        }
    }
}
