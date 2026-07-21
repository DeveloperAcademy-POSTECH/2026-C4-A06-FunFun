//  NaverLocationOverlay.swift
//  LiveActivity_Practice

import CoreLocation
import NMapsMap

final class NaverLocationOverlay {
    weak var locationButton: MyLocationButton?
    var locationButtonBottomConstraint: NSLayoutConstraint?

    func setupLocationButton(on naverMapView: NMFNaverMapView, hasRoute: Bool) {
        let button = MyLocationButton()
        button.mapView = naverMapView.mapView
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
            constant: hasRoute ? -250 : -104
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
        overlay.location = NMGLatLng(lat: location.latitude, lng: location.longitude)
        overlay.heading = CGFloat(heading ?? 0)
    }

    func updateButtonLayout(hasRoute: Bool) {
        let targetConstant: CGFloat = hasRoute ? -250 : -104
        guard locationButtonBottomConstraint?.constant != targetConstant else { return }
        locationButtonBottomConstraint?.constant = targetConstant
        locationButton?.superview?.layoutIfNeeded()
    }

    func tearDown() {
        locationButton?.mapView = nil
        locationButtonBottomConstraint?.isActive = false
    }
}
