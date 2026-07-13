import CoreLocation
import Foundation

nonisolated protocol WalkingRouteRepositoryProtocol: Sendable {
    func makeRoute(from start: Coordinate, to end: Coordinate) async throws -> WalkingRoute
}

nonisolated final class WalkingRouteRepository: WalkingRouteRepositoryProtocol, Sendable {
    private let client: TMAPClientProtocol

    init(client: TMAPClientProtocol = TMAPClient()) {
        self.client = client
    }

    func makeRoute(from start: Coordinate, to end: Coordinate) async throws -> WalkingRoute {
        let requestDTO = WalkingRouteRequestDTO(
            startX: start.longitude,
            startY: start.latitude,
            endX: end.longitude,
            endY: end.latitude,
            startName: "출발지",
            endName: "목적지"
        )
        let responseDTO = try await client.requestWalkingRoute(requestDTO)
        var route = try mapRoute(responseDTO)
#if DEBUG
        print("[Landmark] 경로 파싱 완료: distance=\(route.totalDistance)m, time=\(route.totalTime)s")
        print("[Landmark] 경로 좌표 수: \(route.path.count), 검색 대상 분기점 수: \(route.maneuvers.count)")
        for maneuver in route.maneuvers {
            print("[Landmark] 분기점 #\(maneuver.id): turn=\(maneuver.turn.rawValue), coordinate=(\(maneuver.coordinate.latitude), \(maneuver.coordinate.longitude)), description=\(maneuver.description)")
        }
#endif
        route.maneuvers = limitLandmarks(
            await attachLandmarks(
                to: route.maneuvers,
                routePath: route.path,
                start: start,
                exclusionRadius: 10
            ),
            maximumCount: 10
        )
#if DEBUG
        let selected = route.maneuvers.compactMap(\.landmark)
        print("[Landmark] 최종 랜드마크 수: \(selected.count)")
        for landmark in selected {
            print("[Landmark] 최종 선택: \(landmark.name) / \(landmark.category) / (\(landmark.coordinate.latitude), \(landmark.coordinate.longitude))")
        }
#endif
        return route
    }

    private func limitLandmarks(_ maneuvers: [WalkingManeuver], maximumCount: Int) -> [WalkingManeuver] {
        var result = maneuvers
        var used = Set<String>()
        for index in result.indices {
            guard let landmark = result[index].landmark else { continue }
            if used.count >= maximumCount || !used.insert(landmark.id).inserted {
#if DEBUG
                let reason = used.count >= maximumCount ? "최대 \(maximumCount)개 초과" : "중복 POI"
                print("[Landmark] 제외: \(landmark.name), reason=\(reason)")
#endif
                result[index].landmark = nil
            }
        }
        return result
    }

    private func mapRoute(_ responseDTO: WalkingRouteResponseDTO) throws -> WalkingRoute {
        var path: [Coordinate] = []
        var maneuvers: [WalkingManeuver] = []
        var totalDistance = 0
        var totalTime = 0

        for featureDTO in responseDTO.features {
            totalDistance = max(totalDistance, featureDTO.properties.totalDistance ?? 0)
            totalTime = max(totalTime, featureDTO.properties.totalTime ?? 0)

            switch featureDTO.geometry.coordinates {
            case let .line(values):
                for value in values where value.count >= 2 {
                    let coordinate = Coordinate(latitude: value[1], longitude: value[0])
                    if path.last != coordinate { path.append(coordinate) }
                }
            case let .point(value):
                guard value.count >= 2 else { continue }
                let coordinate = Coordinate(latitude: value[1], longitude: value[0])
                let turn = mapTurn(featureDTO.properties.turnType, pointType: featureDTO.properties.pointType)
                guard turn != .straight || featureDTO.properties.pointType == "EP" else { continue }
                maneuvers.append(
                    WalkingManeuver(
                        id: featureDTO.properties.index ?? maneuvers.count,
                        coordinate: coordinate,
                        turn: turn,
                        description: featureDTO.properties.description ?? defaultInstruction(for: turn),
                        routeIndex: nearestPathIndex(to: coordinate, in: path),
                        landmark: nil
                    )
                )
            }
        }

        guard !path.isEmpty else { throw TMAPError.invalidResponse }
        return WalkingRoute(totalDistance: totalDistance, totalTime: totalTime, path: path, maneuvers: maneuvers)
    }

    private func attachLandmarks(
        to maneuvers: [WalkingManeuver],
        routePath: [Coordinate],
        start: Coordinate,
        exclusionRadius: CLLocationDistance
    ) async -> [WalkingManeuver] {
        await withTaskGroup(of: (Int, Landmark?).self) { group in
            for (offset, maneuver) in maneuvers.enumerated()
            where maneuver.turn != .destination && maneuver.coordinate.distance(to: start) > exclusionRadius {
                group.addTask { [client] in
                    do {
                        // TMAP radius는 km 단위다. 1km로 조회한 뒤 분기점 30m·경로선 20m 기준으로 재필터링한다.
                        let responseDTO = try await client.searchLandmarks(near: maneuver.coordinate, radius: 1)
                        let candidates = responseDTO.searchPoiInfo.pois.poi
                            .compactMap(Self.mapLandmark)
                            .filter { $0.coordinate.distance(to: start) > exclusionRadius }
#if DEBUG
                        print("[Landmark] 분기점 #\(maneuver.id) POI 디코딩 수: \(responseDTO.searchPoiInfo.pois.poi.count), 좌표 변환 성공 수: \(candidates.count)")
                        for candidate in candidates {
                            let cornerDistance = candidate.coordinate.distance(to: maneuver.coordinate)
                            let routeDistance = Self.distanceToRoute(candidate.coordinate, routePath: routePath)
                            print("[Landmark] 후보: \(candidate.name) / \(candidate.category) / 분기점=\(String(format: "%.1f", cornerDistance))m / 경로=\(String(format: "%.1f", routeDistance))m")
                        }
#endif
                        let selected = Self.bestLandmark(
                            from: candidates,
                            near: maneuver.coordinate,
                            turn: maneuver.turn,
                            routeIndex: maneuver.routeIndex,
                            routePath: routePath
                        )
#if DEBUG
                        if let selected {
                            print("[Landmark] 분기점 #\(maneuver.id) 선택: \(selected.name)")
                        } else {
                            print("[Landmark] 분기점 #\(maneuver.id) 선택 실패: 회전 기준으로 적합한 후보 없음")
                        }
#endif
                        return (offset, selected)
                    } catch {
                        // 랜드마크 실패가 경로 전체 실패로 이어지지 않게 한다.
#if DEBUG
                        print("[Landmark] 분기점 #\(maneuver.id) POI 검색 실패: \(String(reflecting: error))")
                        print("[Landmark] 실패 좌표: (\(maneuver.coordinate.latitude), \(maneuver.coordinate.longitude))")
#endif
                        return (offset, nil)
                    }
                }
            }

            var result = maneuvers
            for await (offset, landmark) in group {
                if let landmark { result[offset].landmark = landmark }
            }
            return result
        }
    }

    private static func mapLandmark(_ poiDTO: LandmarkPoiDTO) -> Landmark? {
        guard let coordinate = validCoordinate(
            preferredLatitude: poiDTO.pnsLat,
            preferredLongitude: poiDTO.pnsLon,
            fallbackLatitude: poiDTO.noorLat,
            fallbackLongitude: poiDTO.noorLon
        ) else { return nil }
        return Landmark(
            id: poiDTO.id ?? "\(poiDTO.name)-\(coordinate.latitude)-\(coordinate.longitude)",
            name: poiDTO.name,
            category: poiDTO.lowerBizName ?? poiDTO.middleBizName ?? poiDTO.upperBizName ?? "장소",
            coordinate: coordinate
        )
    }

    private static func validCoordinate(
        preferredLatitude: String?,
        preferredLongitude: String?,
        fallbackLatitude: String?,
        fallbackLongitude: String?
    ) -> Coordinate? {
        let pairs = [
            (preferredLatitude, preferredLongitude),
            (fallbackLatitude, fallbackLongitude)
        ]
        for (latitudeText, longitudeText) in pairs {
            guard let latitudeText, let longitudeText,
                  let latitude = Double(latitudeText),
                  let longitude = Double(longitudeText),
                  (33...39).contains(latitude),
                  (124...132).contains(longitude) else { continue }
            return Coordinate(latitude: latitude, longitude: longitude)
        }
        return nil
    }

    private static func bestLandmark(
        from candidates: [Landmark],
        near corner: Coordinate,
        turn: WalkingTurn,
        routeIndex: Int,
        routePath: [Coordinate]
    ) -> Landmark? {
        let selected = candidates
            .filter {
                $0.coordinate.distance(to: corner) <= 30 &&
                distanceToRoute($0.coordinate, routePath: routePath) <= 20 &&
                isOnPreferredTurnSide(
                    poi: $0.coordinate,
                    corner: corner,
                    turn: turn,
                    routeIndex: routeIndex,
                    routePath: routePath
                )
            }
            .min {
                landmarkScore(
                    $0,
                    corner: corner,
                    turn: turn,
                    routeIndex: routeIndex,
                    routePath: routePath
                ) < landmarkScore(
                    $1,
                    corner: corner,
                    turn: turn,
                    routeIndex: routeIndex,
                    routePath: routePath
                )
            }
        guard let selected,
              landmarkScore(
                selected,
                corner: corner,
                turn: turn,
                routeIndex: routeIndex,
                routePath: routePath
              ) <= 40 else { return nil }
        return selected
    }

    private static func landmarkScore(
        _ landmark: Landmark,
        corner: Coordinate,
        turn: WalkingTurn,
        routeIndex: Int,
        routePath: [Coordinate]
    ) -> Double {
        let cornerDistance = landmark.coordinate.distance(to: corner)
        let routeDistance = distanceToRoute(landmark.coordinate, routePath: routePath)
        let position = relativePosition(
            poi: landmark.coordinate,
            corner: corner,
            routeIndex: routeIndex,
            routePath: routePath
        )
        let afterCornerPenalty = (position?.longitudinal ?? 0) > 5 ? 20.0 : 0
        return cornerDistance
            + routeDistance * 0.3
            + afterCornerPenalty
            - visibilityBonus(for: landmark.category)
    }

    private static func isOnPreferredTurnSide(
        poi: Coordinate,
        corner: Coordinate,
        turn: WalkingTurn,
        routeIndex: Int,
        routePath: [Coordinate]
    ) -> Bool {
        let expectsLeftSide: Bool
        switch turn {
        case .left, .slightLeft: expectsLeftSide = true
        case .right, .slightRight: expectsLeftSide = false
        default: return true
        }

        guard let position = relativePosition(
            poi: poi,
            corner: corner,
            routeIndex: routeIndex,
            routePath: routePath
        ) else { return false }

        let sideThreshold = 2.0
        return expectsLeftSide
            ? position.lateral > sideThreshold
            : position.lateral < -sideThreshold
    }

    private static func relativePosition(
        poi: Coordinate,
        corner: Coordinate,
        routeIndex: Int,
        routePath: [Coordinate]
    ) -> (lateral: Double, longitudinal: Double)? {
        guard routePath.count >= 2 else { return nil }
        let index = min(max(routeIndex, 1), routePath.count - 1)
        let previous = routePath[index - 1]
        let metersPerLatitudeDegree = 111_132.0
        let metersPerLongitudeDegree = 111_320.0 * cos(corner.latitude * .pi / 180)

        let incomingX = (corner.longitude - previous.longitude) * metersPerLongitudeDegree
        let incomingY = (corner.latitude - previous.latitude) * metersPerLatitudeDegree
        let poiX = (poi.longitude - corner.longitude) * metersPerLongitudeDegree
        let poiY = (poi.latitude - corner.latitude) * metersPerLatitudeDegree
        let incomingLength = hypot(incomingX, incomingY)
        guard incomingLength > 0 else { return nil }

        let lateral = (incomingX * poiY - incomingY * poiX) / incomingLength
        let longitudinal = (incomingX * poiX + incomingY * poiY) / incomingLength
        return (lateral, longitudinal)
    }

    private static func visibilityBonus(for category: String) -> Double {
        let highVisibility = ["편의점", "대형마트", "마트", "지하철", "관공서", "공공기관", "주요시설물", "공원", "은행"]
        if highVisibility.contains(where: category.contains) { return 20 }

        let clearSignage = ["카페", "커피", "약국", "병원", "보건소", "호텔", "주유소", "충전소"]
        if clearSignage.contains(where: category.contains) { return 15 }

        let mediumVisibility = ["음식", "식당", "제과", "패스트푸드", "쇼핑", "숙박", "문화시설", "공연장", "영화관"]
        if mediumVisibility.contains(where: category.contains) { return 10 }

        let lowVisibility = ["ATM", "주차장", "버스정류장", "화장실", "미용실", "이발소", "노래방", "PC방", "정비소"]
        if lowVisibility.contains(where: category.contains) { return 5 }

        // 알려지지 않은 업종도 후보에서 제외하지 않는다.
        return 2
    }

    private static func distanceToRoute(_ point: Coordinate, routePath: [Coordinate]) -> CLLocationDistance {
        guard let first = routePath.first else { return .greatestFiniteMagnitude }
        guard routePath.count > 1 else { return point.distance(to: first) }

        return zip(routePath, routePath.dropFirst())
            .map { distanceFrom(point, toSegmentFrom: $0.0, to: $0.1) }
            .min() ?? .greatestFiniteMagnitude
    }

    private static func distanceFrom(
        _ point: Coordinate,
        toSegmentFrom start: Coordinate,
        to end: Coordinate
    ) -> CLLocationDistance {
        let metersPerLatitudeDegree = 111_132.0
        let metersPerLongitudeDegree = 111_320.0 * cos(point.latitude * .pi / 180)
        let segmentX = (end.longitude - start.longitude) * metersPerLongitudeDegree
        let segmentY = (end.latitude - start.latitude) * metersPerLatitudeDegree
        let pointX = (point.longitude - start.longitude) * metersPerLongitudeDegree
        let pointY = (point.latitude - start.latitude) * metersPerLatitudeDegree
        let segmentLengthSquared = segmentX * segmentX + segmentY * segmentY
        guard segmentLengthSquared > 0 else { return hypot(pointX, pointY) }

        let projection = min(1, max(0, (pointX * segmentX + pointY * segmentY) / segmentLengthSquared))
        return hypot(pointX - projection * segmentX, pointY - projection * segmentY)
    }

    private func nearestPathIndex(to coordinate: Coordinate, in path: [Coordinate]) -> Int {
        path.enumerated().min { $0.element.distance(to: coordinate) < $1.element.distance(to: coordinate) }?.offset ?? 0
    }

    private func mapTurn(_ turnType: Int?, pointType: String?) -> WalkingTurn {
        if pointType == "EP" { return .destination }
        return switch turnType {
        case 12: .left
        case 16, 17: .slightLeft
        case 13: .right
        case 18, 19: .slightRight
        case 125, 126, 127, 128, 129, 218: .stairs
        case 211, 212, 213, 214, 215, 216, 217: .crosswalk
        case 14: .unknown
        default: .straight
        }
    }

    private func defaultInstruction(for turn: WalkingTurn) -> String {
        return switch turn {
        case .left, .slightLeft: "왼쪽으로 이동하세요"
        case .right, .slightRight: "오른쪽으로 이동하세요"
        case .crosswalk: "횡단보도를 건너세요"
        case .stairs: "계단으로 이동하세요"
        case .destination: "목적지에 도착했습니다"
        default: "직진하세요"
        }
    }
}
