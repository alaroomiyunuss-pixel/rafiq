// PATH: ios-app/Rafiq/Features/Profile/
// FILENAME: ProfileView.swift

import SwiftUI

// ============================================================
// MARK: - ProfileViewModel
// ============================================================

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoggingOut = false
    @Published var showLogoutConfirm = false
    @Published var showEditName = false
    @Published var editedName = ""
    @Published var isSavingName = false
    @Published var errorMessage: String?

    func startEditingName(current: String) {
        editedName = current
        showEditName = true
    }

    func saveName(auth: AuthServiceProtocol, onSuccess: @escaping (AppUser) -> Void) {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            errorMessage = "الاسم يجب أن يكون حرفين على الأقل"
            return
        }

        isSavingName = true
        errorMessage = nil

        Task {
            do {
                let updated = try await auth.updateProfile(name: trimmed, photoURL: nil)
                onSuccess(updated)
                showEditName = false
            } catch {
                errorMessage = "فشل في تحديث الاسم"
            }
            isSavingName = false
        }
    }

    func logout(auth: AuthServiceProtocol, onDone: @escaping () -> Void) {
        isLoggingOut = true
        do {
            try auth.signOut()
            onDone()
        } catch {
            errorMessage = "فشل في تسجيل الخروج"
        }
        isLoggingOut = false
    }
}

// ============================================================
// MARK: - ProfileView
// ============================================================

