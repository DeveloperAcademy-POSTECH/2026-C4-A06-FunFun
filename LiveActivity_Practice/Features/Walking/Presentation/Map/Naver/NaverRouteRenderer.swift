//  NaverRouteRenderer.swift
//  LiveActivity_Practice

import NMapsMap
import UIKit

final class NaverRouteRenderer {
    private var routePath: NMFPath?
    private var deviationRoutePath: NMFPath?
    private var renderedDeviationPath: [Coordinate] = []
    private var startEndMarkers: [NMFMarker] = []

    func render(route: WalkingRoute?, passedRouteIndex: Int, on mapView: NMFMapView) {
        clearAll()

        guard let route, route.path.count >= 2 else { return }
        let points = route.path.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }
        let path = NMFPath(points: points)
        path?.color = .systemBlue
        path?.outlineColor = .white
        path?.width = 8
        path?.outlineWidth = 2
        path?.patternIcon = NMFOverlayImage(image: Self.arrowPatternImage(size: 8))
        path?.patternInterval = 18
        path?.mapView = mapView
        routePath = path
        
        if let start = route.path.first {
            addMarker(type: .start, coordinate: start, on: mapView)
        }
        if let destination = route.path.last {
            addMarker(type: .destination, coordinate: destination, on: mapView)
        }
    }

    func renderDeviationPath(_ path: [Coordinate], on mapView: NMFMapView) {
        guard renderedDeviationPath != path else { return }
        deviationRoutePath?.mapView = nil
        deviationRoutePath = nil
        renderedDeviationPath = path
        guard path.count >= 2 else { return }

        let points = path.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }
        let deviation = NMFPath(points: points)
        deviation?.color = .systemRed
        deviation?.outlineColor = .white
        deviation?.width = 9
        deviation?.outlineWidth = 2
        deviation?.mapView = mapView
        deviationRoutePath = deviation
    }

    func clearAll() {
        routePath?.mapView = nil
        deviationRoutePath?.mapView = nil
        startEndMarkers.forEach { $0.mapView = nil }
        routePath = nil
        deviationRoutePath = nil
        renderedDeviationPath = []
        startEndMarkers.removeAll()
    }

    private func addMarker(type: MarkerType, coordinate: Coordinate, on mapView: NMFMapView) {
        let marker = NMFMarker(position: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
        marker.iconImage = NMFOverlayImage(image: type.image)
        marker.width = 37
        marker.height = 48
        marker.mapView = mapView
        startEndMarkers.append(marker)
    }
    
    enum MarkerType {
        case start
        case destination
        
        var image: UIImage {
            switch self {
            case .start:
                UIImage(imageLiteralResourceName: "ic-start")
            case .destination:
                UIImage(imageLiteralResourceName: "ic-destination")
            }
        }
    }

    /// 경로위에 표시하는 화살표
    private static func arrowPatternImage(size: CGFloat) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        guard let symbol = UIImage(systemName: "arrowtriangle.up.fill", withConfiguration: config) else {
            return UIImage()
        }
        let renderer = UIGraphicsImageRenderer(size: symbol.size)
        return renderer.image { _ in
            UIColor.white.setFill()
            symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(at: .zero)
        }
    }
}
