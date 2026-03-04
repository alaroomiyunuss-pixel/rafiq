// PATH: ios-app/Rafiq/Features/Auth/
// FILENAME: SplashView.swift

import SwiftUI

// ============================================================
// MARK: - SplashViewModel
// ============================================================

@MainActor
final class SplashViewModel: ObservableObject {
    @Published var isAnimating = false
    @Published var isReady = false

    func startAnimation() {
        withAnimation(.easeOut(duration: 0.8)) {
            isAnimating = true
        }

        // Simulate loading (Firebase init, auth check, etc.)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.4)) {
                isReady = true
            }
        }
    }
}

// ============================================================
// MARK: - SplashView
// ============================================================

struct SplashView: View {
    @StateObject private var viewModel = SplashViewModel()
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    RafiqColors.primaryDarkFallback,
                    RafiqColors.primaryFallback,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: RafiqSpacing.xl) {
                Spacer()

                // Logo / Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .scaleEffect(viewModel.isAnimating ? 1.0 : 0.5)

                    Image(systemName: "car.2.fill")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(.white)
                        .scaleEffect(viewModel.isAnimating ? 1.0 : 0.3)
                        .opacity(viewModel.isAnimating ? 1.0 : 0)
                }

                // App name
                VStack(spacing: RafiqSpacing.sm) {
                    Text("رفيق")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(viewModel.isAnimating ? 1.0 : 0)
                        .offset(y: viewModel.isAnimating ? 0 : 20)

                    Text("رحلتك أسهل مع رفيق")
                        .font(RafiqFonts.body())
                        .foregroundStyle(.white.opacity(0.8))
                        .opacity(viewModel.isAnimating ? 1.0 : 0)
                        .offset(y: viewModel.isAnimating ? 0 : 10)
                }

                Spacer()

                // Loading indicator
                if !viewModel.isReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.1)
                        .padding(.bottom, RafiqSpacing.xxl)
                        .opacity(viewModel.isAnimating ? 1.0 : 0)
                }
            }
        }
        .onAppear {
            viewModel.startAnimation()
        }
        .onChange(of: viewModel.isReady) { _, ready in
            if ready { onFinished() }
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Splash Screen") {
    SplashView {
        print("Splash finished")
    }
    .environment(\.layoutDirection, .rightToLeft)
}
