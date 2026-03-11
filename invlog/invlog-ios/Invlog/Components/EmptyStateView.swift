import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let description: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(Color.brandTextTertiary)
            Text(title)
                .font(InvlogTheme.heading(18, weight: .bold))
                .foregroundColor(Color.brandText)
            Text(description)
                .font(InvlogTheme.body(14))
                .foregroundColor(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
            if let buttonTitle, let buttonAction {
                Button(buttonTitle, action: buttonAction)
                    .buttonStyle(InvlogAccentButtonStyle())
                    .padding(.horizontal, 48)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
