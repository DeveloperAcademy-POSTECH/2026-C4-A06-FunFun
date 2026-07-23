//  NaverLandmarkRenderer.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

final class NaverLandmarkRenderer {
    private static let overviewScale: Double = 100
    private static let defaultDetailScale: Double = 20
    private static let landmarkIndexImagePadding: CGFloat = 2
    private static var landmarkIndexImageSize: CGSize {
        CGSize(
            width: LandmarkIndexView.preferredSize.width + landmarkIndexImagePadding * 2,
            height: LandmarkIndexView.preferredSize.height + landmarkIndexImagePadding * 2
        )
    }

    /// 축척(m)을 NaverMap 줌 레벨로 변환
    /// 축척이 작을수록(확대) 줌 레벨이 높고, 클수록(축소) 줌 레벨이 낮음
    static func zoomLevel(forScale meters: Double) -> Double {
        // NaverMap: 줌 16 ≈ 25m, 줌 15 ≈ 50m, 줌 14 ≈ 100m (log2 스케일)
        let baseZoom = 15.0  // 50m 기준
        let baseScale = 50.0
        return baseZoom + log2(baseScale / meters)
    }

    private var overviewMinZoom: Double = zoomLevel(forScale: overviewScale)
    private var detailMinZoom: Double = zoomLevel(forScale: defaultDetailScale)
    private var landmarkAreas: [NMFCircleOverlay] = []
    private var landmarkConnectors: [NMFPolylineOverlay] = []
    private var landmarkMarkers: [NMFMarker] = []

    func render(landmarks: [MapLandmarkSelection], passedRouteIndex: Int, scaleThreshold: Double = 20, on mapView: NMFMapView) {
        clearAll()
        detailMinZoom = Self.zoomLevel(forScale: scaleThreshold)
        overviewMinZoom = Self.zoomLevel(forScale: Self.overviewScale)

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
        let detailPlacement = Self.detailPlacement(
            landmarkPosition: landmarkPosition,
            maneuverPosition: maneuverPosition,
            on: mapView
        )

        let area = NMFCircleOverlay()
        area.center = landmarkPosition
        area.radius = 15
        let landmarkColor: UIColor = isPassed
            ? (UIColor(named: "Colors/Gray-gray-500") ?? .systemGray)
            : LandmarkIndexView.defaultAccentColor
        area.fillColor = landmarkColor.withAlphaComponent(0.12)
        area.outlineColor = landmarkColor.withAlphaComponent(0.55)
        area.outlineWidth = 1
        area.minZoom = detailMinZoom
        area.mapView = mapView
        landmarkAreas.append(area)

        if let connector = NMFPolylineOverlay([maneuverPosition, landmarkPosition]) {
            connector.color = landmarkColor.withAlphaComponent(0.75)
            connector.width = 2
            connector.pattern = [4, 4]
            connector.capType = .round
            connector.joinType = .round
            connector.minZoom = detailMinZoom
            connector.mapView = mapView
            landmarkConnectors.append(connector)
        }

        let indexMarker = NMFMarker(position: landmarkPosition)
        indexMarker.iconImage = NMFOverlayImage(
            image: Self.landmarkIndexImage(index: index, isPassed: isPassed),
            reuseIdentifier: "naver-landmark-index-padded-\(selection.landmark.id)-\(index)-\(isPassed)"
        )
        indexMarker.width = Self.landmarkIndexImageSize.width
        indexMarker.height = Self.landmarkIndexImageSize.height
        indexMarker.anchor = CGPoint(x: 0.5, y: 0.5)
        indexMarker.isForceShowIcon = true
        indexMarker.isHideCollidedSymbols = true
        indexMarker.zIndex = 10_000 - index
        indexMarker.minZoom = overviewMinZoom
        indexMarker.maxZoom = detailMinZoom - 0.001
        indexMarker.mapView = mapView
        landmarkMarkers.append(indexMarker)

        let detailMarker = NMFMarker(position: landmarkPosition)
        detailMarker.iconImage = NMFOverlayImage(
            image: Self.landmarkBubbleImage(
                index: index,
                name: selection.landmark.name,
                isPassed: isPassed,
                placement: detailPlacement
            ),
            reuseIdentifier: "naver-landmark-detail-\(selection.landmark.id)-\(index)-\(isPassed)-\(detailPlacement.rawValue)"
        )
        detailMarker.width = LandmarkBubbleView.preferredSize.width
        detailMarker.height = LandmarkBubbleView.preferredSize.height
        detailMarker.anchor = detailPlacement.anchor
        detailMarker.isHideCollidedMarkers = true
        detailMarker.isHideCollidedSymbols = true
        detailMarker.zIndex = 10_000 - index
        detailMarker.minZoom = detailMinZoom
        detailMarker.mapView = mapView
        landmarkMarkers.append(detailMarker)
    }

    private static func landmarkIndexImage(index: Int, isPassed: Bool) -> UIImage {
        let color: UIColor = isPassed
            ? (UIColor(named: "Colors/Gray-gray-500") ?? .systemGray)
            : LandmarkIndexView.defaultAccentColor
        let indexView = LandmarkIndexView(index: index, accentColor: color)
        indexView.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(
            size: landmarkIndexImageSize,
            format: format
        ).image { context in
            context.cgContext.translateBy(
                x: landmarkIndexImagePadding,
                y: landmarkIndexImagePadding
            )
            indexView.layer.render(in: context.cgContext)
        }
    }

    private static func landmarkBubbleImage(
        index: Int,
        name: String,
        isPassed: Bool,
        placement: LandmarkBubbleView.Placement
    ) -> UIImage {
        let bubbleView = LandmarkBubbleView(
            index: index,
            name: name,
            isPassed: isPassed,
            placement: placement
        )
        bubbleView.layoutIfNeeded()
        return UIGraphicsImageRenderer(bounds: bubbleView.bounds).image { context in
            bubbleView.layer.render(in: context.cgContext)
        }
    }

    private static func detailPlacement(
        landmarkPosition: NMGLatLng,
        maneuverPosition: NMGLatLng,
        on mapView: NMFMapView
    ) -> LandmarkBubbleView.Placement {
        let landmarkPoint = mapView.projection.point(from: landmarkPosition)
        let maneuverPoint = mapView.projection.point(from: maneuverPosition)
        let isAboveRoute = landmarkPoint.y <= maneuverPoint.y
        let isLeftOfRoute = landmarkPoint.x <= maneuverPoint.x

        switch (isAboveRoute, isLeftOfRoute) {
        case (true, true):
            return .aboveLeft
        case (true, false):
            return .aboveRight
        case (false, true):
            return .belowLeft
        case (false, false):
            return .belowRight
        }
    }
}
