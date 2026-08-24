//  WalkingNavigationViewModelTests.swift
//  LiveActivity_PracticeTests

import Testing
@testable import LiveActivity_Practice

@MainActor
@Suite("WalkingNavigationViewModel 출발지 설정")
struct WalkingNavigationViewModelTests {

    @Test("현재 위치가 없으면 출발지가 즉시 설정되지 않는다")
    func setStartFromCurrentLocation_withoutLocation() {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        vm.setStartFromCurrentLocation()

        #expect(vm.hasSelectedStart == false)
    }
}

@Suite("SearchViewModel 검색 및 페이징")
struct SearchViewModelTests {

    // MARK: - searchPlaces

    @Test("키워드가 2자 미만이면 검색하지 않고 결과를 비운다")
    func searchPlaces_shortKeyword() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        await vm.searchPlaces(keyword: "포")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(vm.canLoadMoreSearchResults == false)
        #expect(mockClient.searchPlacesCallCount == 0)
    }

    @Test("빈 키워드이면 검색하지 않는다")
    func searchPlaces_emptyKeyword() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        await vm.searchPlaces(keyword: "")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(mockClient.searchPlacesCallCount == 0)
    }

    @Test("공백만 있는 키워드이면 검색하지 않는다")
    func searchPlaces_whitespaceKeyword() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        await vm.searchPlaces(keyword: "   ")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(mockClient.searchPlacesCallCount == 0)
    }

    @Test("정상 검색 시 결과가 반환된다")
    func searchPlaces_validKeyword() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        let pois = [
            MockTMAPClient.makePoi(id: "1", name: "포항공대"),
            MockTMAPClient.makePoi(id: "2", name: "포항역"),
        ]
        mockClient.searchPlacesHandler = { _, _, _ in
            MockTMAPClient.makeResponse(pois: pois, totalCount: 5)
        }

        await vm.searchPlaces(keyword: "포항")

        #expect(vm.placeSearchResults.count == 2)
        #expect(vm.placeSearchResults[0].name == "포항공대")
        #expect(vm.canLoadMoreSearchResults == true)
        #expect(mockClient.lastSearchPage == 1)
    }

    @Test("검색 결과가 totalCount와 같으면 더 불러올 수 없다")
    func searchPlaces_noMoreResults() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        let pois = [MockTMAPClient.makePoi(id: "1", name: "포항공대")]
        mockClient.searchPlacesHandler = { _, _, _ in
            MockTMAPClient.makeResponse(pois: pois, totalCount: 1)
        }

        await vm.searchPlaces(keyword: "포항공대")

        #expect(vm.placeSearchResults.count == 1)
        #expect(vm.canLoadMoreSearchResults == false)
    }

    @Test("검색 실패 시 결과가 비워진다")
    func searchPlaces_failure() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        mockClient.searchPlacesHandler = { _, _, _ in
            throw TMAPError.missingAPIKey
        }

        await vm.searchPlaces(keyword: "포항")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(vm.canLoadMoreSearchResults == false)
    }

    // MARK: - loadMoreSearchResults

    @Test("추가 페이지 로드 시 결과가 기존 결과에 추가된다")
    func loadMoreSearchResults_appendsResults() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        mockClient.searchPlacesHandler = { _, page, _ in
            if page == 1 {
                return MockTMAPClient.makeResponse(
                    pois: [MockTMAPClient.makePoi(id: "1", name: "결과1")],
                    totalCount: 3,
                    page: 1
                )
            } else {
                return MockTMAPClient.makeResponse(
                    pois: [
                        MockTMAPClient.makePoi(id: "2", name: "결과2"),
                        MockTMAPClient.makePoi(id: "3", name: "결과3"),
                    ],
                    totalCount: 3,
                    page: 2
                )
            }
        }

        await vm.searchPlaces(keyword: "테스트")
        #expect(vm.placeSearchResults.count == 1)
        #expect(vm.canLoadMoreSearchResults == true)

        await vm.loadMoreSearchResults()
        #expect(vm.placeSearchResults.count == 3)
        #expect(vm.placeSearchResults[1].name == "결과2")
        #expect(vm.canLoadMoreSearchResults == false)
        #expect(mockClient.lastSearchPage == 2)
    }

    @Test("canLoadMore가 false이면 추가 로드하지 않는다")
    func loadMoreSearchResults_guardCanLoadMore() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        mockClient.searchPlacesHandler = { _, _, _ in
            MockTMAPClient.makeResponse(
                pois: [MockTMAPClient.makePoi(id: "1", name: "결과1")],
                totalCount: 1
            )
        }

        await vm.searchPlaces(keyword: "테스트")
        #expect(vm.canLoadMoreSearchResults == false)

        let countBefore = mockClient.searchPlacesCallCount
        await vm.loadMoreSearchResults()
        #expect(mockClient.searchPlacesCallCount == countBefore)
    }

    @Test("검색 전에는 loadMore가 호출되지 않는다")
    func loadMoreSearchResults_beforeSearch() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        await vm.loadMoreSearchResults()

        #expect(mockClient.searchPlacesCallCount == 0)
    }

    // MARK: - clearPlaceSearchResults

    @Test("검색 결과 초기화 시 페이징 상태도 리셋된다")
    func clearPlaceSearchResults_resetsAll() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        mockClient.searchPlacesHandler = { _, _, _ in
            MockTMAPClient.makeResponse(
                pois: [MockTMAPClient.makePoi(id: "1", name: "결과")],
                totalCount: 10
            )
        }

        await vm.searchPlaces(keyword: "포항")
        #expect(vm.placeSearchResults.count == 1)
        #expect(vm.canLoadMoreSearchResults == true)

        vm.clearPlaceSearchResults()

        #expect(vm.placeSearchResults.isEmpty)
        #expect(vm.canLoadMoreSearchResults == false)
    }

    // MARK: - selectPlace

    @Test("장소 선택 시 검색 결과가 초기화된다")
    func selectPlace_clearsResults() async {
        let mockClient = MockTMAPClient()
        let vm = SearchViewModel(placeSearchClient: mockClient)

        mockClient.searchPlacesHandler = { _, _, _ in
            MockTMAPClient.makeResponse(
                pois: [MockTMAPClient.makePoi(id: "1", name: "포항공대")],
                totalCount: 1
            )
        }

        await vm.searchPlaces(keyword: "포항공대")
        #expect(vm.placeSearchResults.count == 1)

        let place = vm.placeSearchResults[0]
        vm.selectPlace(place)

        #expect(vm.placeSearchResults.isEmpty)
    }
}
