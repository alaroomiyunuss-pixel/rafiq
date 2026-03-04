// PATH: ios-app/Rafiq/Features/Auth/
// FILENAME: RegisterView.swift

import SwiftUI

// ============================================================
// MARK: - RegisterViewModel
// ============================================================

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name = ""
    @Published var selectedRole: UserRole = .passenger
    @Published var isLoading = false
    @Published var errorMessage: String?

    let availableRoles: [(UserRole, String, String)] = [
        (.passenger, "راكب", "person.fill"),
        (.driver, "سائق", "car.fill"),
        (.both, "راكب وسائق", "person.2.fill"),
    ]

    var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 50
    }

    func register(
        auth: AuthServiceProtocol,
        onComplete: @escaping (AppUser) -> Void
    ) {
        guard isValid else {
            errorMessage = "الاسم يجب أن يكون حرفين على الأقل"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await auth.updateProfile(
                    name: name.trimmingCharacters(in: .whitespaces),
                    photoURL: nil
                )
                onComplete(user)
            } catch {
                errorMessage = "فشل في إنشاء الحساب. حاول مرة أخرى"
            }
            isLoading = false
        }
    }
}

// ============================================================
// MARK: - AuthRegisterView
// ============================================================

struct AuthRegisterView: View {
    let phone: String
    let onComplete: (AppUser) -> Void
    let onBack: () -> Void

    @EnvironmentObject var environment: AppEnvironment
    @StateObject private var viewModel = RegisterViewModel()
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.lg) {
                Spacer().frame(height: RafiqSpacing.xl)

                // Header
                header

                // Name input
                nameInput

                // Role selection
                roleSelection

                // Error
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                // Register button
                PrimaryButton(
                    title: "إنشاء الحساب",
                    icon: "person.badge.plus",
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isValid
                ) {
                    viewModel.register(
                        auth: environment.auth,
                        onComplete: onComplete
                    )
                }

                // Info note
                infoNote

                Spacer()

                // Back button
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
            .padding(.horizontal, RafiqSpacing.md)
        }
        .background(RafiqColors.backgroundFallback)
        .onAppear {
            isNameFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: RafiqSpacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(RafiqColors.primaryFallback)

            Text("أكمل ملفك الشخصي")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("خطوة أخيرة قبل البدء")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)

            // Phone badge
            HStack(spacing: RafiqSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RafiqColors.successFallback)
                    .font(.system(size: 14))
                Text(phone)
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.xs)
            .background(RafiqColors.successFallback.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    // MARK: - Name Input

    private var nameInput: some View {
        AppCard {
            VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                Text("الاسم الكامل")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)

                TextField("أدخل اسمك", text: $viewModel.name)
                    .font(RafiqFonts.heading3())
                    .textContentType(.name)
                    .focused($isNameFocused)
                    .onChange(of: viewModel.name) { _, newValue in
                        viewModel.name = String(newValue.prefix(50))
                    }

                if !viewModel.name.isEmpty {
                    Text("\(viewModel.name.count)/50")
                        .font(RafiqFonts.small())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Role Selection

    private var roleSelection: some View {
        VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
            Text("كيف تبي تستخدم رفيق؟")
                .font(RafiqFonts.bodyBold())
                .foregroundStyle(RafiqColors.textPrimaryFallback)
                .padding(.horizontal, RafiqSpacing.xs)

            VStack(spacing: RafiqSpacing.sm) {
                ForEach(viewModel.availableRoles, id: \.0) { role, label, icon in
                    roleCard(role: role, label: label, icon: icon)
                }
            }
        }
    }

    private func roleCard(role: UserRole, label: String, icon: String) -> some View {
        let isSelected = viewModel.selectedRole == role

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedRole = role
            }
        } label: {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? .white : RafiqColors.primaryFallback)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? RafiqColors.primaryFallback
                            : RafiqColors.primaryFallback.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    Text(roleDescription(role))
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isSelected ? RafiqColors.primaryFallback : RafiqColors.textSecondaryFallback.opacity(0.4)
                    )
            }
            .padding(RafiqSpacing.md)
            .background(RafiqColors.surfaceFallback)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: RafiqRadius.md)
                    .stroke(
                        isSelected ? RafiqColors.primaryFallback : Color.clear,
                        lineWidth: 2
                    )
            }
            .rafiqShadow(isSelected ? .medium : .light)
        }
    }

    private func roleDescription(_ role: UserRole) -> String {
        switch role {
        case .passenger: return "ابحث عن رحلات واحجز مقعدك"
        case .driver: return "أنشئ رحلات واستقبل ركاب"
        case .both: return "استخدم التطبيق كراكب وسائق"
        default: return ""
        }
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(alignment: .top, spacing: RafiqSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(RafiqColors.accentFallback)
                .font(.system(size: 16))

            Text("يمكنك تغيير دورك لاحقاً من الإعدادات. السائقين سيحتاجون إضافة مركبة قبل إنشاء رحلات.")
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
        .padding(RafiqSpacing.md)
        .background(RafiqColors.accentFallback.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Register") {
    AuthRegisterView(
        phone: "+966501234567",
        onComplete: { user in
            print("Registered: \(user.name)")
        },
        onBack: {}
    )
    .environmentObject(AppEnvironment.preview())
    .environment(\.layoutDirection, .rightToLeft)
}
