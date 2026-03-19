import SwiftUI
@preconcurrency import NukeUI

struct MentionableTextField: View {
    @Binding var text: String
    let placeholder: String
    var axis: Axis = .vertical
    var lineLimit: ClosedRange<Int> = 2...5
    var foregroundColor: Color = Color.brandText

    @EnvironmentObject private var appState: AppState
    @State private var followingList: [User] = []
    @State private var hasFetchedFollowing = false
    @State private var showSuggestions = false
    @State private var mentionQuery = ""
    @FocusState private var isFocused: Bool

    private var filteredSuggestions: [User] {
        let query = mentionQuery.lowercased()
        let results: [User]
        if query.isEmpty {
            results = followingList
        } else {
            results = followingList.filter { user in
                user.username.lowercased().contains(query)
                    || (user.displayName?.lowercased().contains(query) ?? false)
            }
        }
        return Array(results.prefix(5))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Suggestion overlay positioned above the text field
            if showSuggestions && !filteredSuggestions.isEmpty {
                VStack(spacing: 0) {
                    suggestionList
                    Spacer().frame(height: 0)
                }
                .frame(maxWidth: .infinity)
                .zIndex(1)
            }

            textField
        }
        .onChange(of: text) { newValue in
            detectMention(in: newValue)
        }
    }

    // MARK: - Subviews

    private var textField: some View {
        TextField(placeholder, text: $text, axis: axis)
            .font(InvlogTheme.body(14))
            .foregroundColor(foregroundColor)
            .lineLimit(lineLimit)
            .focused($isFocused)
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(filteredSuggestions) { user in
                Button {
                    insertMention(user: user)
                } label: {
                    suggestionRow(user: user)
                }
                .buttonStyle(.plain)

                if user.id != filteredSuggestions.last?.id {
                    Divider()
                        .background(Color.brandBorder)
                }
            }
        }
        .background(Color.brandCard)
        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                .stroke(Color.brandBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        .padding(.bottom, 44)
    }

    private func suggestionRow(user: User) -> some View {
        HStack(spacing: 10) {
            LazyImage(url: user.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName ?? user.username)
                    .font(InvlogTheme.body(14, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(1)

                Text("@\(user.username)")
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Mention Logic

    private func detectMention(in text: String) {
        guard let lastMentionRange = findActiveMentionRange(in: text) else {
            showSuggestions = false
            mentionQuery = ""
            return
        }

        mentionQuery = String(text[lastMentionRange])
        showSuggestions = true
        fetchFollowingIfNeeded()
    }

    /// Finds the query portion after the active `@` symbol.
    /// An `@` is considered active if it is at the start of the text or preceded by a space/newline,
    /// and there is no space between the `@` and the cursor (end of string).
    private func findActiveMentionRange(in text: String) -> Range<String.Index>? {
        // Search backwards from the end for the last `@`
        guard let atIndex = text.lastIndex(of: "@") else { return nil }

        // The `@` must be at the start or preceded by whitespace
        if atIndex != text.startIndex {
            let charBefore = text[text.index(before: atIndex)]
            guard charBefore == " " || charBefore == "\n" else { return nil }
        }

        let afterAt = text.index(after: atIndex)

        // If `@` is at the very end, query is empty — show all suggestions
        guard afterAt <= text.endIndex else { return nil }

        let querySubstring = text[afterAt...]

        // If there's a space in the query portion, the mention is "closed" — no suggestions
        if querySubstring.contains(" ") || querySubstring.contains("\n") {
            return nil
        }

        return afterAt..<text.endIndex
    }

    private func insertMention(user: User) {
        guard let atIndex = text.lastIndex(of: "@") else { return }
        let prefix = text[text.startIndex...atIndex]
        text = prefix + user.username + " "
        showSuggestions = false
        mentionQuery = ""
    }

    // MARK: - API

    private func fetchFollowingIfNeeded() {
        guard !hasFetchedFollowing else { return }
        guard let userId = appState.currentUser?.id else { return }

        hasFetchedFollowing = true

        Task {
            do {
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .following(userId: userId, page: 1, perPage: 100),
                    responseType: [User].self
                )
                await MainActor.run {
                    followingList = data
                }
            } catch {
                hasFetchedFollowing = false
            }
        }
    }
}
