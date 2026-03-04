// PATH: ios-app/Rafiq/Components/
// FILENAME: LoadingView.swift

import SwiftUI

struct LoadingView: View {
    var message: String = "جاري التحميل..."
    var showBackground: Bool = true

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: RafiqSpacing.lg) {
            // Animated dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(RafiqColors.primaryFallback)
                        .frame(width: 12, height: 12)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .opacity(isAnimating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }

            Text(message)
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(showBackground ? RafiqColors.backgroundFallback : .clear)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Inline Loading (for buttons / small areas)

struct InlineLoadingView: View {
    var size: CGFloat = 20
    var color: Color = RafiqColors.primaryFallback

    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: color))
            .scaleEffect(size / 20)
    }
}

// MARK: - Overlay Loading

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    var message: String = "جاري التحميل..."

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: RafiqSpacing.md) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text(message)
                                .font(RafiqFonts.body())
                                .foregroundStyle(.white)
                        }
                        .padding(RafiqSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isLoading)
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool, message: String = "جاري التحميل...") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

// MARK: - Preview

#Preview("Loading Views") {
    VStack(spacing: RafiqSpacing.xl) {
        LoadingView()
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))

        LoadingView(message: "جاري البحث عن رحلات...")
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))

        HStack {
            InlineLoadingView()
            Text("جاري الحفظ")
                .font(RafiqFonts.caption())
        }
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}
