//  NaverTurnRenderer.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

final class NaverTurnRenderer {
    private static let turnTypes: Set<WalkingTurn> = [.left, .slightLeft, .right, .slightRight]
    private static let passedZoneDistance: Double = 15
    private static let passedZoneRadius: Double = 10

    private var markers: [NMFMarker] = []
    private var detectionAreas: [NMFCircleOverlay] = []
    private var passedZones: [NMFCircleOverlay] = []

    func render(maneuvers: [WalkingManeuver], passedRouteIndex: Int, approachingRadius: Double, routePath: [Coordinate], on mapView: NMFMapView) {
        clearAll()

        for maneuver in maneuvers {
            let isPassed = maneuver.routeIndex <= passedRouteIndex
            addTurnMarker(maneuver: maneuver, isPassed: isPassed, approachingRadius: approachingRadius, on: mapView)
            addPassedZone(maneuver: maneuver, routePath: routePath, on: mapView)
        }
    }

    func clearAll() {
        markers.forEach { $0.mapView = nil }
        detectionAreas.forEach { $0.mapView = nil }
        passedZones.forEach { $0.mapView = nil }
        markers.removeAll()
        detectionAreas.removeAll()
        passedZones.removeAll()
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

    private func addPassedZone(maneuver: WalkingManeuver, routePath: [Coordinate], on mapView: NMFMapView) {
        guard Self.turnTypes.contains(maneuver.turn) else { return }
        let idx = maneuver.routeIndex
        guard idx + 1 < routePath.count else { return }

        let from = maneuver.coordinate
        let to = routePath[idx + 1]
        let dist = from.distance(to: to)
        guard dist > 0 else { return }

        // from → to 방향으로 10m 이동 (선형 보간)
        let ratio = min(Self.passedZoneDistance / dist, 1.0)
        let centerLat = from.latitude + (to.latitude - from.latitude) * ratio
        let centerLng = from.longitude + (to.longitude - from.longitude) * ratio

        let zone = NMFCircleOverlay()
        zone.center = NMGLatLng(lat: centerLat, lng: centerLng)
        zone.radius = Self.passedZoneRadius
        zone.fillColor = UIColor.systemTeal.withAlphaComponent(0.4)
        zone.outlineColor = UIColor.systemTeal.withAlphaComponent(0.6)
        zone.outlineWidth = 1
        zone.zIndex = 90
        zone.mapView = mapView
        passedZones.append(zone)
    }
}
