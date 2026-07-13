import CoreLocation
import SwiftUI
import TMapSDK
import TMapSDK.VSMModule
import UIKit

struct TMapRouteView: UIViewRepresentable {
    let state: MapPresentationState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> TMapView {
        let mapView = TMapView(frame: .zero)
        let appKey = Bundle.main.object(forInfoDictionaryKey: "TMAP_APP_KEY") as? String ?? ""
        mapView.setApiKey(appKey)
        mapView.setCenter(
            state.currentLocation?.clCoordinate
                ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        )
        mapView.setZoom(14)
        mapView.isShowCompass = false
        mapView.vsmMapView?.showScaleBar = false
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: TMapView, context: Context) {
        context.coordinator.updateUserMarker(
            location: state.currentLocation,
            heading: state.currentHeading,
            accuracy: state.currentLocationAccuracy,
            on: mapView
        )

        if context.coordinator.renderedRoute != state.route {
            context.coordinator.render(state.route, on: mapView)
        }
        context.coordinator.applyCamera(state: state, on: mapView)
    }

    static func dismantleUIView(_ mapView: TMapView, coordinator: Coordinator) {
        coordinator.tearDown(on: mapView)
    }

    final class Coordinator: NSObject, TMapViewDelegate {
        weak var mapView: TMapView?
        var renderedRoute: WalkingRoute?
        private var centeredLocation: Coordinate?
        private var latestState: MapPresentationState?
        private var isMapReady = false
        private var isFollowingUserLocation = false
        private var lastCameraCommandID: Int?
        private var userMarker: TMapMarker?
        private var userHeadingMarker: TMapMarker?
        private var userAccuracyCircle: TMapCircle?
        private var routeLine: TMapPolyline?
        private var routeMarkers: [TMapMarker] = []
        private var landmarkAreas: [TMapCircle] = []
        private var landmarkConnectors: [TMapPolyline] = []
        private var landmarkOverlays: [String: (coordinate: CLLocationCoordinate2D, view: LandmarkOverlayView)] = [:]

        @MainActor
        func tearDown(on mapView: TMapView) {
            userMarker?.map = nil
            userHeadingMarker?.map = nil
            userAccuracyCircle?.map = nil
            routeLine?.map = nil
            routeMarkers.forEach { $0.map = nil }
            landmarkAreas.forEach { $0.map = nil }
            landmarkConnectors.forEach { $0.map = nil }
            landmarkOverlays.values.forEach { $0.view.removeFromSuperview() }
            mapView.delegate = nil

            userMarker = nil
            userHeadingMarker = nil
            userAccuracyCircle = nil
            routeLine = nil
            routeMarkers.removeAll()
            landmarkAreas.removeAll()
            landmarkConnectors.removeAll()
            landmarkOverlays.removeAll()
            latestState = nil
        }

        @MainActor
        func applyCamera(state: MapPresentationState, on mapView: TMapView) {
            latestState = state
            guard isMapReady else { return }

            if let command = state.cameraCommand,
               command.id != lastCameraCommandID {
                switch command.target {
                case .userLocation:
                    guard let location = state.currentLocation else { return }
                    mapView.animateTo(location: location.clCoordinate)
                    centeredLocation = location
                    isFollowingUserLocation = true
                case .route:
                    guard let routeLine else { return }
                    mapView.fitMapBoundsWithPolylines(
                        [routeLine],
                        inset: UIEdgeInsets(top: 180, left: 45, bottom: 230, right: 45)
                    )
                    isFollowingUserLocation = false
                }
                lastCameraCommandID = command.id
                return
            }

            if isFollowingUserLocation,
               let location = state.currentLocation,
               centeredLocation != location {
                mapView.animateTo(location: location.clCoordinate)
                centeredLocation = location
            }
        }

