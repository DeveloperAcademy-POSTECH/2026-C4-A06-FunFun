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
                    cameraCommand: cameraCommand,
                    showLandmarks: viewModel.showLandmarks,
                    landmarkScaleThreshold: viewModel.landmarkMinZoom,
                    onMapTapped: { coordinate in
                        guard !viewModel.isNavigating, !isSearchExpanded else { return }
                        viewModel.selectCoordinateAsDestination(coordinate)
                    }
                )
            )
                .ignoresSafeArea()

            if viewModel.isNavigating && viewModel.showGradientOverlay {
                HeadingSafeAreaGradientOverlay(heading: viewModel.currentHeading)
                    .ignoresSafeArea()
            }

            VStack(spacing: 12) {
                HStack {
                    if viewModel.route != nil || viewModel.isNavigating || viewModel.tappedCoordinate != nil {
                        backButton
                    }
                    Spacer()
                    settingsButton
                }

                if viewModel.isNavigating {
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
                    if viewModel.isNavigating {
                        navigationInfoPanel(route: route)
                    } else {
                        routeSummary(route)
                    }
                } else if viewModel.tappedCoordinate != nil {
                    tappedDestinationPanel
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
        .sheet(isPresented: $isSearchExpanded) {
            WalkingSearchModalView(
                viewModel: viewModel,
                isPresented: $isSearchExpanded,
                searchQuery: $searchQuery
            )
                .presentationDetents([.fraction(0.9)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }

    private var backButton: some View {
        Button {
            viewModel.clearTappedCoordinate()
            Task { await viewModel.dismissRoute() }
            issueCameraCommand(.userLocation)
        } label: {
            ZStack {
                Circle()
                    //.fill(Color.white.opacity(0.05))
                    //.background(.ultraThinMaterial, in: Circle())
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                Image(systemName: "chevron.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("Colors/text-text-1"))
            }
        }
    }

    @State private var showSettings = false

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                Form {
                    Section("Compact 표시") {
                        Toggle("남은 거리를 시간(분)으로 표시", isOn: $viewModel.showTimeInsteadOfDistance)
                            .onChange(of: viewModel.showTimeInsteadOfDistance) {
                                viewModel.refreshLiveActivity()
                            }
                    }
                    Section("화면 효과") {
                        Toggle("그라디언트 오버레이", isOn: $viewModel.showGradientOverlay)
                    }
                    Section("지도") {
                        Toggle("랜드마크 표시", isOn: $viewModel.showLandmarks)
                        if viewModel.showLandmarks {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("축척 \(Int(viewModel.landmarkMinZoom))m 이하에서 표시")
                                    .font(.subheadline)
                                Slider(value: $viewModel.landmarkMinZoom, in: 10...100, step: 10)
                            }
                        }
                    }
                    Section("Approaching 기준 거리") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Int(viewModel.approachingThreshold))m")
                                .font(.subheadline.monospacedDigit())
                            Slider(value: $viewModel.approachingThreshold, in: 0...30, step: 1)
                                .onChange(of: viewModel.approachingThreshold) {
                                    viewModel.refreshLiveActivity()
                                }
                        }
                    }
                }
                .navigationTitle("설정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("닫기") { showSettings = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var tappedDestinationPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text(viewModel.destinationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }

            Button {
                Task { await viewModel.searchRoute() }
            } label: {
                Label("경로 찾기", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
    }

    private var homeSearchPanel: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 51, height: 5)

            Button {
                isSearchExpanded = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color("Colors/text-text-1"))

                    Text("어디로 갈까요?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))

                    Spacer()

                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color("Colors/text-text-1"))
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
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1, green: 0.882, blue: 0.627))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(red: 1, green: 0.714, blue: 0.098))
                }

                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.isRerouting {
                        Text("경로 재탐색 중…")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    } else {
                        Text("경로에서 벗어난 것 같아요")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("현재 위치에서 재탐색할까요?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                    }
                }

                Spacer()

                if viewModel.isRerouting {
                    ProgressView()
                }
            }

            if !viewModel.isRerouting {
                VStack(spacing: 6) {
                    Button {
                        Task { await viewModel.rerouteFromCurrentLocation() }
                    } label: {
                        Text("재탐색")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.075, green: 0.42, blue: 1))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 0.678, green: 0.8, blue: 1).opacity(0.8), in: Capsule())

                    Button {
                        viewModel.keepCurrentRoute()
                    } label: {
                        Text("기존 경로 유지")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 0.9, green: 0.9, blue: 0.9), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 25))
    }

    private func navigationInfoPanel(route: WalkingRoute) -> some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 5)

            if let progress = viewModel.progress, let maneuver = progress.nextManeuver {
                HStack(spacing: 16) {
                    Image(systemName: maneuver.turn.symbolName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.blue)
                        .frame(width: 80, height: 80)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 40))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(maneuver.instruction)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(2)

                        if let nextLandmarkName = nextLandmarkName(after: maneuver, in: route) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("다음")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(white: 0.565))
                                Text(nextLandmarkName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 30))
    }

    private func nextLandmarkName(after current: WalkingManeuver, in route: WalkingRoute) -> String? {
        guard let index = route.maneuvers.firstIndex(where: { $0.id == current.id }) else { return nil }
        let next = route.maneuvers.index(after: index)
        guard next < route.maneuvers.endIndex else { return nil }
        return route.maneuvers[next].landmark?.name
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
