//  WalkingNavigationView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

struct WalkingNavigationView: View {
    @StateObject private var viewModel = WalkingNavigationViewModel()
    @State private var cameraCommand: MapCameraCommand?
    @State private var cameraCommandSequence = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PersistentWalkingMapView(
                state: MapPresentationState(
                    route: viewModel.route,
                    deviationPath: viewModel.deviationPath,
                    passedRouteIndex: viewModel.passedRouteIndex,
                    currentLocation: viewModel.currentLocation,
                    currentHeading: viewModel.currentHeading,
                    currentLocationAccuracy: viewModel.currentLocationAccuracy,
                    navigationBearing: viewModel.navigationBearing,
                    navigationAlignmentID: viewModel.navigationAlignmentID,
                    isNavigating: viewModel.isNavigating,
                    cameraCommand: cameraCommand
                )
            )
                .ignoresSafeArea()

            if viewModel.isNavigating {
                HeadingSafeAreaGradientOverlay(heading: viewModel.currentHeading)
                    .ignoresSafeArea()
            }

            VStack(spacing: 12) {
                if viewModel.isNavigating {
                    navigationDestinationPanel
                    if viewModel.isOffRoute {
                        offRouteBanner
                    }
                }

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

                if !viewModel.isNavigating && viewModel.route == nil {
                    homeSearchPanel
                }
            }
            .padding()

        }
        .task {
            viewModel.startLocationTracking()
            issueCameraCommand(.userLocation)
        }
        .onChange(of: viewModel.route) { _, route in
            if route != nil { issueCameraCommand(.route) }
        }
        .confirmationDialog(
            "경로를 벗어났습니다",
            isPresented: $viewModel.shouldPresentReroutePrompt,
            titleVisibility: .visible
        ) {
            Button("현재 위치에서 재탐색") {
                Task { await viewModel.rerouteFromCurrentLocation() }
            }
            Button("기존 경로 유지", role: .cancel) {
                viewModel.keepCurrentRoute()
            }
        } message: {
            Text("현재 위치를 출발점으로 목적지까지 다시 탐색할 수 있습니다.")
        }
        .overlay {
            if isSearchExpanded {
                expandedSearchPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSearchExpanded)
        .task(id: searchQuery) {
            guard isSearchExpanded else { return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.searchPlaces(keyword: searchQuery)
        }
    }

    private var homeSearchPanel: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 51, height: 5)

            Button {
                isSearchExpanded = true
                isSearchFieldFocused = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(.systemGray))

                    Text("어디로 갈까요?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))

                    Spacer()

                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(.systemGray))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 30))
    }

    private var navigationDestinationPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("목적지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.destinationName.isEmpty ? "목적지" : viewModel.destinationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
    }

    private var offRouteBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isRerouting ? "경로 재탐색 중…" : "경로를 벗어났습니다")
                    .font(.subheadline.weight(.bold))
                if !viewModel.isRerouting {
                    Text("기존 경로에서 약 \(Int(viewModel.distanceFromRoute))m 떨어져 있습니다.")
                        .font(.caption)
                }
            }
            Spacer()
            if !viewModel.isRerouting {
                Button("재탐색") {
                    Task { await viewModel.rerouteFromCurrentLocation() }
                }
                .buttonStyle(.bordered)
                .tint(.white)
            } else {
                ProgressView().tint(.white)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }

    private var expandedSearchPanel: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 51, height: 5)
                .padding(.top, 12)

            // Search bar
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(.systemGray))

                TextField("어디로 갈까요?", text: $searchQuery)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        viewModel.clearPlaceSearchResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.systemGray3))
                    }
                }

                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(.systemGray))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: 50)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 25))
            .padding(.horizontal, 12)

            // Results container
            if !viewModel.placeSearchResults.isEmpty || (viewModel.isSearchingPlaces && placeSearchResultsEmpty) {
                searchResultsContainer
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(red: 233/255, green: 233/255, blue: 238/255).opacity(0.1)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    private var placeSearchResultsEmpty: Bool {
        viewModel.placeSearchResults.isEmpty
    }

    private var searchResultsContainer: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.placeSearchResults) { place in
                    searchResultRow(place)
                        .onAppear {
                            if place.id == viewModel.placeSearchResults.last?.id {
                                Task { await viewModel.loadMoreSearchResults() }
                            }
                        }
                }
                if viewModel.isSearchingPlaces {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
    }

    private func searchResultRow(_ place: PlaceSearchResult) -> some View {
        Button {
            viewModel.setStartFromCurrentLocation()
            viewModel.selectPlace(place, for: .destination)
            searchQuery = ""
            isSearchFieldFocused = false
            isSearchExpanded = false
            Task { await viewModel.searchRoute() }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(1)
                Text(place.address)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.7, green: 0.7, blue: 0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.top, 4)
        }
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
