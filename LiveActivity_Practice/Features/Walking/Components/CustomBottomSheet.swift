//
//  CustomBottomSheet.swift
//  LiveActivity_Practice
//

import SwiftUI

/// 도보 안내를 접힘/펼침 형태로 보여주는 바텀 시트입니다.
///     /// - Parameters:
///   - route: 표시할 전체 도보 경로입니다.
///   - progress: 현재 위치를 기준으로 계산된 경로 진행 정보입니다.
///   - destinationName: 하단에 표시할 목적지 이름입니다.
///   - isExpanded: 펼침 상태를 외부에서 제어하기 위한 바인딩입니다.
///   - expandedHeight: 펼친 콘텐츠의 높이입니다.
///
struct CustomBottomSheet: View {
    // MARK: - Inputs

    let route: WalkingRoute
    let progress: WalkingProgress?
    let destinationName: String

    // MARK: - Expansion State

    private let expandedHeight: CGFloat
    private let expansionBinding: Binding<Bool>?
    @State private var internalIsExpanded: Bool
    
    init(
        route: WalkingRoute,
        progress: WalkingProgress?,
        destinationName: String = "목적지",
        isExpanded: Binding<Bool>? = nil,
        expandedHeight: CGFloat = 500
    ) {
        self.route = route
        self.progress = progress
        self.destinationName = destinationName
        self.expansionBinding = isExpanded
        self.expandedHeight = expandedHeight
        _internalIsExpanded = State(initialValue: isExpanded?.wrappedValue ?? false)
    }

    // MARK: - Route Presentation Values

    private var isExpanded: Bool {
        expansionBinding?.wrappedValue ?? internalIsExpanded
    }

    private var currentManeuver: WalkingManeuver? {
        progress?.nextManeuver ?? orderedManeuvers.first
    }

    private var orderedManeuvers: [WalkingManeuver] {
        route.maneuvers.sorted {
            if $0.routeIndex == $1.routeIndex { return $0.id < $1.id }
            return $0.routeIndex < $1.routeIndex
        }
    }

    private var upcomingManeuvers: [WalkingManeuver] {
        guard let currentManeuver else { return orderedManeuvers }
        return orderedManeuvers.filter {
            $0.routeIndex > currentManeuver.routeIndex && $0.turn != .destination
        }
    }

    private var sheetCornerRadius: CGFloat {
        isExpanded ? 60 : 120
    }

    // MARK: - Main Layout

    var body: some View {
        VStack(spacing: 0) {
            expansionButton
                .contentShape(Rectangle())
                .onTapGesture {
                    setExpanded(!isExpanded)
                }
                .simultaneousGesture(expansionDragGesture)

            VStack(spacing: 0) {
                currentInstructionCard(isInset: isExpanded)
                    .padding(.leading, isExpanded ? 12 : 30)
                    .padding(.trailing, isExpanded ? 12 : 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        setExpanded(!isExpanded)
                    }
                    .simultaneousGesture(expansionDragGesture)

                if isExpanded {
                    expandedRouteDetails
                        .padding(.top, 10)
                        .transition(
                            .opacity.combined(
                                with: .move(edge: .bottom)
                            )
                        )
                }
            }
            .padding(.bottom, isExpanded ? 16 : 20)
            .frame(
                height: isExpanded ? expandedHeight : 100,
                alignment: .top
            )
        }
        .frame(maxWidth: .infinity)
        .modifier(
            BottomSheetGlassSurface(
                cornerRadius: sheetCornerRadius
            )
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 5)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: isExpanded)
        .contentShape(
            RoundedRectangle(
                cornerRadius: sheetCornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: isExpanded ? "전체 경로 접기" : "전체 경로 펼치기") {
            setExpanded(!isExpanded)
        }
    }

    // MARK: - Expansion Controls