        @MainActor
        func render(_ route: WalkingRoute?, on mapView: TMapView) {
            routeLine?.map = nil
            routeMarkers.forEach { $0.map = nil }
            landmarkAreas.forEach { $0.map = nil }
            landmarkConnectors.forEach { $0.map = nil }
            landmarkOverlays.values.forEach { $0.view.removeFromSuperview() }
            routeLine = nil
            routeMarkers.removeAll()
            landmarkAreas.removeAll()
            landmarkConnectors.removeAll()
            landmarkOverlays.removeAll()
            renderedRoute = route

            guard let route, route.path.count >= 2 else { return }

            let polyline = TMapPolyline(coordinates: route.path.map(\.clCoordinate))
            polyline.strokeColor = .systemBlue
            polyline.strokeWidth = 7
            polyline.opacity = 0.9
            polyline.map = mapView
            routeLine = polyline

            if let start = route.path.first {
                addRouteMarker(title: "출발지", coordinate: start.clCoordinate, color: .systemGreen, on: mapView)
            }
            if let end = route.path.last {
                addRouteMarker(title: "목적지", coordinate: end.clCoordinate, color: .systemRed, on: mapView)
            }

            for (offset, selection) in route.mapLandmarkSelections().enumerated() {
                let coordinate = selection.landmark.coordinate.clCoordinate
                let cornerCoordinate = selection.maneuver.coordinate.clCoordinate
                let area = TMapCircle(position: coordinate, radius: 15)
                area.fillColor = UIColor.systemOrange.withAlphaComponent(0.32)
                area.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
                area.strokeWidth = 2
                area.map = mapView
                landmarkAreas.append(area)

                let connector = TMapPolyline(coordinates: [cornerCoordinate, coordinate])
                connector.strokeColor = UIColor.systemOrange.withAlphaComponent(0.75)
                connector.strokeWidth = 2
                connector.opacity = 0.8
                connector.map = mapView
                landmarkConnectors.append(connector)

                addTurnMarker(
                    turn: selection.maneuver.turn,
                    coordinate: cornerCoordinate,
                    on: mapView
                )

                let overlay = LandmarkOverlayView(index: offset + 1, name: selection.landmark.name)
                overlay.isUserInteractionEnabled = false
                mapView.addSubview(overlay)
                landmarkOverlays[selection.landmark.id] = (coordinate, overlay)
            }

            mapView.fitMapBoundsWithPolylines(
                [polyline],
                inset: UIEdgeInsets(top: 180, left: 45, bottom: 230, right: 45)
            )
            updateLandmarkOverlayPositions(on: mapView)
        }

