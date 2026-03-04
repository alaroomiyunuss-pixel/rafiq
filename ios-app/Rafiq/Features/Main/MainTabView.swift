// PATH: ios-app/Rafiq/Features/Main/
// FILENAME: MainTabView.swift

import SwiftUI

// ============================================================
// MARK: - MainTabView (replaces placeholder in RafiqApp.swift)
// ============================================================

struct RafiqMainTabView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter

    @State private var unreadMessages = 0

    var body: some View {
        TabView(selection: $router.selectedTab) {

            // ──────────────────────────────────
            // Tab 1: الرئيسية
            // ──────────────────────────────────
            NavigationStack(path: $router.homePath) {
                HomeTabView()
                    .navigationDestinations()
            }
            .tabItem {
                Label {
                    Text("الرئيسية")
                } icon: {
                    Image(systemName: router.selectedTab == .home
                          ? "house.fill" : "house")
                }
            }
            .tag(AppRouter.Tab.home)

            // ──────────────────────────────────
            // Tab 2: رحلاتي
            // ──────────────────────────────────
            NavigationStack(path: $router.bookingsPath) {
                MyTripsTabView()
                    .navigationDestinations()
            }
            .tabItem {
                Label {
                    Text("رحلاتي")
                } icon: {
                    Image(systemName: router.selectedTab == .bookings
                          ? "ticket.fill" : "ticket")
                }
            }
            .tag(AppRouter.Tab.bookings)

            // ──────────────────────────────────
            // Tab 3: الرسائل
            // ──────────────────────────────────
            NavigationStack(path: $router.chatPath) {
                MessagesTabView()
                    .navigationDestinations()
            }
            .tabItem {
                Label {
                    Text("الرسائل")
                } icon: {
                    Image(systemName: router.selectedTab == .chat
                          ? "bubble.left.and.bubble.right.fill"
                          : "bubble.left.and.bubble.right")
                }
            }
            .badge(unreadMessages > 0 ? unreadMessages : 0)
            .tag(AppRouter.Tab.chat)

            // ──────────────────────────────────
            // Tab 4: حسابي
            // ──────────────────────────────────
            NavigationStack(path: $router.profilePath) {
                AccountTabView()
                    .navigationDestinations()
            }
            .tabItem {
                Label {
                    Text("حسابي")
                } icon: {
                    Image(systemName: router.selectedTab == .profile
                          ? "person.fill" : "person")
                }
            }
            .tag(AppRouter.Tab.profile)
        }
        .tint(RafiqColors.primaryFallback)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    // MARK: - Tab Bar Appearance

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // Active
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(RafiqColors.primaryFallback)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(RafiqColors.primaryFallback),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
        ]

        // Inactive
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(RafiqColors.textSecondaryFallback)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(RafiqColors.textSecondaryFallback),
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// ============================================================
// MARK: - Tab Content Views (real implementations)
// ============================================================

// MARK: Home Tab

struct HomeTabView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.lg) {
                // Welcome header
                welcomeHeader

                // Quick actions
                quickActions

                // Recent trips placeholder
                recentTripsSection
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("الرئيسية")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.navigate(to: .support, in: .profile)
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
        }
    }

    private var welcomeHeader: some View {
        AppCard {
            HStack(spacing: RafiqSpacing.md) {
                VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                    Text("أهلاً \(environment.currentUser?.name ?? "")!")
                        .font(RafiqFonts.heading2())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    Text("وين تبي تروح اليوم؟")
                        .font(RafiqFonts.body())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
                Spacer()
                Image(systemName: "car.2.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(RafiqColors.primaryFallback.opacity(0.3))
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: RafiqSpacing.md) {
            // Search trip
            quickActionButton(
                icon: "magnifyingglass",
                title: "ابحث عن رحلة",
                color: RafiqColors.primaryFallback
            ) {
                // TODO: Navigate to search
            }

            // Post trip (driver only)
            if environment.currentUser?.isDriver == true {
                quickActionButton(
                    icon: "plus.circle.fill",
                    title: "أنشئ رحلة",
                    color: RafiqColors.accentFallback
                ) {
                    router.showPostTrip()
                }
            }
        }
    }

    private func quickActionButton(
        icon: String, title: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: RafiqSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(color)

                Text(title)
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RafiqSpacing.lg)
            .background(RafiqColors.surfaceFallback)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
            .rafiqShadow(.light)
        }
    }

    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
            Text("رحلات متاحة")
                .font(RafiqFonts.heading3())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            // Placeholder cards
            ForEach(Trip.mockList) { trip in
                Button {
                    router.showTripDetail(trip.tripId)
                } label: {
                    TripMiniCard(trip: trip)
                }
            }
        }
    }
}

