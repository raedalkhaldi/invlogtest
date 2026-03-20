import SwiftUI
import Nuke
@preconcurrency import NukeUI

/// Renders text content that may contain inline [sticker:URL] tokens.
/// Text parts render via MentionText (with @mention support).
/// Sticker tokens render as animated GIF images.
struct StickerContentView: View {
    let content: String
    var font: Font = InvlogTheme.body(14)
    var color: Color = Color.brandText
    var mentionColor: Color = Color.brandPrimary
    var lineLimit: Int? = nil
    var onMentionTap: ((String) -> Void)? = nil

    private struct ContentSegment: Identifiable {
        let id = UUID()
        enum Kind {
            case text(String)
            case sticker(URL)
        }
        let kind: Kind
    }

    private var segments: [ContentSegment] {
        var result: [ContentSegment] = []
        var remaining = content

        while let range = remaining.range(of: "[sticker:") {
            // Text before sticker
            let textBefore = String(remaining[remaining.startIndex..<range.lowerBound])
            if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(ContentSegment(kind: .text(textBefore)))
            }

            // Find closing bracket
            let afterPrefix = remaining[range.upperBound...]
            if let closingRange = afterPrefix.range(of: "]") {
                let urlStr = String(afterPrefix[afterPrefix.startIndex..<closingRange.lowerBound])
                if let url = URL(string: urlStr) {
                    result.append(ContentSegment(kind: .sticker(url)))
                }
                remaining = String(afterPrefix[closingRange.upperBound...])
            } else {
                // No closing bracket — treat rest as text
                result.append(ContentSegment(kind: .text(String(remaining[range.lowerBound...]))))
                remaining = ""
            }
        }

        // Remaining text
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(ContentSegment(kind: .text(remaining)))
        }

        return result
    }

    var body: some View {
        let segs = segments

        if segs.isEmpty {
            EmptyView()
        } else if segs.count == 1, case .text(let text) = segs[0].kind {
            // Pure text — use MentionText directly
            MentionText(
                content: text,
                font: font,
                color: color,
                mentionColor: mentionColor,
                lineLimit: lineLimit,
                onMentionTap: onMentionTap
            )
        } else {
            // Mixed content
            VStack(alignment: .leading, spacing: 6) {
                ForEach(segs) { segment in
                    switch segment.kind {
                    case .text(let text):
                        MentionText(
                            content: text,
                            font: font,
                            color: color,
                            mentionColor: mentionColor,
                            lineLimit: lineLimit,
                            onMentionTap: onMentionTap
                        )
                    case .sticker(let url):
                        AnimatedGIFView(url: url)
                            .frame(width: 140, height: 140)
                    }
                }
            }
        }
    }
}
