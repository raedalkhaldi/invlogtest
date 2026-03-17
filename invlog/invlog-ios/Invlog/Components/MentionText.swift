import SwiftUI

/// A Text view that renders @mentions as tappable links navigating to user profiles.
/// Usage: MentionText("Check out @john and @jane!", font: .body, color: .white)
struct MentionText: View {
    let content: String
    var font: Font = InvlogTheme.body(14)
    var color: Color = Color.brandText
    var mentionColor: Color = Color.brandPrimary
    var lineLimit: Int? = nil
    var onMentionTap: ((String) -> Void)? = nil

    var body: some View {
        mentionTextView()
    }

    @ViewBuilder
    private func mentionTextView() -> some View {
        let parts = parseMentions(content)

        if parts.contains(where: { $0.isMention }) {
            // Has mentions — use VStack of HFlows for tappable mentions
            WrappingMentionText(parts: parts, font: font, color: color, mentionColor: mentionColor, lineLimit: lineLimit, onMentionTap: onMentionTap)
        } else {
            // No mentions — simple text
            Text(content)
                .font(font)
                .foregroundColor(color)
                .lineLimit(lineLimit)
        }
    }

    private func parseMentions(_ text: String) -> [MentionPart] {
        var parts: [MentionPart] = []
        let pattern = "(^|\\s)@([a-zA-Z0-9._]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [MentionPart(text: text, isMention: false, username: nil)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var lastIndex = 0
        for match in matches {
            let fullRange = match.range
            let usernameRange = match.range(at: 2)
            let prefixRange = match.range(at: 1) // whitespace or start

            // Text before this mention (include any prefix whitespace as part of before-text)
            let beforeEnd = fullRange.location + prefixRange.length
            if lastIndex < beforeEnd {
                let beforeText = nsText.substring(with: NSRange(location: lastIndex, length: beforeEnd - lastIndex))
                if !beforeText.isEmpty {
                    parts.append(MentionPart(text: beforeText, isMention: false, username: nil))
                }
            }

            // The @mention itself
            let username = nsText.substring(with: usernameRange)
            parts.append(MentionPart(text: "@\(username)", isMention: true, username: username))

            lastIndex = fullRange.location + fullRange.length
        }

        // Remaining text after last mention
        if lastIndex < nsText.length {
            let remaining = nsText.substring(from: lastIndex)
            parts.append(MentionPart(text: remaining, isMention: false, username: nil))
        }

        if parts.isEmpty {
            parts.append(MentionPart(text: text, isMention: false, username: nil))
        }

        return parts
    }
}

struct MentionPart: Identifiable {
    let id = UUID()
    let text: String
    let isMention: Bool
    let username: String?
}

/// Uses Text concatenation for inline rendering with tappable mentions.
private struct WrappingMentionText: View {
    let parts: [MentionPart]
    let font: Font
    let color: Color
    let mentionColor: Color
    let lineLimit: Int?
    let onMentionTap: ((String) -> Void)?

    var body: some View {
        // Build attributed text using Text concatenation
        let attributedText = parts.reduce(Text("")) { result, part in
            if part.isMention {
                return result + Text(part.text)
                    .font(font)
                    .bold()
                    .foregroundColor(mentionColor)
            } else {
                return result + Text(part.text)
                    .font(font)
                    .foregroundColor(color)
            }
        }

        // If we have a tap handler, overlay invisible buttons for each mention
        if let onMentionTap = onMentionTap {
            attributedText
                .lineLimit(lineLimit)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "mention", let username = url.host {
                        onMentionTap(username)
                    }
                    return .handled
                })
        } else {
            attributedText
                .lineLimit(lineLimit)
        }
    }
}
