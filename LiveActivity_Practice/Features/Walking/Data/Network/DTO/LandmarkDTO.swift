//  LandmarkDTO.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import Foundation

// TMAP 주변 POI 검색 응답 DTO
nonisolated struct LandmarkSearchResponseDTO: Decodable, Sendable {
    let searchPoiInfo: LandmarkSearchPoiInfoDTO
}

nonisolated struct LandmarkSearchPoiInfoDTO: Decodable, Sendable {
    let totalCount: String?
    let page: String?
    let count: String?
    let pois: LandmarkPoisDTO

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = Self.decodeFlexibleString(from: container, key: .totalCount)
        page = Self.decodeFlexibleString(from: container, key: .page)
        count = Self.decodeFlexibleString(from: container, key: .count)
        pois = try container.decode(LandmarkPoisDTO.self, forKey: .pois)
    }

    private enum CodingKeys: String, CodingKey {
        case totalCount, page, count, pois
    }

    private static func decodeFlexibleString(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
        if let str = try? container.decode(String.self, forKey: key) { return str }
        if let num = try? container.decode(Int.self, forKey: key) { return String(num) }
        return nil
    }
}

nonisolated struct LandmarkPoisDTO: Decodable, Sendable {
    let poi: [LandmarkPoiDTO]
}

nonisolated struct LandmarkPoiDTO: Decodable, Sendable {
    let id: String?
    let name: String
    let upperBizName: String?
    let middleBizName: String?
    let lowerBizName: String?
    let noorLat: String?
    let noorLon: String?
    let pnsLat: String?
    let pnsLon: String?
    let upperAddrName: String?
    let middleAddrName: String?
    let lowerAddrName: String?
    let detailAddrName: String?
}
