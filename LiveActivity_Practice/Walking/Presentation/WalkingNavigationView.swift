import SwiftUI

struct WalkingNavigationView: View {
    private enum SearchField: String, Hashable { case start, destination }

    @StateObject private var viewModel = WalkingNavigationViewModel()
    @State private var cameraCommand: MapCameraCommand?
    @State private var cameraCommandSequence = 0
    @FocusState private var focusedSearchField: SearchField?
    @Binding private var selectedMapProvider: MapProviderKind

    init(selectedMapProvider: Binding<MapProviderKind>) {
        _selectedMapProvider = selectedMapProvider
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PersistentWalkingMapView(
                selectedProvider: selectedMapProvider,
                state: MapPresentationState(
                    route: viewModel.route,
                    currentLocation: viewModel.currentLocation,
                    currentHeading: viewModel.currentHeading,
                    currentLocationAccuracy: viewModel.currentLocationAccuracy,
                    cameraCommand: cameraCommand
                ),
                appleEngine: AppleMapEngine(),
                tmapEngine: TMapEngine()
            )
                .ignoresSafeArea()

            VStack(spacing: 12) {
                routeSearchPanel

                Spacer()

                if viewModel.isLoading {
                    ProgressView("최단 경로와 랜드마크 검색 중…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if let route = viewModel.route {
                    routeSummary(route)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()

            Button {
                viewModel.startLocationTracking()
                issueCameraCommand(.userLocation)
            } label: {
                Image(systemName: "location.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.blue)
            .clipShape(Circle())
            .shadow(radius: 5)
            .accessibilityLabel("내 위치 추적")
            .padding(.trailing, 16)
            .padding(.bottom, viewModel.route == nil ? 24 : 235)
        }
        .task {
            // 지도 첫 화면의 기준점을 현재 위치로 맞춘다.
            viewModel.startLocationTracking()
            issueCameraCommand(.userLocation)
        }
        .onChange(of: viewModel.route) { _, route in
            if route != nil { issueCameraCommand(.route) }
        }
        .task(id: placeSearchTaskID) {
            guard focusedSearchField != nil else {
                viewModel.clearPlaceSearchResults()
                return
            }
            let query = activeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard query.count >= 2 else {
                viewModel.clearPlaceSearchResults()
                return
            }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                try Task.checkCancellation()
                await viewModel.searchPlaces(keyword: query)
            } catch {
                // 새 입력이 들어오면 이전 검색 작업을 조용히 취소한다.
            }
        }
    }

    private var routeSearchPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Label("지도", systemImage: "map")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("지도 선택", selection: $selectedMapProvider) {
                    ForEach(MapProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                TextField("출발지를 검색하세요", text: searchBinding(for: .start))
                    .focused($focusedSearchField, equals: .start)
                    .submitLabel(.search)
                if viewModel.hasSelectedStart {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Button {
                    viewModel.useCurrentLocation()
                    focusedSearchField = nil
                } label: {
                    Image(systemName: "location.fill")
                }
                .accessibilityLabel("현재 위치를 출발지로 사용")
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                TextField("목적지를 검색하세요", text: searchBinding(for: .destination))
                    .focused($focusedSearchField, equals: .destination)
                    .submitLabel(.search)
                if viewModel.hasSelectedDestination {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if focusedSearchField != nil {
                Divider()
                placeSearchResults
            }

            Button {
                focusedSearchField = nil
                Task { await viewModel.searchRoute() }
            } label: {
                HStack {
                    if viewModel.isLoading { ProgressView().tint(.white) }
                    Text("길찾기").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isLoading ||
                !viewModel.hasSelectedStart ||
                !viewModel.hasSelectedDestination
            )
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
    }

    @ViewBuilder
    private var placeSearchResults: some View {
        if viewModel.isSearchingPlaces {
            ProgressView("장소 검색 중…")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.placeSearchResults.isEmpty, activeSearchQuery.count >= 2 {
            Text("검색 결과가 없습니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ForEach(viewModel.placeSearchResults.prefix(6)) { place in
                Button {
                    guard let target = activeSearchTarget else { return }
                    viewModel.selectPlace(place, for: target)
                    focusedSearchField = nil
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text([place.category, place.address].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    private func searchBinding(for field: SearchField) -> Binding<String> {
        Binding(
            get: { field == .start ? viewModel.startName : viewModel.destinationName },
            set: {
                viewModel.updateSearchQuery(
                    $0,
                    for: field == .start ? .start : .destination
                )
            }
        )
    }

    private var activeSearchTarget: WalkingNavigationViewModel.SearchTarget? {
        switch focusedSearchField {
        case .start: .start
        case .destination: .destination
        case nil: nil
        }
    }

    private var activeSearchQuery: String {
        switch focusedSearchField {
        case .start: viewModel.startName
        case .destination: viewModel.destinationName
        case nil: ""
        }
    }

    private var placeSearchTaskID: String {
        "\(focusedSearchField?.rawValue ?? "none")|\(activeSearchQuery)"
    }

    private func issueCameraCommand(_ target: MapCameraCommand.Target) {
        cameraCommandSequence += 1
        cameraCommand = MapCameraCommand(id: cameraCommandSequence, target: target)
    }

    private func routeSummary(_ route: WalkingRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(distanceText(route.totalDistance), systemImage: "figure.walk")
                Spacer()
                Label("약 \(max(1, route.totalTime / 60))분", systemImage: "clock")
            }
            .font(.headline)

            // 길찾기 직후에는 핵심 요약과 시작 동작만 제공한다.
            // 안내가 시작된 뒤에만 다음 회전 등 상세 정보를 노출한다.
            if viewModel.isNavigating {
                navigationDetails(for: route)
            }

            Button(viewModel.isNavigating ? "안내 종료" : "도보 안내 시작") {
                Task {
                    if viewModel.isNavigating { await viewModel.stopNavigation() }
                    else { await viewModel.startNavigation() }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isNavigating ? .red : .blue)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
    }

    @ViewBuilder
    private func navigationDetails(for route: WalkingRoute) -> some View {
        if let progress = viewModel.progress, let next = progress.nextManeuver {
            Label(next.instruction, systemImage: next.turn.symbolName)
                .lineLimit(2)
            Text("다음 안내까지 \(distanceText(progress.distanceToNextManeuver))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        let landmarkCount = Set(route.maneuvers.compactMap(\.landmark?.id)).count
        Text("경로 랜드마크 \(landmarkCount)개")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func distanceText(_ meters: Int) -> String {
        meters >= 1000 ? String(format: "%.1fkm", Double(meters) / 1000) : "\(meters)m"
    }

}
