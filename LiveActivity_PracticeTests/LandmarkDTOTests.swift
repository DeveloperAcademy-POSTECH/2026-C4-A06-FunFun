//  LandmarkDTOTests.swift
//  LiveActivity_PracticeTests

import Testing
import Foundation
@testable import LiveActivity_Practice

@Suite("LandmarkSearchResponseDTO 디코딩")
struct LandmarkDTOTests {

    @Test("페이징 필드가 포함된 응답이 정상 디코딩된다")
    func decoding_withPaginationFields() throws {
        let json = """
        {
            "searchPoiInfo": {
                "totalCount": "42",
                "page": "1",
                "count": "20",
                "pois": {
                    "poi": [
                        {
                            "id": "100",
                            "name": "포항공대",
                            "noorLat": "36.014",
                            "noorLon": "129.326",
                            "upperAddrName": "경상북도",
                            "middleAddrName": "포항시",
                            "lowerAddrName": "지곡동"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LandmarkSearchResponseDTO.self, from: json)

        #expect(response.searchPoiInfo.totalCount == "42")
        #expect(response.searchPoiInfo.page == "1")
        #expect(response.searchPoiInfo.count == "20")
        #expect(response.searchPoiInfo.pois.poi.count == 1)
        #expect(response.searchPoiInfo.pois.poi[0].name == "포항공대")
    }

    @Test("페이징 필드가 없어도 정상 디코딩된다 (Optional)")
    func decoding_withoutPaginationFields() throws {
        let json = """
        {
            "searchPoiInfo": {
                "pois": {
                    "poi": [
                        {
                            "name": "포항역"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LandmarkSearchResponseDTO.self, from: json)

        #expect(response.searchPoiInfo.totalCount == nil)
        #expect(response.searchPoiInfo.page == nil)
        #expect(response.searchPoiInfo.count == nil)
        #expect(response.searchPoiInfo.pois.poi[0].name == "포항역")
    }

    @Test("빈 POI 배열 응답이 정상 디코딩된다")
    func decoding_emptyPois() throws {
        let json = """
        {
            "searchPoiInfo": {
                "totalCount": "0",
                "page": "1",
                "count": "0",
                "pois": {
                    "poi": []
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LandmarkSearchResponseDTO.self, from: json)

        #expect(response.searchPoiInfo.pois.poi.isEmpty)
        #expect(response.searchPoiInfo.totalCount == "0")
    }

    @Test("POI의 선택적 필드가 모두 nil이어도 디코딩된다")
    func decoding_minimalPoi() throws {
        let json = """
        {
            "searchPoiInfo": {
                "pois": {
                    "poi": [
                        {
                            "name": "테스트"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LandmarkSearchResponseDTO.self, from: json)
        let poi = try #require(response.searchPoiInfo.pois.poi.first)

        #expect(poi.name == "테스트")
        #expect(poi.id == nil)
        #expect(poi.noorLat == nil)
        #expect(poi.noorLon == nil)
        #expect(poi.pnsLat == nil)
        #expect(poi.pnsLon == nil)
        #expect(poi.upperAddrName == nil)
        #expect(poi.upperBizName == nil)
    }

    @Test("POI의 모든 필드가 채워진 응답 디코딩",
          arguments: [("36.014", "129.326"), ("35.100", "128.900")])
    func decoding_fullPoiCoordinates(lat: String, lon: String) throws {
        let json = """
        {
            "searchPoiInfo": {
                "totalCount": "1",
                "pois": {
                    "poi": [
                        {
                            "id": "test-1",
                            "name": "테스트 장소",
                            "upperBizName": "음식점",
                            "middleBizName": "한식",
                            "lowerBizName": "김밥",
                            "noorLat": "\(lat)",
                            "noorLon": "\(lon)",
                            "pnsLat": "\(lat)",
                            "pnsLon": "\(lon)",
                            "upperAddrName": "경상북도",
                            "middleAddrName": "포항시",
                            "lowerAddrName": "남구",
                            "detailAddrName": "지곡동 1번지"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LandmarkSearchResponseDTO.self, from: json)
        let poi = try #require(response.searchPoiInfo.pois.poi.first)

        #expect(poi.id == "test-1")
        #expect(poi.noorLat == lat)
        #expect(poi.noorLon == lon)
        #expect(poi.upperBizName == "음식점")
        #expect(poi.detailAddrName == "지곡동 1번지")
    }
}