// MARK: Trip Mini Card (used in home)

struct TripMiniCard: View {
    let trip: Trip

    var body: some View {
        AppCard {
            VStack(spacing: RafiqSpacing.sm) {
                // Route
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.routeText)
                            .font(RafiqFonts.bodyBold())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)
                        Text(trip.tripDate.arabicShortDate + " · " + trip.tripDate.arabicTime)
                            .font(RafiqFonts.caption())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }
                    Spacer()
                    Text(trip.formattedPrice)
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.primaryFallback)
                }

                Divider()

                // Driver + Seats
                HStack {
                    HStack(spacing: RafiqSpacing.xs) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                        Text(trip.driverName)
                            .font(RafiqFonts.caption())
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(RafiqColors.warningFallback)
                            Text(String(format: "%.1f", trip.driverRating))
                                .font(RafiqFonts.small())
                        }
                    }
                    .foregroundStyle(RafiqColors.textSecondaryFallback)

                    Spacer()

                    HStack(spacing: RafiqSpacing.xs) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                        Text("\(trip.availableSeats) متاح")
                            .font(RafiqFonts.caption())
                    }
                    .foregroundStyle(
                        trip.availableSeats > 0
                            ? RafiqColors.successFallback
                            : RafiqColors.errorFallback
                    )
                }
            }
        }
    }
}

// MARK: My Trips Tab

struct MyTripsTabView: View {
    @EnvironmentObject var environment: AppEnvironment

    var body: some View {
        EmptyStateView.noBookings
            .navigationTitle("رحلاتي")
            .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: Messages Tab

struct MessagesTabView: View {
    var body: some View {
        EmptyStateView.noMessages
            .navigationTitle("الرسائل")
            .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: Account Tab

struct AccountTabView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.md) {
                // Profile header
                profileHeader

                // Menu items
                menuSection
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("حسابي")
        .navigationBarTitleDisplayMode(.large)
    }

    private var profileHeader: some View {
        AppCard {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(RafiqColors.primaryFallback.opacity(0.6))

                VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                    Text(environment.currentUser?.name ?? "مستخدم")
                        .font(RafiqFonts.heading2())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    Text(environment.currentUser?.phone ?? "")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)

                    if let rating = environment.currentUser?.avgRating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(RafiqColors.warningFallback)
                            Text(String(format: "%.1f", rating))
                                .font(RafiqFonts.caption())
                                .foregroundStyle(RafiqColors.textSecondaryFallback)
                        }
                    }
                }
                Spacer()

                Button {
                    router.navigate(to: .editProfile, in: .profile)
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(RafiqColors.primaryFallback)
                }
            }
        }
    }

    private var menuSection: some View {
        VStack(spacing: 1) {
            if environment.currentUser?.isDriver == true {
                menuRow(icon: "car.fill", title: "لوحة السائق", color: RafiqColors.primaryFallback) {
                    router.navigate(to: .driverDashboard, in: .profile)
                }
                menuRow(icon: "car.2.fill", title: "مركباتي", color: RafiqColors.accentFallback) {
                    router.navigate(to: .vehicles, in: .profile)
                }
            }

            menuRow(icon: "star.fill", title: "تقييماتي", color: RafiqColors.warningFallback) {
                if let uid = environment.currentUser?.uid {
                    router.navigate(to: .reviews(userId: uid), in: .profile)
                }
            }

            menuRow(icon: "questionmark.circle.fill", title: "الدعم والمساعدة", color: RafiqColors.textSecondaryFallback) {
                router.navigate(to: .support, in: .profile)
            }

            // Sign out
            menuRow(icon: "rectangle.portrait.and.arrow.right", title: "تسجيل الخروج", color: RafiqColors.errorFallback) {
                try? environment.auth.signOut()
                environment.isLoggedIn = false
                environment.currentUser = nil
                router.popAllToRoot()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
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
                    .foregroundStyle(
                        title == "تسجيل الخروج"
                            ? RafiqColors.errorFallback
                            : RafiqColors.textPrimaryFallback
                    )

                Spacer()

                if title != "تسجيل الخروج" {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.md)
            .background(RafiqColors.surfaceFallback)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Main Tabs") {
    RafiqMainTabView()
        .environmentObject(AppEnvironment.preview())
        .environmentObject(AppRouter())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA"))
}

#Preview("Home Tab") {
    NavigationStack {
        HomeTabView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Account Tab") {
    NavigationStack {
        AccountTabView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
