//  WalkingRouteDTO.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import Foundation

// TMAP 보행자 경로 FeatureCollection 응답 DTO
nonisolated struct WalkingRouteResponseDTO: Decodable, Sendable {
    let type: String
    let features: [WalkingRouteFeatureDTO]
}

nonisolated struct WalkingRouteFeatureDTO: Decodable, Sendable {
    let type: String
    let geometry: WalkingRouteGeometryDTO
    let properties: WalkingRoutePropertiesDTO
}

nonisolated struct WalkingRouteGeometryDTO: Decodable, Sendable {
    let type: String
    let coordinates: JSONCoordinateDTO
}

nonisolated enum JSONCoordinateDTO: Decodable, Sendable {
    case point([Double])
    case line([[Double]])

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let point = try? container.decode([Double].self) {
            self = .point(point)
        } else {
            self = .line(try container.decode([[Double]].self))
        }
    }
}

nonisolated struct WalkingRoutePropertiesDTO: Decodable, Sendable {
    let index: Int?
    let totalDistance: Int?
    let totalTime: Int?
    let distance: Int?
    let time: Int?
    let pointType: String?
    let turnType: Int?
    let description: String?
    let name: String?
    let nearPoiName: String?
}

nonisolated struct WalkingRouteRequestDTO: Encodable, Sendable {
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
    let reqCoordType = "WGS84GEO"
    let resCoordType = "WGS84GEO"
    let startName: String
    let endName: String
    let searchOption = "10"
    let sort = "index"
}
