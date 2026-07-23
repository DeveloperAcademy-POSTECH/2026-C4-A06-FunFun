//  NaverLocationOverlay.swift
//  LiveActivity_Practice

import CoreLocation
import NMapsMap
import UIKit

final class NaverLocationOverlay: NSObject, NMFMapViewOptionDelegate {
    weak var locationButton: MyLocationButton?
    var locationButtonBottomConstraint: NSLayoutConstraint?

    func setupLocationButton(
        on naverMapView: NMFNaverMapView,
        bottomInset: CGFloat
    ) {
        let button = MyLocationButton()
        button.mapView = naverMapView.mapView
        naverMapView.mapView.addOptionDelegate(delegate: self)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "내 위치 찾기"
        naverMapView.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: naverMapView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])
        let bottomConstraint = button.bottomAnchor.constraint(
            equalTo: naverMapView.safeAreaLayoutGuide.bottomAnchor,
            constant: -bottomInset
        )
        bottomConstraint.isActive = true
        locationButton = button
        locationButtonBottomConstraint = bottomConstraint
    }

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

    func updateButtonLayout(bottomInset: CGFloat) {
        let targetConstant = -bottomInset
        guard let bottomConstraint = locationButtonBottomConstraint,
              bottomConstraint.constant != targetConstant else { return }

        let superview = locationButton?.superview
        superview?.layoutIfNeeded()
        bottomConstraint.constant = targetConstant

        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0
        ) {
            superview?.layoutIfNeeded()
        }
    }

    func mapViewOptionChanged(_ mapView: NMFMapView) {
        mapView.locationOverlay.icon = NMFOverlayImage(name: "indicator")
        mapView.locationOverlay.iconWidth = 28
        mapView.locationOverlay.iconHeight = 38
    }

    func tearDown() {
        locationButton?.mapView?.removeOptionDelegate(delegate: self)
        locationButton?.mapView = nil
        locationButtonBottomConstraint?.isActive = false
    }
}
