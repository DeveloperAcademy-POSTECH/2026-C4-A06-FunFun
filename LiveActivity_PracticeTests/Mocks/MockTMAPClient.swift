//  MockTMAPClient.swift
//  LiveActivity_PracticeTests

import Foundation
@testable import LiveActivity_Practice

final class MockTMAPClient: TMAPClientProtocol, @unchecked Sendable {
    var searchPlacesHandler: ((String, Int, Coordinate?) async throws -> LandmarkSearchResponseDTO)?
    var searchPlacesCallCount = 0
    var lastSearchKeyword: String?
    var lastSearchPage: Int?

    func requestWalkingRoute(_ requestDTO: WalkingRouteRequestDTO) async throws -> WalkingRouteResponseDTO {
        fatalError("Not implemented in mock")
    }

    func searchLandmarks(near coordinate: Coordinate, radius: Int) async throws -> LandmarkSearchResponseDTO {
        fatalError("Not implemented in mock")
    }

    func searchPlaces(keyword: String, page: Int, near coordinate: Coordinate?) async throws -> LandmarkSearchResponseDTO {
        searchPlacesCallCount += 1
        lastSearchKeyword = keyword
        lastSearchPage = page
        guard let handler = searchPlacesHandler else {
            return Self.emptyResponse
        }
        return try await handler(keyword, page, coordinate)
    }

    static let emptyResponse = LandmarkSearchResponseDTO(
        searchPoiInfo: LandmarkSearchPoiInfoDTO(
            totalCount: "0",
            page: "1",
            count: "0",
            pois: LandmarkPoisDTO(poi: [])
        )
    )

    static func makeResponse(pois: [LandmarkPoiDTO], totalCount: Int, page: Int = 1) -> LandmarkSearchResponseDTO {
        LandmarkSearchResponseDTO(
            searchPoiInfo: LandmarkSearchPoiInfoDTO(
                totalCount: String(totalCount),
                page: String(page),
                count: String(pois.count),
                pois: LandmarkPoisDTO(poi: pois)
            )
        )
    }

    static func makePoi(id: String, name: String, address: String = "포항시 청암로 77", lat: String = "36.014", lon: String = "129.326") -> LandmarkPoiDTO {
        LandmarkPoiDTO(
            id: id,
            name: name,
            upperBizName: nil,
            middleBizName: nil,
            lowerBizName: nil,
            noorLat: lat,
            noorLon: lon,
            pnsLat: nil,
            pnsLon: nil,
            upperAddrName: "경상북도",
            middleAddrName: "포항시",
            lowerAddrName: address,
            detailAddrName: nil
        )
    }
}
