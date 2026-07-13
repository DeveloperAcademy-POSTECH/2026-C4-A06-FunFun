import Foundation

// TMAP 주변 POI 검색 응답 DTO
nonisolated struct LandmarkSearchResponseDTO: Decodable, Sendable {
    let searchPoiInfo: LandmarkSearchPoiInfoDTO
}

nonisolated struct LandmarkSearchPoiInfoDTO: Decodable, Sendable {
    let pois: LandmarkPoisDTO
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
