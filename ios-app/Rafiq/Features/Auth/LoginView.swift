// PATH: ios-app/Rafiq/Features/Auth/
// FILENAME: LoginView.swift

import SwiftUI

// ============================================================
// MARK: - LoginViewModel
// ============================================================

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Saudi country code fixed for MVP
    let countryCode = "+966"
    let maxDigits = 9

    var fullPhone: String {
        countryCode + phoneNumber
    }

    var isValid: Bool {
        phoneNumber.count == maxDigits && phoneNumber.allSatisfy(\.isNumber)
    }

    var formattedPreview: String {
        guard !phoneNumber.isEmpty else { return "+966 5X XXX XXXX" }
        return countryCode + " " + phoneNumber
    }

    func sendOTP(
        auth: AuthServiceProtocol,
        onSent: @escaping (String, String) -> Void
    ) {
        guard isValid else {
            errorMessage = "رقم الجوال يجب أن يكون 9 أرقام"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let verificationId = try await auth.sendOTP(phone: fullPhone)
                onSent(verificationId, fullPhone)
            } catch {
                errorMessage = "فشل إرسال رمز التحقق. تأكد من الرقم وحاول مرة أخرى"
            }
            isLoading = false
        }
    }
}

// ============================================================
// MARK: - AuthLoginView
// ============================================================

struct AuthLoginView: View {
    let onOTPSent: (String, String) -> Void

    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var viewModel = LoginViewModel()
    @FocusState private var isPhoneFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.lg) {
                Spacer().frame(height: RafiqSpacing.xxl)

                // Header
                header

                Spacer().frame(height: RafiqSpacing.lg)

                // Phone input
                phoneInput

                // Error banner
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                // Send OTP button
                PrimaryButton(
                    title: "إرسال رمز التحقق",
                    icon: "paperplane.fill",
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isValid
                ) {
                    viewModel.sendOTP(auth: environment.auth, onSent: onOTPSent)
                }

                // Terms
                termsText

                Spacer()

                // Support
                supportLink
            }
            .padding(.horizontal, RafiqSpacing.md)
        }
        .background(RafiqColors.backgroundFallback)
        .onAppear {
            isPhoneFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: RafiqSpacing.md) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(RafiqColors.primaryFallback)
                .frame(width: 80, height: 80)
                .background(RafiqColors.primaryFallback.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))

            Text("مرحباً بك في رفيق")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("أدخل رقم جوالك السعودي للبدء")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
    }

    // MARK: - Phone Input

    private var phoneInput: some View {
        AppCard {
            VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                Text("رقم الجوال")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)

                HStack(spacing: RafiqSpacing.sm) {
                    // Country code badge
                    HStack(spacing: 4) {
                        Text("🇸🇦")
                            .font(.system(size: 20))
                        Text("+966")
                            .font(RafiqFonts.bodyBold())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)
                    }
                    .padding(.horizontal, RafiqSpacing.sm)
                    .padding(.vertical, RafiqSpacing.sm)
                    .background(RafiqColors.backgroundFallback)
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))

                    // Phone number field
                    TextField("5XXXXXXXX", text: $viewModel.phoneNumber)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .focused($isPhoneFocused)
                        .onChange(of: viewModel.phoneNumber) { _, newValue in
                            viewModel.phoneNumber = String(
                                newValue.filter(\.isNumber).prefix(viewModel.maxDigits)
                            )
                        }
                }

                // Character count
                HStack {
                    Spacer()
                    Text("\(viewModel.phoneNumber.count)/\(viewModel.maxDigits)")
                        .font(RafiqFonts.small())
                        .foregroundStyle(
                            viewModel.isValid
                                ? RafiqColors.successFallback
                                : RafiqColors.textSecondaryFallback
                        )
                }
            }
        }
    }

    // MARK: - Terms

    private var termsText: some View {
        Text("بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية")
            .font(RafiqFonts.small())
            .foregroundStyle(RafiqColors.textSecondaryFallback)
            .multilineTextAlignment(.center)
            .padding(.horizontal, RafiqSpacing.lg)
    }

    // MARK: - Support

    private var supportLink: some View {
        Button {
            if let url = DeepLinks.saudiSupportURL() {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: RafiqSpacing.xs) {
                Image(systemName: "questionmark.circle")
                Text("تحتاج مساعدة؟")
            }
            .font(RafiqFonts.caption())
            .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
        .padding(.bottom, RafiqSpacing.lg)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Login") {
    AuthLoginView { verificationId, phone in
        print("OTP sent: \(verificationId) to \(phone)")
    }
    .environmentObject(AppEnvironment.preview())
    .environment(\.layoutDirection, .rightToLeft)
}
