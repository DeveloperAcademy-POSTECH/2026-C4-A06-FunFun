//  TMAPClientIntegrationTests.swift
//  LiveActivity_PracticeTests
//
//  Created on 2026/07/18.
//

import Testing
@testable import LiveActivity_Practice

@Suite("TMap 장소 검색 API 중복 검증")
struct TMAPClientIntegrationTests {

    let client = TMAPClient()

    @Test("스타벅스 검색 결과 20개 중 id 중복 확인")
    func duplicateIDsInStarbucksSearch() async throws {
        let response = try await client.searchPlaces(keyword: "스타벅스", page: 1, near: nil)
        let pois = response.searchPoiInfo.pois.poi

        print("=== 스타벅스 검색 결과 ===")
        print("totalCount: \(response.searchPoiInfo.totalCount ?? "nil")")
        print("page: \(response.searchPoiInfo.page ?? "nil")")
        print("count: \(response.searchPoiInfo.count ?? "nil")")
        print("실제 반환 POI 수: \(pois.count)")
        print("")

        // id 기준 중복 확인
        let ids = pois.compactMap(\.id)
        let uniqueIDs = Set(ids)
        let duplicateIDCount = ids.count - uniqueIDs.count
        print("--- id 기준 ---")
        print("id가 있는 POI: \(ids.count)개")
        print("고유 id: \(uniqueIDs.count)개")
        print("중복 id: \(duplicateIDCount)개")

        if duplicateIDCount > 0 {
            let duplicateIDs = Dictionary(grouping: ids, by: { $0 })
                .filter { $0.value.count > 1 }
            for (id, occurrences) in duplicateIDs {
                let names = pois.filter { $0.id == id }.map(\.name)
                print("  중복 id=\(id) (\(occurrences.count)회): \(names)")
            }
        }
        print("")

        // name+좌표 기준 중복 확인 (앱에서 fallback id로 사용하는 조합)
        let nameCoordKeys = pois.map { poi -> String in
            let lat = poi.noorLat ?? poi.pnsLat ?? "?"
            let lon = poi.noorLon ?? poi.pnsLon ?? "?"
            return "\(poi.name)-\(lat)-\(lon)"
        }
        let uniqueNameCoords = Set(nameCoordKeys)
        let duplicateNameCoordCount = nameCoordKeys.count - uniqueNameCoords.count
        print("--- name+좌표 기준 ---")
        print("고유 조합: \(uniqueNameCoords.count)개")
        print("중복 조합: \(duplicateNameCoordCount)개")

        if duplicateNameCoordCount > 0 {
            let duplicates = Dictionary(grouping: nameCoordKeys, by: { $0 })
                .filter { $0.value.count > 1 }
            for (key, occurrences) in duplicates {
                print("  중복: \(key) (\(occurrences.count)회)")
            }
        }
        print("")

        // 전체 POI 목록 출력
        print("--- 전체 목록 ---")
        for (index, poi) in pois.enumerated() {
            let lat = poi.noorLat ?? poi.pnsLat ?? "?"
            let lon = poi.noorLon ?? poi.pnsLon ?? "?"
            let address = [poi.upperAddrName, poi.middleAddrName, poi.lowerAddrName]
                .compactMap { $0 }
                .joined(separator: " ")
            print("[\(index + 1)] id=\(poi.id ?? "nil") | \(poi.name) | \(address) | (\(lat), \(lon))")
        }

        // 테스트 결과 기록 (실패시키지 않고 정보 수집 목적)
        print("")
        print("=== 요약 ===")
        print("총 \(pois.count)개 중 id 중복 \(duplicateIDCount)개, name+좌표 중복 \(duplicateNameCoordCount)개")
    }
}
