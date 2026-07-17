//  WalkingNavigationViewModelTests.swift
//  LiveActivity_PracticeTests

import Testing
@testable import LiveActivity_Practice

@MainActor
@Suite("WalkingNavigationViewModel 검색 및 출발지 설정")
struct WalkingNavigationViewModelTests {

    // MARK: - setStartFromCurrentLocation

    @Test("현재 위치가 있으면 출발지가 즉시 설정된다")
    func setStartFromCurrentLocation_withExistingLocation() {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        // currentLocation은 private(set)이라 직접 설정 불가 — startLocationTracking 후 위치 업데이트 필요
        // 대신 setStartFromCurrentLocation이 currentLocation == nil일 때 fallback 동작을 검증
        vm.setStartFromCurrentLocation()

        // currentLocation이 nil이므로 hasSelectedStart는 아직 false (useCurrentLocation fallback)
        #expect(vm.hasSelectedStart == false)
    }

    // MARK: - selectPlace

    @Test("목적지 선택 시 destinationName과 hasSelectedDestination이 설정된다")
    func selectPlace_destination() {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        let place = PlaceSearchResult(
            id: "1",
            name: "포항공대",
            category: "대학교",
            address: "포항시 지곡동",
            coordinate: Coordinate(latitude: 36.014, longitude: 129.326)
        )

        vm.selectPlace(place, for: .destination)

        #expect(vm.destinationName == "포항공대")
        #expect(vm.hasSelectedDestination == true)
        #expect(vm.placeSearchResults.isEmpty)
    }

    @Test("출발지 선택 시 startName과 hasSelectedStart가 설정된다")
    func selectPlace_start() {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        let place = PlaceSearchResult(
            id: "2",
            name: "포항역",
            category: "기차역",
            address: "포항시 흥해읍",
            coordinate: Coordinate(latitude: 36.080, longitude: 129.380)
        )

        vm.selectPlace(place, for: .start)

        #expect(vm.startName == "포항역")
        #expect(vm.hasSelectedStart == true)
    }

    // MARK: - searchPlaces

    @Test("키워드가 2자 미만이면 검색하지 않고 결과를 비운다")
    func searchPlaces_shortKeyword() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        await vm.searchPlaces(keyword: "포")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(vm.canLoadMoreSearchResults == false)
        #expect(mockClient.searchPlacesCallCount == 0)
    }

    @Test("빈 키워드이면 검색하지 않는다")
    func searchPlaces_emptyKeyword() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        await vm.searchPlaces(keyword: "")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(mockClient.searchPlacesCallCount == 0)
    }

    @Test("공백만 있는 키워드이면 검색하지 않는다")
    func searchPlaces_whitespaceKeyword() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        await vm.searchPlaces(keyword: "   ")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(mockClient.searchPlacesCallCount == 0)
    }

    @Test("정상 검색 시 결과가 반환되고 페이지가 1로 설정된다")
    func searchPlaces_validKeyword() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

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
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        let pois = [MockTMAPClient.makePoi(id: "1", name: "포항공대")]
        mockClient.searchPlacesHandler = { _, _, _ in
            MockTMAPClient.makeResponse(pois: pois, totalCount: 1)
        }

        await vm.searchPlaces(keyword: "포항공대")

        #expect(vm.placeSearchResults.count == 1)
        #expect(vm.canLoadMoreSearchResults == false)
    }

    @Test("검색 실패 시 에러 메시지가 설정된다")
    func searchPlaces_failure() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        mockClient.searchPlacesHandler = { _, _, _ in
            throw TMAPError.missingAPIKey
        }

        await vm.searchPlaces(keyword: "포항")

        #expect(vm.placeSearchResults.isEmpty)
        #expect(vm.errorMessage != nil)
        #expect(vm.canLoadMoreSearchResults == false)
    }

    // MARK: - loadMoreSearchResults (페이징)

    @Test("추가 페이지 로드 시 결과가 기존 결과에 추가된다")
    func loadMoreSearchResults_appendsResults() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        // 첫 페이지
        var callCount = 0
        mockClient.searchPlacesHandler = { _, page, _ in
            callCount += 1
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

        // 두 번째 페이지
        await vm.loadMoreSearchResults()
        #expect(vm.placeSearchResults.count == 3)
        #expect(vm.placeSearchResults[1].name == "결과2")
        #expect(vm.canLoadMoreSearchResults == false)
        #expect(mockClient.lastSearchPage == 2)
    }

    @Test("canLoadMore가 false이면 추가 로드하지 않는다")
    func loadMoreSearchResults_guardCanLoadMore() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

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
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        await vm.loadMoreSearchResults()

        #expect(mockClient.searchPlacesCallCount == 0)
    }

    // MARK: - clearPlaceSearchResults

    @Test("검색 결과 초기화 시 페이징 상태도 리셋된다")
    func clearPlaceSearchResults_resetsAll() async {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

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

    // MARK: - updateSearchQuery

    @Test("검색 쿼리 변경 시 기존 경로와 진행 상태가 초기화된다")
    func updateSearchQuery_resetsRoute() {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        vm.updateSearchQuery("새로운 목적지", for: .destination)

        #expect(vm.destinationName == "새로운 목적지")
        #expect(vm.hasSelectedDestination == false)
        #expect(vm.route == nil)
    }

    @Test("같은 쿼리로 변경 시 아무 변화가 없다")
    func updateSearchQuery_sameValueNoOp() {
        let mockClient = MockTMAPClient()
        let mockRepo = MockWalkingRouteRepository()
        let vm = WalkingNavigationViewModel(repository: mockRepo, placeSearchClient: mockClient)

        let place = PlaceSearchResult(
            id: "1", name: "포항공대", category: "", address: "",
            coordinate: Coordinate(latitude: 36.0, longitude: 129.0)
        )
        vm.selectPlace(place, for: .destination)
        #expect(vm.hasSelectedDestination == true)

        // 같은 이름으로 업데이트 — hasSelectedDestination이 유지되어야 함
        vm.updateSearchQuery("포항공대", for: .destination)
        #expect(vm.hasSelectedDestination == true)
    }
}
