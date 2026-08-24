//  NaverLocationOverlay.swift
//  LiveActivity_Practice

import CoreLocation
import NMapsMap
import UIKit

final class NaverLocationOverlay {

    func updateOverlay(location: Coordinate?, heading: CLLocationDirection?, on mapView: NMFMapView) {
        let overlay = mapView.locationOverlay
        guard let location else {
            overlay.hidden = true
            return
        }
        overlay.hidden = false
        overlay.icon = NMFOverlayImage(name: "indicator")
        overlay.iconWidth = 28
        overlay.iconHeight = 38
        overlay.location = NMGLatLng(lat: location.latitude, lng: location.longitude)
        overlay.heading = CGFloat(heading ?? 0)
    }

    func tearDown() {
    }
}
