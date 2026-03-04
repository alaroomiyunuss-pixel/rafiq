// PATH: ios-app/Rafiq/Features/Bookings/
// FILENAME: MyTripsView.swift

import SwiftUI

// ============================================================
// MARK: - MyTripsViewModel
// ============================================================

@MainActor
final class MyTripsViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: BookingFilter = .upcoming

    enum BookingFilter: String, CaseIterable {
        case upcoming = "قادمة"
        case completed = "منجزة"
        case cancelled = "ملغاة"

        var statuses: [BookingStatus] {
            switch self {
            case .upcoming: return [.pendingPayment, .confirmed]
            case .completed: return [.completed]
            case .cancelled: return [.cancelled, .expired]
            }
        }

        var icon: String {
            switch self {
            case .upcoming: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            }
        }
    }

    var filteredBookings: [Booking] {
        let statuses = selectedFilter.statuses
        return bookings
            .filter { statuses.contains($0.status) }
            .sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
    }

    var filterCounts: [BookingFilter: Int] {
        var counts: [BookingFilter: Int] = [:]
        for filter in BookingFilter.allCases {
            let statuses = filter.statuses
            counts[filter] = bookings.filter { statuses.contains($0.status) }.count
        }
        return counts
    }

    func load(userId: String, role: UserRole, service: BookingServiceProtocol) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                var results: [Booking] = []
                // Load as passenger
                if role == .passenger || role == .both {
                    let passengerBookings = try await service.getPassengerBookings(passengerId: userId)
                    results.append(contentsOf: passengerBookings)
                }
                // Load as driver
                if role == .driver || role == .both {
                    let driverBookings = try await service.getDriverBookings(driverId: userId)
                    // Avoid duplicates
                    let existingIds = Set(results.compactMap(\.id))
                    let unique = driverBookings.filter { !existingIds.contains($0.id ?? "") }
                    results.append(contentsOf: unique)
                }
                bookings = results
            } catch {
                errorMessage = "فشل في تحميل الحجوزات"
            }
            isLoading = false
        }
    }
}

// ============================================================
// MARK: - MyTripsView
// ============================================================