        @MainActor
        private func addRouteMarker(
            title: String,
            coordinate: CLLocationCoordinate2D,
            color: UIColor,
            on mapView: TMapView
        ) {
            let marker = TMapMarker(position: coordinate)
            marker.title = title
            let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
            marker.icon = UIImage(systemName: "mappin.circle.fill", withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
            marker.isUseImage = true
            marker.map = mapView
            routeMarkers.append(marker)
        }

        @MainActor
        private func addTurnMarker(
            turn: WalkingTurn,
            coordinate: CLLocationCoordinate2D,
            on mapView: TMapView
        ) {
            let marker = TMapMarker(position: coordinate)
            let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            marker.icon = UIImage(systemName: turn.symbolName, withConfiguration: configuration)?
                .withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
            marker.isUseImage = true
            marker.showPriority = 9_000
            marker.map = mapView
            routeMarkers.append(marker)
        }

        @MainActor
        func updateUserMarker(
            location: Coordinate?,
            heading: CLLocationDirection?,
            accuracy: CLLocationAccuracy?,
            on mapView: TMapView
        ) {
            guard let location else {
                userMarker?.map = nil
                userMarker = nil
                userHeadingMarker?.map = nil
                userHeadingMarker = nil
                userAccuracyCircle?.map = nil
                userAccuracyCircle = nil
                return
            }

            if let accuracy, accuracy >= 0 {
                let circle = userAccuracyCircle
                    ?? TMapCircle(position: location.clCoordinate, radius: max(1, Int(accuracy.rounded())))
                circle.position = location.clCoordinate
                circle.radius = max(1, Int(accuracy.rounded()))
                circle.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
                circle.strokeColor = UIColor.systemBlue.withAlphaComponent(0.24)
                circle.strokeWidth = 1
                circle.showPriority = 9_998
                circle.map = mapView
                userAccuracyCircle = circle
            } else {
                userAccuracyCircle?.map = nil
                userAccuracyCircle = nil
            }

            let headingMarker = userHeadingMarker ?? TMapMarker(position: location.clCoordinate)
            headingMarker.position = location.clCoordinate
            headingMarker.icon = Self.userHeadingImage(heading: heading ?? 0)
            headingMarker.isUseImage = true
            // TMapMarker의 rotation은 이미지 중심이 아닌 마커 앵커를 기준으로
            // 동작하므로 사용하지 않는다. 방향 이미지를 중심축에서 직접 회전한다.
            headingMarker.rotation = 0
            headingMarker.showPriority = 9_999
            headingMarker.map = mapView
            userHeadingMarker = headingMarker

            let marker = userMarker ?? TMapMarker(position: location.clCoordinate)
            marker.position = location.clCoordinate
            marker.icon = Self.userLocationDotImage
            marker.isUseImage = true
            marker.rotation = 0
            marker.title = "내 위치"
            marker.showPriority = 10_000
            marker.map = mapView
            userMarker = marker
        }

        /// 회전하는 방향 부채꼴. 위치 원과 분리해 원의 중심은 항상 고정한다.
        private static func userHeadingImage(heading: CLLocationDirection) -> UIImage {
            let size = CGSize(width: 64, height: 64)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let cg = context.cgContext
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // 나침반 방위각(북쪽 0°, 시계 방향)을 이미지 중심에서 회전한다.
                cg.translateBy(x: center.x, y: center.y)
                cg.rotate(by: CGFloat(heading * .pi / 180))
                cg.translateBy(x: -center.x, y: -center.y)

                let cone = UIBezierPath()
                cone.move(to: CGPoint(x: center.x, y: 3))
                cone.addLine(to: CGPoint(x: center.x - 15, y: center.y + 3))
                cone.addQuadCurve(
                    to: CGPoint(x: center.x + 15, y: center.y + 3),
                    controlPoint: CGPoint(x: center.x, y: center.y - 5)
                )
                cone.close()
                cg.saveGState()
                cone.addClip()
                let colors = [
                    UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
                    UIColor.systemBlue.withAlphaComponent(0.42).cgColor
                ] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                    cg.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: center.x, y: 3),
                        end: center,
                        options: []
                    )
                }
                cg.restoreGState()
            }.withRenderingMode(.alwaysOriginal)
        }

        /// 회전하지 않는 Apple Maps 스타일의 현재 위치 원.
        private static let userLocationDotImage: UIImage = {
            let size = CGSize(width: 64, height: 64)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let cg = context.cgContext
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let dotRect = CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)
                cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 2.5, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                UIColor.white.setFill()
                cg.fillEllipse(in: dotRect.insetBy(dx: -3, dy: -3))
                cg.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.systemBlue.setFill()
                cg.fillEllipse(in: dotRect)
            }.withRenderingMode(.alwaysOriginal)
        }()

        @MainActor
        private func updateLandmarkOverlayPositions(on mapView: TMapView) {
            for item in landmarkOverlays.values {
                guard let point = mapView.convertCoordinatesToPoint(item.coordinate) else { continue }
                item.view.frame.origin = CGPoint(
                    x: point.x - item.view.bounds.width / 2,
                    y: point.y - item.view.bounds.height
                )
            }
        }

        func mapViewDidChangeBounds() {
            guard let mapView else { return }
            Task { @MainActor in self.updateLandmarkOverlayPositions(on: mapView) }
        }

        func mapViewDidFinishLoadingMap() {
            guard let mapView else { return }
            Task { @MainActor in
                self.isMapReady = true
                mapView.vsmMapView?.showScaleBar = false
                if let latestState {
                    self.applyCamera(state: latestState, on: mapView)
                }
            }
        }

        private final class LandmarkOverlayView: UIView {
            private let indexLabel = UILabel()
            private let nameLabel = UILabel()
            private let bubbleLayer = CAShapeLayer()
            private let bodyHeight: CGFloat = 34
            private let tailHeight: CGFloat = 11

            init(index: Int, name: String) {
                super.init(frame: CGRect(x: 0, y: 0, width: 148, height: 45))
                backgroundColor = .clear
                bubbleLayer.fillColor = UIColor.systemBackground.cgColor
                bubbleLayer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.5).cgColor
                bubbleLayer.lineWidth = 1
                bubbleLayer.shadowColor = UIColor.black.cgColor
                bubbleLayer.shadowOpacity = 0.18
                bubbleLayer.shadowOffset = CGSize(width: 0, height: 2)
                bubbleLayer.shadowRadius = 3
                layer.insertSublayer(bubbleLayer, at: 0)

                indexLabel.text = "\(index)"
                indexLabel.font = .systemFont(ofSize: 13, weight: .bold)
                indexLabel.textColor = .white
                indexLabel.textAlignment = .center
                indexLabel.backgroundColor = .systemOrange
                indexLabel.layer.cornerRadius = 12
                indexLabel.clipsToBounds = true

                nameLabel.text = name
                nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
                nameLabel.textColor = .label
                nameLabel.lineBreakMode = .byTruncatingTail
                addSubview(indexLabel)
                addSubview(nameLabel)
            }

            required init?(coder: NSCoder) { nil }

            override func layoutSubviews() {
                super.layoutSubviews()
                let bodyRect = CGRect(x: 0, y: 0, width: bounds.width, height: bodyHeight)
                let path = UIBezierPath(roundedRect: bodyRect, cornerRadius: 17)
                path.move(to: CGPoint(x: bounds.midX - 8, y: bodyHeight - 1))
                path.addLine(to: CGPoint(x: bounds.midX, y: bodyHeight + tailHeight))
                path.addLine(to: CGPoint(x: bounds.midX + 8, y: bodyHeight - 1))
                path.close()
                bubbleLayer.path = path.cgPath
                bubbleLayer.shadowPath = path.cgPath
                indexLabel.frame = CGRect(x: 5, y: 5, width: 24, height: 24)
                nameLabel.frame = CGRect(x: 36, y: 7, width: bounds.width - 44, height: 20)
            }
        }
    }
}