struct ProfileFullView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ProfileViewModel()

    private var user: AppUser? { environment.currentUser }

    var body: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.md) {
                // Avatar + Name
                profileHeader

                // Stats card
                statsCard

                // Menu sections
                accountSection
                driverSection
                supportSection
                legalSection
                logoutSection
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
            .padding(.bottom, RafiqSpacing.xl)
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("حسابي")
        .navigationBarTitleDisplayMode(.large)
        .alert("تسجيل الخروج", isPresented: $viewModel.showLogoutConfirm) {
            Button("تسجيل الخروج", role: .destructive) {
                viewModel.logout(auth: environment.auth) {
                    environment.isLoggedIn = false
                    environment.currentUser = nil
                    router.popAllToRoot()
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("هل أنت متأكد من تسجيل الخروج؟")
        }
        .sheet(isPresented: $viewModel.showEditName) {
            editNameSheet
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        AppCard(shadow: .medium) {
            VStack(spacing: RafiqSpacing.md) {
                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(RafiqColors.primaryFallback.opacity(0.4))

                    Button {
                        // TODO: photo picker
                    } label: {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(RafiqColors.primaryFallback)
                            .background(Circle().fill(RafiqColors.surfaceFallback))
                    }
                }

                // Name
                VStack(spacing: RafiqSpacing.xs) {
                    HStack(spacing: RafiqSpacing.sm) {
                        Text(user?.name ?? "مستخدم")
                            .font(RafiqFonts.heading2())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)

                        Button {
                            viewModel.startEditingName(current: user?.name ?? "")
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(RafiqColors.primaryFallback)
                        }
                    }

                    Text(user?.phone ?? "")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)

                    // Role badge
                    if let role = user?.role {
                        Text(roleDisplayName(role))
                            .font(RafiqFonts.small())
                            .foregroundStyle(RafiqColors.primaryFallback)
                            .padding(.horizontal, RafiqSpacing.sm)
                            .padding(.vertical, 3)
                            .background(RafiqColors.primaryFallback.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        AppCard {
            HStack(spacing: 0) {
                statItem(
                    value: user?.formattedRating ?? "0.0",
                    label: "التقييم",
                    icon: "star.fill",
                    color: RafiqColors.warningFallback
                )

                Divider().frame(height: 40)

                statItem(
                    value: "\(user?.totalRatings ?? 0)",
                    label: "تقييمات",
                    icon: "person.3.fill",
                    color: RafiqColors.primaryFallback
                )
            }
        }
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: RafiqSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
            }
            Text(label)
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        menuSection(title: "الحساب") {
            menuRow(icon: "star.fill", title: "تقييماتي", color: RafiqColors.warningFallback) {
                if let uid = user?.uid {
                    router.navigate(to: .reviews(userId: uid), in: .profile)
                }
            }
        }
    }

    // MARK: - Driver Section

    @ViewBuilder
    private var driverSection: some View {
        if user?.isDriver == true {
            menuSection(title: "السائق") {
                menuRow(icon: "rectangle.grid.1x2.fill", title: "لوحة السائق", color: RafiqColors.primaryFallback) {
                    router.navigate(to: .driverDashboard, in: .profile)
                }
                menuRow(icon: "car.fill", title: "مركباتي", color: RafiqColors.accentFallback) {
                    router.navigate(to: .vehicles, in: .profile)
                }
                menuRow(icon: "map.fill", title: "رحلاتي كسائق", color: RafiqColors.primaryFallback) {
                    router.navigate(to: .myTrips, in: .profile)
                }
            }
        }
    }

    // MARK: - Support Section (WhatsApp)

    private var supportSection: some View {
        menuSection(title: "الدعم والمساعدة") {
            // Saudi WhatsApp
            whatsappRow(
                flag: "🇸🇦",
                title: "دعم السعودية",
                subtitle: "واتساب",
                url: DeepLinks.saudiSupportURL()
            )

            // Yemen WhatsApp
            whatsappRow(
                flag: "🇾🇪",
                title: "دعم اليمن",
                subtitle: "واتساب",
                url: DeepLinks.yemenSupportURL()
            )
        }
    }

    private func whatsappRow(flag: String, title: String, subtitle: String, url: URL?) -> some View {
        Button {
            if let url { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: RafiqSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: RafiqRadius.sm)
                        .fill(Color(hex: "#25D366").opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(flag)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(RafiqFonts.body())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Text(subtitle)
                        .font(RafiqFonts.small())
                        .foregroundStyle(Color(hex: "#25D366"))
                }

                Spacer()

                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 14))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm + 2)
            .background(RafiqColors.surfaceFallback)
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        menuSection(title: "القانونية") {
            menuRow(icon: "doc.text.fill", title: "شروط الاستخدام", color: RafiqColors.textSecondaryFallback) {
                router.navigate(to: .support, in: .profile) // TODO: dedicated legal route
            }
            menuRow(icon: "lock.shield.fill", title: "سياسة الخصوصية", color: RafiqColors.textSecondaryFallback) {
                router.navigate(to: .support, in: .profile)
            }
        }
    }

    // MARK: - Logout Section

    private var logoutSection: some View {
        Button {
            viewModel.showLogoutConfirm = true
        } label: {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                    .foregroundStyle(RafiqColors.errorFallback)
                    .frame(width: 28)

                Text("تسجيل الخروج")
                    .font(RafiqFonts.body())
                    .foregroundStyle(RafiqColors.errorFallback)

                Spacer()
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.md)
            .background(RafiqColors.surfaceFallback)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
        }
    }

    // MARK: - Edit Name Sheet

    private var editNameSheet: some View {
        NavigationStack {
            VStack(spacing: RafiqSpacing.lg) {
                Text("تعديل الاسم")
                    .font(RafiqFonts.heading2())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                TextField("الاسم الكامل", text: $viewModel.editedName)
                    .font(RafiqFonts.heading3())
                    .padding(RafiqSpacing.md)
                    .background(RafiqColors.backgroundFallback)
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) { viewModel.errorMessage = nil }
                }

                PrimaryButton(
                    title: "حفظ",
                    icon: "checkmark.circle.fill",
                    isLoading: viewModel.isSavingName
                ) {
                    viewModel.saveName(auth: environment.auth) { updated in
                        environment.currentUser = updated
                    }
                }

                Spacer()
            }
            .padding(RafiqSpacing.md)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { viewModel.showEditName = false }
                }
            }
        }
    }

    // MARK: - Menu Helpers

    private func menuSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .padding(.horizontal, RafiqSpacing.xs)
                .padding(.bottom, RafiqSpacing.xs)

            VStack(spacing: 1) {
                content()
            }
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
        }
    }

    private func menuRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 28)

                Text(title)
                    .font(RafiqFonts.body())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.md)
            .background(RafiqColors.surfaceFallback)
        }
    }

    private func roleDisplayName(_ role: UserRole) -> String {
        switch role {
        case .passenger: return "راكب"
        case .driver: return "سائق"
        case .both: return "راكب وسائق"
        default: return ""
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Profile") {
    NavigationStack {
        ProfileFullView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
