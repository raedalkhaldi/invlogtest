import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    .init(color: Color.brandBorder.opacity(0.6), location: max(0, phase - 0.3)),
                    .init(color: Color.brandBorder, location: phase),
                    .init(color: Color.brandBorder.opacity(0.6), location: min(1, phase + 0.3)),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
        }
    }
}
