//
//  NaverDestinationPreviewRenderer.swift
//  LiveActivity_Practice
//

import NMapsMap
import UIKit

/// 도착지 설정하기 전 미리보기를 위한 객체입니다.
final class NaverDestinationPreviewRenderer {
    private var marker: NMFMarker?
    private var renderedPlace: PlaceSearchResult?

    func render(place: PlaceSearchResult?, on mapView: NMFMapView) {
        guard renderedPlace != place else { return }

        clear()
        renderedPlace = place

        guard let place else { return }
        let marker = NMFMarker(
            position: NMGLatLng(
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude
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
        renderedPlace = nil
    }
}
