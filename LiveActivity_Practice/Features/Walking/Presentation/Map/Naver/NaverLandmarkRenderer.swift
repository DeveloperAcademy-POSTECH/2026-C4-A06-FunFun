//  NaverLandmarkRenderer.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

final class NaverLandmarkRenderer {
    private static let overviewScale: Double = 100
    private static let defaultDetailScale: Double = 20
    private static let landmarkIndexImagePadding: CGFloat = 3
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

    func render(
        landmarks: [MapLandmarkSelection],
        routePath: [Coordinate],
        passedRouteIndex: Int,
        scaleThreshold: Double = 20,
        on mapView: NMFMapView
    ) {
        clearAll()
        detailMinZoom = Self.zoomLevel(forScale: scaleThreshold)
        overviewMinZoom = Self.zoomLevel(forScale: Self.overviewScale)
        let projectedRoutePath = routePath.map {
            mapView.projection.point(
                from: NMGLatLng(lat: $0.latitude, lng: $0.longitude)
            )
        }

        for (offset, selection) in landmarks.enumerated() {
            addLandmark(
                index: offset + 1,
                selection: selection,
                projectedRoutePath: projectedRoutePath,
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
        projectedRoutePath: [CGPoint],
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
            routeIndex: selection.maneuver.routeIndex,
            projectedRoutePath: projectedRoutePath,
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
            reuseIdentifier: "naver-landmark-index-shadow-\(selection.landmark.id)-\(index)-\(isPassed)"
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
        routeIndex: Int,
        projectedRoutePath: [CGPoint],
        on mapView: NMFMapView
    ) -> LandmarkBubbleView.Placement {
        let landmarkPoint = mapView.projection.point(from: landmarkPosition)
        let maneuverPoint = mapView.projection.point(from: maneuverPosition)
        let leftBubbleFrame = bubbleFrame(
            at: landmarkPoint,
            placement: .left
        )
        let rightBubbleFrame = bubbleFrame(
            at: landmarkPoint,
            placement: .right
        )
        let leftIntersectionCount = routeIntersectionCount(
            with: leftBubbleFrame,
            path: projectedRoutePath
        )
        let rightIntersectionCount = routeIntersectionCount(
            with: rightBubbleFrame,
            path: projectedRoutePath
        )

        if leftIntersectionCount != rightIntersectionCount {
            return leftIntersectionCount < rightIntersectionCount ? .left : .right
        }

        let localRoutePath = localRoutePath(
            around: routeIndex,
            in: projectedRoutePath
        )
        let nearestRoutePoint = nearestPoint(
            to: landmarkPoint,
            on: localRoutePath
        ) ?? maneuverPoint
        let horizontalDistance = landmarkPoint.x - nearestRoutePoint.x

        if abs(horizontalDistance) > 1 {
            return horizontalDistance < 0 ? .left : .right
        }

        // 랜드마크가 경로 위에 있는 경우 화면 안쪽 여백이 더 넓은 방향을 사용합니다.
        return landmarkPoint.x >= mapView.bounds.midX ? .left : .right
    }

    private static func bubbleFrame(
        at point: CGPoint,
        placement: LandmarkBubbleView.Placement
    ) -> CGRect {
        let size = LandmarkBubbleView.preferredSize
        let originX = placement == .left
            ? point.x - size.width
            : point.x
        return CGRect(
            x: originX,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func routeIntersectionCount(
        with rect: CGRect,
        path: [CGPoint]
    ) -> Int {
        guard path.count >= 2 else { return 0 }
        let protectedRect = rect.insetBy(dx: -8, dy: -8)

        return (0..<(path.count - 1)).reduce(into: 0) { count, index in
            if segment(
                from: path[index],
                to: path[index + 1],
                intersects: protectedRect
            ) {
                count += 1
            }
        }
    }

    /// Liang-Barsky 알고리즘 방식으로 선분과 사각형의 교차 여부를 계산합니다.
    /// 교차 횟수가 같으면 로컬 경로와 랜드마크의 상대 위치를 보조 기준으로 사용
    private static func segment(
        from start: CGPoint,
        to end: CGPoint,
        intersects rect: CGRect
    ) -> Bool {
        guard start.x.isFinite, start.y.isFinite,
              end.x.isFinite, end.y.isFinite else { return false }

        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1

        let boundaries: [(p: CGFloat, q: CGFloat)] = [
            (-deltaX, start.x - rect.minX),
            (deltaX, rect.maxX - start.x),
            (-deltaY, start.y - rect.minY),
            (deltaY, rect.maxY - start.y)
        ]

        for boundary in boundaries {
            if boundary.p == 0 {
                if boundary.q < 0 { return false }
                continue
            }

            let ratio = boundary.q / boundary.p
            if boundary.p < 0 {
                lowerBound = max(lowerBound, ratio)
            } else {
                upperBound = min(upperBound, ratio)
            }

            if lowerBound > upperBound { return false }
        }

        return true
    }

    private static func localRoutePath(
        around routeIndex: Int,
        in path: [CGPoint]
    ) -> [CGPoint] {
        guard !path.isEmpty else { return [] }

        let clampedIndex = min(max(routeIndex, 0), path.count - 1)
        let lowerBound = max(0, clampedIndex - 2)
        let upperBound = min(path.count - 1, clampedIndex + 2)
        return Array(path[lowerBound...upperBound])
    }

    private static func nearestPoint(
        to point: CGPoint,
        on path: [CGPoint]
    ) -> CGPoint? {
        guard path.count >= 2 else { return path.first }

        var nearestPoint: CGPoint?
        var nearestSquaredDistance = CGFloat.greatestFiniteMagnitude

        for index in 0..<(path.count - 1) {
            let start = path[index]
            let end = path[index + 1]
            guard start.x.isFinite, start.y.isFinite,
                  end.x.isFinite, end.y.isFinite else { continue }

            let segmentX = end.x - start.x
            let segmentY = end.y - start.y
            let squaredLength = segmentX * segmentX + segmentY * segmentY
            let projection: CGFloat

            if squaredLength > 0 {
                projection = min(
                    1,
                    max(
                        0,
                        ((point.x - start.x) * segmentX + (point.y - start.y) * segmentY)
                            / squaredLength
                    )
                )
            } else {
                projection = 0
            }

            let candidate = CGPoint(
                x: start.x + segmentX * projection,
                y: start.y + segmentY * projection
            )
            let deltaX = point.x - candidate.x
            let deltaY = point.y - candidate.y
            let squaredDistance = deltaX * deltaX + deltaY * deltaY

            if squaredDistance < nearestSquaredDistance {
                nearestSquaredDistance = squaredDistance
                nearestPoint = candidate
            }
        }

        return nearestPoint
    }
}
