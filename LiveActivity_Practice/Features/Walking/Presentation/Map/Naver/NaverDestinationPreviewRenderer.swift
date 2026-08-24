//
//  NaverDestinationPreviewRenderer.swift
//  LiveActivity_Practice
//

import NMapsMap
import UIKit

/// 도착지 설정하기 전 미리보기를 위한 객체입니다.
final class NaverDestinationPreviewRenderer {
    private var marker: NMFMarker?
    private var renderedCoordinate: Coordinate?

    func render(coordinate: Coordinate?, on mapView: NMFMapView) {
        guard renderedCoordinate != coordinate else { return }

        clear()
        renderedCoordinate = coordinate

        guard let coordinate else { return }
        let marker = NMFMarker(
            position: NMGLatLng(
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
        )
        marker.iconImage = NMFOverlayImage(image: UIImage(imageLiteralResourceName: "ic-destination"))
        marker.width = 37
        marker.height = 48
        marker.mapView = mapView
        self.marker = marker
    }

    func clear() {
        marker?.mapView = nil
        marker = nil
        renderedCoordinate = nil
    }
}
