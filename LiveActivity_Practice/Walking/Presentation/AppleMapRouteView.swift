import MapKit
import SwiftUI
import UIKit

struct AppleMapRouteView: UIViewRepresentable {
    let state: MapPresentationState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.setRegion(
            MKCoordinateRegion(
                center: state.currentLocation?.clCoordinate
                    ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            ),
            animated: false
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if context.coordinator.renderedRoute != state.route {
            context.coordinator.render(state.route, on: mapView)
        }
        context.coordinator.applyCamera(state: state, on: mapView)
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        coordinator.tearDown(on: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var renderedRoute: WalkingRoute?
        private var lastCameraCommandID: Int?
        private var overlays: [MKOverlay] = []
        private var annotations: [MKAnnotation] = []
        private var routePolyline: MKPolyline?

        @MainActor
        func tearDown(on mapView: MKMapView) {
            mapView.setUserTrackingMode(.none, animated: false)
            mapView.showsUserLocation = false
            mapView.removeOverlays(overlays)
            mapView.removeAnnotations(annotations)
            mapView.delegate = nil
            overlays.removeAll()
            annotations.removeAll()
            routePolyline = nil
        }

        @MainActor
        func applyCamera(state: MapPresentationState, on mapView: MKMapView) {
            guard let command = state.cameraCommand,
                  command.id != lastCameraCommandID else { return }

            switch command.target {
            case .userLocation:
                guard let location = state.currentLocation else { return }
                mapView.setUserTrackingMode(.followWithHeading, animated: true)
                mapView.setCenter(location.clCoordinate, animated: true)
            case .route:
                guard let routePolyline else { return }
                mapView.setUserTrackingMode(.none, animated: false)
                mapView.setVisibleMapRect(
                    routePolyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 180, left: 45, bottom: 230, right: 45),
                    animated: true
                )
            }
            lastCameraCommandID = command.id
        }

        @MainActor
        func render(_ route: WalkingRoute?, on mapView: MKMapView) {
            mapView.removeOverlays(overlays)
            mapView.removeAnnotations(annotations)
            overlays.removeAll()
            annotations.removeAll()
            routePolyline = nil
            renderedRoute = route
            guard let route, route.path.count >= 2 else { return }

            let coordinates = route.path.map(\.clCoordinate)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
            overlays.append(polyline)
            routePolyline = polyline

            if let start = route.path.first {
                annotations.append(RoutePointAnnotation(title: "출발지", coordinate: start.clCoordinate, isStart: true))
            }
            if let end = route.path.last {
                annotations.append(RoutePointAnnotation(title: "목적지", coordinate: end.clCoordinate, isStart: false))
            }

            for (index, selection) in route.mapLandmarkSelections().enumerated() {
                let coordinate = selection.landmark.coordinate.clCoordinate
                let cornerCoordinate = selection.maneuver.coordinate.clCoordinate
                let area = MKCircle(center: coordinate, radius: 15)
                mapView.insertOverlay(area, below: polyline)
                overlays.append(area)

                let connectorCoordinates = [cornerCoordinate, coordinate]
                let connector = MKPolyline(coordinates: connectorCoordinates, count: connectorCoordinates.count)
                mapView.insertOverlay(connector, below: polyline)
                overlays.append(connector)

                annotations.append(LandmarkAnnotation(index: index + 1, name: selection.landmark.name, coordinate: coordinate))
                annotations.append(TurnPointAnnotation(turn: selection.maneuver.turn, coordinate: cornerCoordinate))
            }
            mapView.addAnnotations(annotations)
            mapView.setVisibleMapRect(
                polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 180, left: 45, bottom: 230, right: 45),
                animated: true
            )
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.32)
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
                renderer.lineWidth = 2
                return renderer
            }
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            if let routePolyline, polyline === routePolyline {
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 7
                renderer.alpha = 0.9
            } else {
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.75)
                renderer.lineWidth = 2
                renderer.alpha = 0.8
                renderer.lineDashPattern = [4, 4]
            }
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let landmark = annotation as? LandmarkAnnotation {
                let identifier = LandmarkAnnotationView.reuseIdentifier
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? LandmarkAnnotationView
                    ?? LandmarkAnnotationView(annotation: landmark, reuseIdentifier: identifier)
                view.annotation = landmark
                view.configure(index: landmark.index, name: landmark.name)
                return view
            }
            if let turnPoint = annotation as? TurnPointAnnotation {
                let identifier = "turn-point"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: turnPoint, reuseIdentifier: identifier)
                view.annotation = turnPoint
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: turnPoint.turn.symbolName)
                view.displayPriority = .required
                return view
            }
            guard let point = annotation as? RoutePointAnnotation else { return nil }
            let identifier = "route-point"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: point, reuseIdentifier: identifier)
            view.annotation = point
            view.canShowCallout = true
            view.markerTintColor = point.isStart ? .systemGreen : .systemRed
            view.glyphImage = UIImage(systemName: point.isStart ? "figure.walk" : "flag.fill")
            return view
        }
    }
}

private final class TurnPointAnnotation: NSObject, MKAnnotation {
    let turn: WalkingTurn
    let coordinate: CLLocationCoordinate2D
    init(turn: WalkingTurn, coordinate: CLLocationCoordinate2D) {
        self.turn = turn
        self.coordinate = coordinate
    }
}

private final class LandmarkAnnotation: NSObject, MKAnnotation {
    let index: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
    init(index: Int, name: String, coordinate: CLLocationCoordinate2D) {
        self.index = index
        self.name = name
        self.coordinate = coordinate
    }
}

private final class RoutePointAnnotation: NSObject, MKAnnotation {
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
    init(title: String, coordinate: CLLocationCoordinate2D, isStart: Bool) {
        self.title = title
        self.coordinate = coordinate
        self.isStart = isStart
    }
}

private final class LandmarkAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "landmark-bubble"
    private let indexLabel = UILabel()
    private let nameLabel = UILabel()
    private let bubbleLayer = CAShapeLayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 148, height: 45)
        centerOffset = CGPoint(x: 0, y: -22.5)
        backgroundColor = .clear
        displayPriority = .required
        bubbleLayer.fillColor = UIColor.systemBackground.cgColor
        bubbleLayer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.5).cgColor
        bubbleLayer.lineWidth = 1
        layer.insertSublayer(bubbleLayer, at: 0)

        indexLabel.font = .systemFont(ofSize: 13, weight: .bold)
        indexLabel.textColor = .white
        indexLabel.textAlignment = .center
        indexLabel.backgroundColor = .systemOrange
        indexLabel.layer.cornerRadius = 12
        indexLabel.clipsToBounds = true
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(indexLabel)
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { nil }

    func configure(index: Int, name: String) {
        indexLabel.text = "\(index)"
        nameLabel.text = name
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bodyHeight: CGFloat = 34
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: bounds.width, height: bodyHeight), cornerRadius: 17)
        path.move(to: CGPoint(x: bounds.midX - 8, y: bodyHeight - 1))
        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
        path.addLine(to: CGPoint(x: bounds.midX + 8, y: bodyHeight - 1))
        path.close()
        bubbleLayer.path = path.cgPath
        indexLabel.frame = CGRect(x: 5, y: 5, width: 24, height: 24)
        nameLabel.frame = CGRect(x: 36, y: 7, width: bounds.width - 44, height: 20)
    }
}