    private var expansionButton: some View {
        Capsule()
            .fill(Color(white: 0.64))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 5)
            .accessibilityHidden(true)
    }

    private var expansionDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let verticalDistance = value.translation.height
                let horizontalDistance = value.translation.width

                guard abs(verticalDistance) > abs(horizontalDistance),
                      abs(verticalDistance) >= 40 else { return }

                setExpanded(verticalDistance < 0)
            }
    }

    // MARK: - Expanded Route Content

    private var expandedRouteDetails: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(upcomingManeuvers) { maneuver in
                    VStack(spacing: 8) {
                        upcomingRow(maneuver)

                        Divider()
                            .overlay(Color(white: 0.82))
                            .padding(.horizontal, 14)
                    }
                    .padding(.bottom, 7)
                }

                destinationFooter
                    .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 20)
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Current Maneuver

    @ViewBuilder
    private func currentInstructionCard(isInset: Bool) -> some View {
        if let maneuver = currentManeuver {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: isInset ? 4 : 3) {
                    Text("남은 거리 \(distanceText(progress?.distanceToNextManeuver ?? route.totalDistance))")
                        .appTypography(isInset ? .labelM : .labelL)
                        .foregroundStyle(Color(white: 0.5))

                    Text(instructionText(for: maneuver))
                        .appTypography(isInset ? .title3 : .title2)
                        .foregroundStyle(.black)
                        .frame(
                            maxWidth: isInset ? .infinity : 200,
                            alignment: .leading
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                }
                .padding(.leading, isInset ? 6 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: maneuver.turn.symbolName)
                    .font(.system(size: isInset ? 42 : 54, weight: .semibold))
                    .foregroundStyle(Color(red: 0.075, green: 0.42, blue: 1))
                    .frame(
                        width: isInset ? 62 : 80,
                        height: isInset ? 62 : 80
                    )
            }
            .padding(.leading, isInset ? 24 : 0)
            .padding(.trailing, isInset ? 20 : 0)
            .frame(height: isInset ? 94 : 80)
            .background {
                Capsule()
                    .fill(.black.opacity(isInset ? 0.1 : 0))
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack {
                Text("경로 안내를 확인해 주세요")
                    .appTypography(.labelL)
                Spacer()
                Image(systemName: "figure.walk")
                    .font(.title)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 80)
        }
    }

    // MARK: - Upcoming Maneuvers

    private func upcomingRow(_ maneuver: WalkingManeuver) -> some View {
        HStack(spacing: 16) {
            Text(maneuver.landmark?.name ?? shortInstruction(for: maneuver))
                .appTypography(.labelL)
                .foregroundStyle(Color(white: 0.5))
                .lineLimit(2)

            Spacer(minLength: 8)

            Image(systemName: maneuver.turn.symbolName)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color(red: 0.60, green: 0.75, blue: 1))
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Destination

    private var destinationFooter: some View {
        HStack(spacing: 10) {
            Image("ic-arrival")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            Text(destinationName.isEmpty ? "목적지" : destinationName)
                .appTypography(.labelL)
                .foregroundStyle(Color(white: 0.5))
                .lineLimit(2)

            Spacer(minLength: 8)

            Text("남은 시간 \(remainingMinutes)분")
                .appTypography(.captionM)
                .foregroundStyle(Color(white: 0.5))
                .fixedSize()
        }
        .frame(height: 60)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Route Text Formatting

    private var remainingMinutes: Int {
        guard route.totalDistance > 0, let progress else {
            return max(1, Int(ceil(Double(route.totalTime) / 60)))
        }
        let remainingSeconds = Double(route.totalTime) * Double(progress.remainingDistance) / Double(route.totalDistance)
        return max(1, Int(ceil(remainingSeconds / 60)))
    }

    private func instructionText(for maneuver: WalkingManeuver) -> String {
        guard let landmark = maneuver.landmark else { return maneuver.description }
        let direction = switch maneuver.turn {
        case .left, .slightLeft: "왼쪽"
        case .right, .slightRight: "오른쪽"
        case .straight: "직진"
        case .crosswalk: "횡단보도 건너기"
        case .stairs: "계단 이용"
        case .destination: "목적지 도착"
        case .unknown: "이동"
        }
        return "\(landmark.name)에서 \(direction)"
    }

    private func shortInstruction(for maneuver: WalkingManeuver) -> String {
        switch maneuver.turn {
        case .left, .slightLeft: "왼쪽으로 이동"
        case .right, .slightRight: "오른쪽으로 이동"
        case .straight: "직진"
        case .crosswalk: "횡단보도"
        case .stairs: "계단"
        case .destination: "목적지"
        case .unknown: maneuver.description
        }
    }

    private func setExpanded(_ expanded: Bool) {
        if let expansionBinding {
            expansionBinding.wrappedValue = expanded
        } else {
            internalIsExpanded = expanded
        }
    }

    private func distanceText(_ meters: Int) -> String {
        meters >= 1_000
            ? String(format: "%.1fkm", Double(meters) / 1_000)
            : "\(meters)m"
    }
}

// MARK: - Version-Adaptive Glass Surface

private struct BottomSheetGlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular,
                    in: shape
                )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .stroke(
                            .white.opacity(0.5),
                            lineWidth: 1
                        )
                }
        }
    }
}

// MARK: - Preview

#Preview("Custom Bottom Sheet") {
    @Previewable @State var isExpanded = false

    let coordinate = Coordinate(
        latitude: 37.5663,
        longitude: 126.9779
    )

    let maneuver = WalkingManeuver(
        id: 0,
        coordinate: coordinate,
        turn: .left,
        description: "효자중학교에서 왼쪽",
        routeIndex: 0,
        landmark: nil
    )

    ZStack(alignment: .bottom) {
        LinearGradient(
            colors: [
                .blue,
                .purple,
                .orange,
                .green
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        CustomBottomSheet(
            route: WalkingRoute(
                totalDistance: 800,
                totalTime: 600,
                path: [],
                maneuvers: [maneuver]
            ),
            progress: WalkingProgress(
                remainingDistance: 600,
                distanceToNextManeuver: 30,
                nextManeuver: maneuver,
                isOffRoute: false,
                isApproachingTurn: true,
                estimatedArrival: Date().addingTimeInterval(600)
            ),
            destinationName: "쿨오프",
            isExpanded: $isExpanded,
            expandedHeight: 500
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}
