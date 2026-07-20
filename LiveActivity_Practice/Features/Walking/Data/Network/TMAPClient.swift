//  TMAPClient.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import Foundation

nonisolated enum TMAPError: LocalizedError {
    case missingAPIKey
    case noWalkingRoute
    case invalidResponse
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Info.plist에 TMAP_APP_KEY를 설정해 주세요."
        case .noWalkingRoute: "출발지와 목적지 사이에서 보행 가능한 경로를 찾지 못했습니다. 좌표 또는 탐색 옵션을 확인해 주세요."
        case .invalidResponse: "TMAP 응답을 해석하지 못했습니다."
        case let .server(code, message): "TMAP 오류(\(code)): \(message)"
        }
    }
}

nonisolated protocol TMAPClientProtocol: Sendable {
    func requestWalkingRoute(_ requestDTO: WalkingRouteRequestDTO) async throws -> WalkingRouteResponseDTO
    func searchLandmarks(near coordinate: Coordinate, radius: Int) async throws -> LandmarkSearchResponseDTO
    func searchPlaces(keyword: String, page: Int, near coordinate: Coordinate?) async throws -> LandmarkSearchResponseDTO
}

nonisolated final class TMAPClient: TMAPClientProtocol, Sendable {
    private let session: URLSession
    private let appKey: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared, appKey: String? = Bundle.main.object(forInfoDictionaryKey: "TMAP_APP_KEY") as? String) {
        self.session = session
        self.appKey = appKey ?? ""
#if DEBUG
        print("[TMAP] 실제 사용 AppKey: \(self.appKey)")
#endif
    }

    func requestWalkingRoute(_ requestDTO: WalkingRouteRequestDTO) async throws -> WalkingRouteResponseDTO {
        guard !appKey.isEmpty, appKey != "$(TMAP_APP_KEY)" else { throw TMAPError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appKey, forHTTPHeaderField: "appKey")
        request.httpBody = try encoder.encode(requestDTO)
#if DEBUG
        print("[TMAP] 보행 경로 요청: start=(\(requestDTO.startY), \(requestDTO.startX)), end=(\(requestDTO.endY), \(requestDTO.endX)), searchOption=\(requestDTO.searchOption)")
#endif
        return try await send(request, as: WalkingRouteResponseDTO.self)
    }

    func searchLandmarks(near coordinate: Coordinate, radius: Int) async throws -> LandmarkSearchResponseDTO {
        guard !appKey.isEmpty, appKey != "$(TMAP_APP_KEY)" else { throw TMAPError.missingAPIKey }
        var components = URLComponents(string: "https://apis.openapi.sk.com/tmap/pois/search/around")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "centerLon", value: String(coordinate.longitude)),
            URLQueryItem(name: "centerLat", value: String(coordinate.latitude)),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "count", value: "100"),
            URLQueryItem(name: "sort", value: "distance"),
            URLQueryItem(name: "reqCoordType", value: "WGS84GEO"),
            URLQueryItem(name: "resCoordType", value: "WGS84GEO")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appKey, forHTTPHeaderField: "appKey")
#if DEBUG
        print("[TMAP][POI] 주변 검색 요청: coordinate=(\(coordinate.latitude), \(coordinate.longitude)), API radius=\(radius)km (앱에서 분기점·경로선 기준 재필터링)")
        print("[TMAP][POI] 요청 URL: \(components.url?.absoluteString ?? "")")
#endif
        return try await send(request, as: LandmarkSearchResponseDTO.self)
    }

    func searchPlaces(keyword: String, page: Int = 1, near coordinate: Coordinate?) async throws -> LandmarkSearchResponseDTO {
        guard !appKey.isEmpty, appKey != "$(TMAP_APP_KEY)" else { throw TMAPError.missingAPIKey }
        var components = URLComponents(string: "https://apis.openapi.sk.com/tmap/pois")!
        var queryItems = [
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "searchKeyword", value: keyword),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "count", value: "20"),
            URLQueryItem(name: "searchtypCd", value: "A"),
            URLQueryItem(name: "reqCoordType", value: "WGS84GEO"),
            URLQueryItem(name: "resCoordType", value: "WGS84GEO")
        ]
        if let coordinate {
            queryItems.append(URLQueryItem(name: "centerLon", value: String(coordinate.longitude)))
            queryItems.append(URLQueryItem(name: "centerLat", value: String(coordinate.latitude)))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appKey, forHTTPHeaderField: "appKey")
#if DEBUG
        print("[TMAP][POI] 통합검색: keyword=\(keyword)")
#endif
        return try await send(request, as: LandmarkSearchResponseDTO.self)
    }

    private func send<ResponseDTO: Decodable>(_ request: URLRequest, as type: ResponseDTO.Type) async throws -> ResponseDTO {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TMAPError.invalidResponse }
#if DEBUG
        let responseBody = printableBody(data, response: http)
        print("[TMAP] HTTP \(http.statusCode) \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        print("[TMAP] Response Body:\n\(responseBody)")
#endif
        if http.statusCode == 204 {
#if DEBUG
            print("[TMAP] 204 No Content: 인증/디코딩 문제가 아니라 서버가 보행 경로 결과를 반환하지 않았습니다.")
#endif
            throw TMAPError.noWalkingRoute
        }
        guard 200..<300 ~= http.statusCode else {
            throw TMAPError.server(statusCode: http.statusCode, message: responseMessage(data, response: http))
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
#if DEBUG
            print("[TMAP] Decoding target: \(String(describing: type))")
            printDecodingError(error)
#endif
            throw TMAPError.invalidResponse
        }
    }

#if DEBUG
    private func printableBody(_ data: Data, response: HTTPURLResponse) -> String {
        guard !data.isEmpty else { return "<empty>" }
        guard let text = String(data: data, encoding: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            let encoding = response.value(forHTTPHeaderField: "Content-Encoding") ?? "none"
            return "<binary/non-JSON response: \(data.count) bytes, Content-Encoding=\(encoding)>"
        }
        return text
    }

    private func printDecodingError(_ error: Error) {
        switch error {
        case let DecodingError.keyNotFound(key, context):
            print("[TMAP] DecodingError.keyNotFound: \(key.stringValue)")
            print("[TMAP] codingPath: \(codingPath(context.codingPath))")
            print("[TMAP] detail: \(context.debugDescription)")
        case let DecodingError.typeMismatch(type, context):
            print("[TMAP] DecodingError.typeMismatch: \(type)")
            print("[TMAP] codingPath: \(codingPath(context.codingPath))")
            print("[TMAP] detail: \(context.debugDescription)")
        case let DecodingError.valueNotFound(type, context):
            print("[TMAP] DecodingError.valueNotFound: \(type)")
            print("[TMAP] codingPath: \(codingPath(context.codingPath))")
            print("[TMAP] detail: \(context.debugDescription)")
        case let DecodingError.dataCorrupted(context):
            print("[TMAP] DecodingError.dataCorrupted")
            print("[TMAP] codingPath: \(codingPath(context.codingPath))")
            print("[TMAP] detail: \(context.debugDescription)")
        default:
            print("[TMAP] Decoding error: \(error)")
        }
    }

    private func codingPath(_ path: [CodingKey]) -> String {
        path.map(\.stringValue).joined(separator: ".")
    }
#endif

    private func responseMessage(_ data: Data, response: HTTPURLResponse) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        let encoding = response.value(forHTTPHeaderField: "Content-Encoding") ?? "none"
        return String(data: data, encoding: .utf8) ?? "비 JSON 응답(\(data.count) bytes, encoding=\(encoding))"
    }
}
