//  NaverTurnRenderer.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

final class NaverTurnRenderer {
    private var markers: [NMFMarker] = []
    private var detectionAreas: [NMFCircleOverlay] = []

    func render(maneuvers: [WalkingManeuver], passedRouteIndex: Int, approachingRadius: Double, on mapView: NMFMapView) {
        clearAll()

        for maneuver in maneuvers {
            let isPassed = maneuver.routeIndex <= passedRouteIndex
            addTurnMarker(maneuver: maneuver, isPassed: isPassed, approachingRadius: approachingRadius, on: mapView)
        }
    }

    func clearAll() {
        markers.forEach { $0.mapView = nil }
        detectionAreas.forEach { $0.mapView = nil }
        markers.removeAll()
        detectionAreas.removeAll()
    }

    private func addTurnMarker(maneuver: WalkingManeuver, isPassed: Bool, approachingRadius: Double, on mapView: NMFMapView) {
        let position = NMGLatLng(
            lat: maneuver.coordinate.latitude,
            lng: maneuver.coordinate.longitude
        )

        let areaColor: UIColor = isPassed ? .systemGray : .systemBlue
        let area = NMFCircleOverlay()
        area.center = position
        area.radius = approachingRadius
        area.fillColor = areaColor.withAlphaComponent(0.12)
        area.outlineColor = areaColor.withAlphaComponent(0.4)
        area.outlineWidth = 1
        area.mapView = mapView
        detectionAreas.append(area)

        let marker = NMFMarker(position: position)
        let markerColor: UIColor = isPassed ? .systemGray : .systemBlue
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        if let symbolImage = UIImage(
            systemName: maneuver.turn.symbolName,
            withConfiguration: configuration
        )?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            let backgroundSize = CGSize(width: 28, height: 28)
            let image = UIGraphicsImageRenderer(size: backgroundSize).image { context in
                markerColor.setFill()
                UIBezierPath(
                    roundedRect: CGRect(origin: .zero, size: backgroundSize),
                    cornerRadius: 8
                ).fill()
                let symbolSize = symbolImage.size
                let origin = CGPoint(
                    x: (backgroundSize.width - symbolSize.width) / 2,
                    y: (backgroundSize.height - symbolSize.height) / 2
                )
                symbolImage.draw(at: origin)
            }
            marker.iconImage = NMFOverlayImage(image: image)
        }
        marker.width = 28
        marker.height = 28
        marker.anchor = CGPoint(x: 0.5, y: 0.5)
        marker.zIndex = 8_000
        marker.mapView = mapView
        markers.append(marker)
    }
}
