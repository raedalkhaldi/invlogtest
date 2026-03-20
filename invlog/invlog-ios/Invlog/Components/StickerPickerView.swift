import SwiftUI
import Nuke
@preconcurrency import NukeUI

@MainActor
struct StickerPickerView: View {
    var onStickerSelected: (GiphySticker) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var stickers: [GiphySticker] = []
    @State private var isLoading = false
    @State private var selectedCategory: StickerCategory = .trending
    @State private var offset = 0
    @State private var hasMore = true

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    enum StickerCategory: String, CaseIterable {
        case trending = "Trending"
        case food = "Food"
        case drink = "Drink"
        case reactions = "Reactions"
        case love = "Love"
        case funny = "Funny"
        case celebrate = "Celebrate"

        var searchQuery: String? {
            switch self {
            case .trending: return nil
            case .food: return "food delicious yummy"
            case .drink: return "drink coffee tea"
            case .reactions: return "reaction face"
            case .love: return "love heart"
            case .funny: return "funny lol"
            case .celebrate: return "celebrate party"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Category strip
                categoryStrip

                Divider()

                // Sticker grid
                if isLoading && stickers.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if stickers.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(Color.brandTextTertiary)
                        Text("No stickers found")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    Spacer()
                } else {
                    stickerGrid
                }

                // Giphy attribution
                giphyAttribution
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadStickers()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.brandTextTertiary)
            TextField("Search stickers...", text: $searchText)
                .font(InvlogTheme.body(14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    Task {
                        offset = 0
                        stickers = []
                        await loadStickers()
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Task {
                        offset = 0
                        stickers = []
                        selectedCategory = .trending
                        await loadStickers()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.brandBorder.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Category Strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StickerCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        searchText = ""
                        Task {
                            offset = 0
                            stickers = []
                            await loadStickers()
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(InvlogTheme.body(13, weight: selectedCategory == category ? .semibold : .regular))
                            .foregroundColor(selectedCategory == category ? .white : Color.brandTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == category
                                    ? Capsule().fill(Color.brandPrimary)
                                    : Capsule().fill(Color.brandBorder.opacity(0.5))
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Sticker Grid

    private var stickerGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(stickers) { sticker in
                    Button {
                        onStickerSelected(sticker)
                        dismiss()
                    } label: {
                        stickerCell(sticker)
                    }
                    .buttonStyle(.plain)
                }

                // Load more trigger
                if hasMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task { await loadMore() }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func stickerCell(_ sticker: GiphySticker) -> some View {
        LazyImage(request: ImageRequest(url: sticker.previewUrl, processors: [])) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
            } else if state.isLoading {
                Color.brandBorder.opacity(0.3)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            } else {
                Color.brandBorder.opacity(0.3)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(Color.brandTextTertiary)
                    )
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Giphy Attribution

    private var giphyAttribution: some View {
        HStack {
            Spacer()
            Text("Powered by ")
                .font(InvlogTheme.caption(10))
                .foregroundColor(Color.brandTextTertiary)
            +
            Text("Tenor")
                .font(InvlogTheme.caption(10, weight: .bold))
                .foregroundColor(Color.brandTextTertiary)
            Spacer()
        }
        .padding(.vertical, 6)
        .background(Color.brandBackground)
    }

    // MARK: - Loading

    private func loadStickers() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let query = searchText.isEmpty ? selectedCategory.searchQuery : searchText
            let results: [GiphySticker]
            if let query = query {
                results = try await GiphyService.shared.search(query: query, offset: offset)
            } else {
                results = try await GiphyService.shared.trending(offset: offset)
            }
            stickers = results
            hasMore = results.count >= 25
        } catch {
            // Silently fail — show empty state
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        offset += 25
        isLoading = true

        do {
            let query = searchText.isEmpty ? selectedCategory.searchQuery : searchText
            let results: [GiphySticker]
            if let query = query {
                results = try await GiphyService.shared.search(query: query, offset: offset)
            } else {
                results = try await GiphyService.shared.trending(offset: offset)
            }
            stickers.append(contentsOf: results)
            hasMore = results.count >= 25
        } catch {
            // Silently fail
        }
        isLoading = false
    }
}
