//  Place+LandmarkPoiDTO.swift
//  LiveActivity_Practice

import Foundation

extension Place {
    init?(from poi: LandmarkPoiDTO) {
        let coordinatePairs = [
            (poi.pnsLat, poi.pnsLon),
            (poi.noorLat, poi.noorLon)
        ]
        guard let coordinate = coordinatePairs.compactMap({ pair -> Coordinate? in
            let (latitudeText, longitudeText) = pair
            guard let latitudeText, let longitudeText,
                  let latitude = Double(latitudeText),
                  let longitude = Double(longitudeText),
                  (33...39).contains(latitude),
                  (124...132).contains(longitude) else { return nil }
            return Coordinate(latitude: latitude, longitude: longitude)
        }).first else { return nil }
        let address = [poi.upperAddrName, poi.middleAddrName, poi.lowerAddrName, poi.detailAddrName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        self.init(
            id: poi.id ?? "\(poi.name)-\(coordinate.latitude)-\(coordinate.longitude)",
            name: poi.name,
            category: poi.lowerBizName ?? poi.middleBizName ?? poi.upperBizName ?? "장소",
            address: address,
            coordinate: coordinate
        )
    }
}
