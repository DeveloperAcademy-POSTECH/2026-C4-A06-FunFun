//
//  SearchViewModel.swift
//  LiveActivity_Practice
//
//  Created by Seungjun Lee on 8/19/26.
//

import CoreLocation

@Observable
final class SearchViewModel: NSObject {
    private(set) var placeSearchResults: [Place] = []
    private(set) var isSearchingPlaces = false
    private var currentSearchPage = 1
    private var lastSearchKeyword = ""
    private(set) var canLoadMoreSearchResults = false
    private(set) var currentLocation: Coordinate?
    
    private let placeSearchClient: TMAPClientProtocol
    private let locationManager = CLLocationManager()
    
    init(placeSearchClient: TMAPClientProtocol = TMAPClient()) {
        self.placeSearchClient = placeSearchClient
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func searchPlaces(keyword: String) async {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword.count >= 2 else {
            placeSearchResults = []
            canLoadMoreSearchResults = false
            return
        }
        currentSearchPage = 1
        lastSearchKeyword = keyword
        isSearchingPlaces = true
        defer { isSearchingPlaces = false }
        do {
            let response = try await placeSearchClient.searchPlaces(keyword: keyword, page: 1, near: currentLocation)
            let results = response.searchPoiInfo.pois.poi.compactMap(Place.init(from:))
            var seen = Set<String>()
            placeSearchResults = results.filter { seen.insert($0.id).inserted }
            let totalCount = Int(response.searchPoiInfo.totalCount ?? "0") ?? 0
            canLoadMoreSearchResults = placeSearchResults.count < totalCount
        } catch is CancellationError {
            return
        } catch {
            placeSearchResults = []
            canLoadMoreSearchResults = false
        }
    }

    func loadMoreSearchResults() async {
        guard canLoadMoreSearchResults, !isSearchingPlaces, !lastSearchKeyword.isEmpty else { return }

        let nextPage = currentSearchPage + 1
        isSearchingPlaces = true
        defer { isSearchingPlaces = false }
        do {
            let response = try await placeSearchClient.searchPlaces(keyword: lastSearchKeyword, page: nextPage, near: currentLocation)
            let newResults = response.searchPoiInfo.pois.poi.compactMap(Place.init(from:))
            let existingIDs = Set(placeSearchResults.map(\.id))
            let uniqueNewResults = newResults.filter { !existingIDs.contains($0.id) }
            placeSearchResults.append(contentsOf: uniqueNewResults)
            currentSearchPage = nextPage
            let totalCount = Int(response.searchPoiInfo.totalCount ?? "0") ?? 0
            canLoadMoreSearchResults = placeSearchResults.count < totalCount
        } catch is CancellationError {
            return
        } catch {
            canLoadMoreSearchResults = false
        }
    }

    func clearPlaceSearchResults() {
        placeSearchResults = []
        canLoadMoreSearchResults = false
        currentSearchPage = 1
        lastSearchKeyword = ""
    }
}

extension SearchViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}
