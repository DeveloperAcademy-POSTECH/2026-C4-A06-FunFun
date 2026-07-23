//
//  WalkingSearchModalView.swift
//  LiveActivity_Practice
//

import SwiftUI

struct WalkingSearchModalView: View {
    @ObservedObject var viewModel: WalkingNavigationViewModel
    @Binding var isPresented: Bool
    @Binding var searchQuery: String

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            searchBar

            if !viewModel.placeSearchResults.isEmpty || viewModel.isSearchingPlaces {
                searchResultsContainer
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(red: 233 / 255, green: 233 / 255, blue: 238 / 255)
                .opacity(0.1)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .onAppear {
            isSearchFieldFocused = true
        }
        .onDisappear {
            isSearchFieldFocused = false
        }
        .task(id: searchQuery) {
            guard isPresented else { return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.searchPlaces(keyword: searchQuery)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(.systemGray))

            TextField("어디로 갈까요?", text: $searchQuery)
                .appTypography(.labelL)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 50)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 25))
        .padding(.horizontal, 12)
    }

    private var searchResultsContainer: some View {
        WalkingSearchResultsTableView(
            places: displayedSearchResults,
            isLoading: viewModel.isSearchingPlaces,
            onSelect: selectPlace,
            onLoadMore: {
                Task {
                    await viewModel.loadMoreSearchResults()
                }
            }
        )
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 30))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
    }

    private var displayedSearchResults: [PlaceSearchResult] {
        var seenPlaces = Set<String>()

        return viewModel.placeSearchResults.filter { place in
            let name = place.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let address = place.address
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let placeKey = "\(name)|\(address)"

            return seenPlaces.insert(placeKey).inserted
        }
    }

    private func selectPlace(_ place: PlaceSearchResult) {
        viewModel.setStartFromCurrentLocation()
        viewModel.selectPlace(place, for: .destination)
        searchQuery = ""
        isSearchFieldFocused = false
        isPresented = false
    }
}
