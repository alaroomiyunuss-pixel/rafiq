// PATH: ios-app/Rafiq/Features/Auth/
// FILENAME: AuthContainerView.swift

import SwiftUI

// ============================================================
// MARK: - AuthContainerViewModel
// ============================================================

@MainActor
final class AuthContainerViewModel: ObservableObject {
    enum AuthStep {
        case splash
        case login
        case otp(verificationId: String, phone: String)
        case register(phone: String)
    }

    @Published var currentStep: AuthStep = .splash
    @Published var isTransitioning = false

    func showLogin() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .login
        }
    }

    func showOTP(verificationId: String, phone: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .otp(verificationId: verificationId, phone: phone)
        }
    }

    func showRegister(phone: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .register(phone: phone)
        }
    }

    func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .otp:
                currentStep = .login
            case .register:
                currentStep = .login
            default:
                break
            }
        }
    }
}

// ============================================================
// MARK: - AuthContainerView
// ============================================================

struct AuthContainerView: View {
    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var viewModel = AuthContainerViewModel()

    var body: some View {
        ZStack {
            RafiqColors.backgroundFallback
                .ignoresSafeArea()

            switch viewModel.currentStep {
            case .splash:
                SplashView {
                    viewModel.showLogin()
                }
                .transition(.opacity)

            case .login:
                AuthLoginView(
                    onOTPSent: { verificationId, phone in
                        viewModel.showOTP(verificationId: verificationId, phone: phone)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .otp(let verificationId, let phone):
                OTPVerifyView(
                    verificationId: verificationId,
                    phone: phone,
                    onVerified: { user in
                        if user.name.isEmpty {
                            viewModel.showRegister(phone: phone)
                        } else {
                            // User exists, go to main
                            environment.currentUser = user
                            environment.isLoggedIn = true
                        }
                    },
                    onBack: {
                        viewModel.goBack()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .register(let phone):
                AuthRegisterView(
                    phone: phone,
                    onComplete: { user in
                        environment.currentUser = user
                        environment.isLoggedIn = true
                    },
                    onBack: {
                        viewModel.goBack()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: String(describing: viewModel.currentStep))
    }
}

// ============================================================
// MARK: - OTP Verify View (inline — part of auth flow)
// ============================================================

@MainActor
final class OTPVerifyViewModel: ObservableObject {
    @Published var code = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var resendCountdown = 60
    @Published var canResend = false

    private var timer: Timer?

    func startCountdown() {
        resendCountdown = 60
        canResend = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.resendCountdown -= 1
                if self.resendCountdown <= 0 {
                    self.canResend = true
                    self.timer?.invalidate()
                }
            }
        }
    }

    func verify(
        verificationId: String,
        auth: AuthServiceProtocol,
        onVerified: @escaping (AppUser) -> Void
    ) {
        guard code.count == 6 else {
            errorMessage = "الرمز يجب أن يكون 6 أرقام"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await auth.verifyOTP(verificationId: verificationId, code: code)
                onVerified(user)
            } catch {
                errorMessage = "رمز التحقق غير صحيح. حاول مرة أخرى"
            }
            isLoading = false
        }
    }

    deinit {
        timer?.invalidate()
    }
}

struct OTPVerifyView: View {
    let verificationId: String
    let phone: String
    let onVerified: (AppUser) -> Void
    let onBack: () -> Void

    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var viewModel = OTPVerifyViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: RafiqSpacing.lg) {
            // Header
            VStack(spacing: RafiqSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(RafiqColors.primaryFallback)

                Text("رمز التحقق")
                    .font(RafiqFonts.heading1())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                Text("أدخل الرمز المرسل إلى \(phone)")
                    .font(RafiqFonts.body())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, RafiqSpacing.xxl)

            // OTP Input
            TextField("000000", text: $viewModel.code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .onChange(of: viewModel.code) { _, newValue in
                    viewModel.code = String(newValue.prefix(6)).filter(\.isNumber)
                }
                .padding()
                .background(RafiqColors.surfaceFallback)
                .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
                .padding(.horizontal, RafiqSpacing.xxl)

            // Error
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            // Verify button
            PrimaryButton(
                title: "تحقق",
                icon: "checkmark.shield.fill",
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.code.count < 6
            ) {
                viewModel.verify(
                    verificationId: verificationId,
                    auth: environment.auth,
                    onVerified: onVerified
                )
            }
            .padding(.horizontal, RafiqSpacing.md)

            // Resend
            if viewModel.canResend {
                Button("إعادة إرسال الرمز") {
                    viewModel.startCountdown()
                    // TODO: Call auth.sendOTP again
                }
                .font(RafiqFonts.bodyBold())
                .foregroundStyle(RafiqColors.primaryFallback)
            } else {
                Text("إعادة الإرسال بعد \(viewModel.resendCountdown) ثانية")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }

            Spacer()

            // Back
            Button {
                onBack()
            } label: {
                HStack(spacing: RafiqSpacing.xs) {
                    Image(systemName: "chevron.right")
                    Text("رجوع")
                }
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
            }
            .padding(.bottom, RafiqSpacing.lg)
        }
        .onAppear {
            isFocused = true
            viewModel.startCountdown()
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Auth Container") {
    AuthContainerView()
        .environmentObject(AppEnvironment.preview())
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("OTP View") {
    OTPVerifyView(
        verificationId: "mock_id",
        phone: "+966501234567",
        onVerified: { _ in },
        onBack: {}
    )
    .environmentObject(AppEnvironment.preview())
    .environment(\.layoutDirection, .rightToLeft)
}