struct MyTripsFullView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = MyTripsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Filter segments
            filterBar

            // Content
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "جاري تحميل رحلاتك...")
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(title: "خطأ", message: error) {
                        reload()
                    }
                } else if viewModel.filteredBookings.isEmpty {
                    emptyState
                } else {
                    bookingsList
                }
            }
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("رحلاتي")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { reload() }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RafiqSpacing.sm) {
                ForEach(MyTripsViewModel.BookingFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
        }
        .background(RafiqColors.surfaceFallback)
    }

    private func filterChip(_ filter: MyTripsViewModel.BookingFilter) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        let count = viewModel.filterCounts[filter] ?? 0

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12))

                Text(filter.rawValue)
                    .font(RafiqFonts.caption())

                if count > 0 {
                    Text("\(count)")
                        .font(RafiqFonts.small())
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? RafiqColors.primaryFallback : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected
                                ? .white
                                : RafiqColors.textSecondaryFallback.opacity(0.4)
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : RafiqColors.textPrimaryFallback)
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
            .background(isSelected ? RafiqColors.primaryFallback : RafiqColors.backgroundFallback)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(RafiqColors.textSecondaryFallback.opacity(0.15), lineWidth: 1)
                }
            }
        }
    }

    // MARK: - Bookings List

    private var bookingsList: some View {
        ScrollView {
            LazyVStack(spacing: RafiqSpacing.md) {
                ForEach(viewModel.filteredBookings) { booking in
                    Button {
                        router.showBookingDetail(booking.bookingId)
                    } label: {
                        BookingCard(booking: booking, currentUserId: environment.currentUser?.uid ?? "")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        let (icon, title, message): (String, String, String) = {
            switch viewModel.selectedFilter {
            case .upcoming:
                return ("ticket.fill", "لا توجد رحلات قادمة", "ابحث عن رحلة واحجز مقعدك")
            case .completed:
                return ("checkmark.circle.fill", "لا توجد رحلات منجزة", "رحلاتك المكتملة ستظهر هنا")
            case .cancelled:
                return ("xmark.circle.fill", "لا توجد رحلات ملغاة", "الحجوزات الملغاة ستظهر هنا")
            }
        }()

        return EmptyStateView(icon: icon, title: title, message: message)
    }

    // MARK: - Helpers

    private func reload() {
        guard let user = environment.currentUser else { return }
        viewModel.load(userId: user.uid, role: user.role, service: environment.bookings)
    }
}

// ============================================================
// MARK: - Booking Card
// ============================================================

struct BookingCard: View {
    let booking: Booking
    let currentUserId: String

    var isDriver: Bool { booking.driverId == currentUserId }
    var roleLabel: String { isDriver ? "سائق" : "راكب" }

    var body: some View {
        AppCard(shadow: .medium) {
            VStack(spacing: RafiqSpacing.md) {
                // Top: status + role badge + date
                HStack {
                    statusBadge
                    roleBadge
                    Spacer()
                    if let date = booking.createdAt?.dateValue() {
                        Text(date.arabicShortDate)
                            .font(RafiqFonts.small())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }
                }

                // Trip info
                HStack {
                    VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                        Text(isDriver ? booking.passengerName : "حجز #\(booking.bookingId.prefix(6))")
                            .font(RafiqFonts.bodyBold())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)

                        HStack(spacing: RafiqSpacing.sm) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 11))
                                Text("\(booking.seatCount) مقعد")
                                    .font(RafiqFonts.caption())
                            }
                            .foregroundStyle(RafiqColors.textSecondaryFallback)

                            Text("·")
                                .foregroundStyle(RafiqColors.textSecondaryFallback)

                            Text(booking.formattedTotal)
                                .font(RafiqFonts.bodyBold())
                                .foregroundStyle(RafiqColors.primaryFallback)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
                }

                // Expiry warning for pending
                if booking.status == .pendingPayment, let expiry = booking.expiryDate {
                    expiryBar(expiry)
                }

                // Rating prompt for completed
                if booking.status == .completed && booking.canRate {
                    ratingPrompt
                }
            }
        }
    }

    private var statusBadge: some View {
        let (text, color) = statusDisplay(booking.status)
        return Text(text)
            .font(RafiqFonts.small())
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var roleBadge: some View {
        Text(roleLabel)
            .font(RafiqFonts.small())
            .foregroundStyle(RafiqColors.textSecondaryFallback)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RafiqColors.backgroundFallback)
            .clipShape(Capsule())
    }

    private func expiryBar(_ expiry: Date) -> some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 14))
                .foregroundStyle(RafiqColors.warningFallback)
            Text("أكمل الدفع قبل: \(expiry.arabicTime)")
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.warningFallback)
            Spacer()
        }
        .padding(RafiqSpacing.sm)
        .background(RafiqColors.warningFallback.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
    }

    private var ratingPrompt: some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundStyle(RafiqColors.warningFallback)
            Text("قيّم تجربتك")
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.primaryFallback)
            Spacer()
            Image(systemName: "chevron.left")
                .font(.system(size: 10))
                .foregroundStyle(RafiqColors.primaryFallback)
        }
        .padding(RafiqSpacing.sm)
        .background(RafiqColors.warningFallback.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
    }

    private func statusDisplay(_ status: BookingStatus) -> (String, Color) {
        switch status {
        case .pendingPayment: return ("بانتظار الدفع", RafiqColors.warningFallback)
        case .confirmed: return ("مؤكد", RafiqColors.successFallback)
        case .completed: return ("مكتمل", RafiqColors.primaryFallback)
        case .cancelled: return ("ملغى", RafiqColors.errorFallback)
        case .expired: return ("منتهي", RafiqColors.textSecondaryFallback)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("My Trips") {
    NavigationStack {
        MyTripsFullView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Booking Card") {
    VStack(spacing: RafiqSpacing.md) {
        BookingCard(booking: .mock, currentUserId: "mock_user_001")

        BookingCard(
            booking: Booking(
                id: "b_002", tripId: "t_001",
                passengerId: "mock_user_001", passengerName: "يونس",
                driverId: "d_001", seatCount: 2,
                totalAmountHalalas: 30000, platformFeeHalalas: 3000,
                paymentIntentId: nil, paymentStatus: .unpaid,
                status: .pendingPayment, cancelledBy: nil, cancelReason: nil,
                pickupPoint: nil,
                createdAt: .init(date: Date()),
                expiresAt: .init(date: Date().addingTimeInterval(7200)),
                confirmedAt: nil, completedAt: nil, cancelledAt: nil, refundedAt: nil,
                ratingWindowStatus: nil, ratingWindowClosesAt: nil,
                passengerRated: nil, driverRated: nil,
                promoCodeId: nil, refundId: nil
            ),
            currentUserId: "mock_user_001"
        )
    }
    .padding()
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}
