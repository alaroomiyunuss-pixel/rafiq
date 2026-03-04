// PATH: ios-app/Rafiq/Features/Bookings/
// FILENAME: BookingConfirmationView.swift

import SwiftUI

// ============================================================
// MARK: - BookingConfirmationViewModel
// ============================================================

@MainActor
final class BookingConfirmationViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var seatCount = 1
    @Published var pickupPoint: MeetingPoint?
    @Published var selectedPayment: PaymentMethod = .card
    @Published var isCreatingBooking = false
    @Published var isLoadingPayment = false
    @Published var errorMessage: String?
    @Published var bookingCreated = false
    @Published var createdBookingId: String?
    @Published var showPickupMap = false

    enum PaymentMethod: String, CaseIterable {
        case card = "بطاقة بنكية"
        case applePay = "Apple Pay"

        var icon: String {
            switch self {
            case .card: return "creditcard.fill"
            case .applePay: return "apple.logo"
            }
        }
    }

    var totalHalalas: Int {
        (trip?.pricePerSeatHalalas ?? 0) * seatCount
    }

    var totalSAR: String {
        let sar = Double(totalHalalas) / 100.0
        return String(format: "%.0f ر.س", sar)
    }

    var maxSeats: Int {
        trip?.availableSeats ?? 1
    }

    var needsPickupPoint: Bool {
        trip?.meetingMode == .driverPicksUp
    }

    var canProceed: Bool {
        guard trip != nil else { return false }
        if needsPickupPoint && pickupPoint == nil { return false }
        return true
    }

    func loadTrip(tripId: String, service: TripsServiceProtocol) {
        Task {
            do {
                trip = try await service.getTrip(id: tripId)
            } catch {
                errorMessage = "فشل في تحميل تفاصيل الرحلة"
            }
        }
    }

    func createBookingAndPay(
        bookingService: BookingServiceProtocol,
        onSuccess: @escaping (String) -> Void
    ) {
        guard let trip, canProceed else { return }

        isCreatingBooking = true
        errorMessage = nil

        Task {
            do {
                // Step 1: Create booking
                let bookingId = try await bookingService.createBooking(
                    tripId: trip.tripId,
                    seatCount: seatCount,
                    pickupPoint: pickupPoint
                )
                createdBookingId = bookingId

                // Step 2: Create payment intent
                isLoadingPayment = true
                let paymentResult = try await bookingService.createPaymentIntent(bookingId: bookingId)

                // Step 3: Present Stripe PaymentSheet
                // In real implementation, use StripePaymentSheet here
                // For now, simulate success
                bookingCreated = true
                onSuccess(bookingId)

            } catch {
                errorMessage = "فشل في إنشاء الحجز. حاول مرة أخرى"
            }
            isCreatingBooking = false
            isLoadingPayment = false
        }
    }
}

// ============================================================
// MARK: - BookingConfirmationView
// ============================================================

struct BookingConfirmationView: View {
    let tripId: String

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = BookingConfirmationViewModel()

    var body: some View {
        Group {
            if viewModel.bookingCreated {
                successView
            } else if let trip = viewModel.trip {
                bookingForm(trip)
            } else {
                LoadingView(message: "جاري تحميل تفاصيل الرحلة...")
            }
        }
        .navigationTitle("تأكيد الحجز")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadTrip(tripId: tripId, service: environment.trips)
        }
        .sheet(isPresented: $viewModel.showPickupMap) {
            PinPickerView(
                title: "حدد موقع الالتقاء",
                initialLocation: viewModel.pickupPoint
            ) { point in
                viewModel.pickupPoint = point
            }
        }
    }

    // MARK: - Booking Form

    @ViewBuilder
    private func bookingForm(_ trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.md) {
                // Trip summary
                tripSummaryCard(trip)

                // Seat selector
                seatSelector(trip)

                // Pickup point (if DRIVER_PICKS_UP)
                if viewModel.needsPickupPoint {
                    pickupPointCard
                }

                // Payment method
                paymentMethodCard

                // 3-hour warning
                expiryWarning

                // Cancel policy
                cancelPolicyCard

                // Price breakdown
                priceBreakdown(trip)

                // Error
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
        }
        .background(RafiqColors.backgroundFallback)
        .overlay(alignment: .bottom) {
            confirmButton
        }
    }

    // MARK: - Trip Summary

    private func tripSummaryCard(_ trip: Trip) -> some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                    Text(trip.routeText)
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Text(trip.tripDate.arabicShortDate + " · " + trip.tripDate.arabicTime)
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                    HStack(spacing: RafiqSpacing.xs) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 14))
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
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(RafiqColors.primaryFallback.opacity(0.3))
            }
        }
    }

    // MARK: - Seat Selector

    private func seatSelector(_ trip: Trip) -> some View {
        AppCardWithHeader(
            title: "عدد المقاعد",
            subtitle: "\(trip.availableSeats) مقعد متاح",
            icon: "person.3.fill",
            iconColor: RafiqColors.successFallback
        ) {
            HStack(spacing: RafiqSpacing.md) {
                // Decrement
                Button {
                    if viewModel.seatCount > 1 {
                        viewModel.seatCount -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.seatCount > 1
                                ? RafiqColors.primaryFallback
                                : RafiqColors.textSecondaryFallback.opacity(0.3)
                        )
                }
                .disabled(viewModel.seatCount <= 1)

                // Count
                Text("\(viewModel.seatCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
                    .frame(width: 60)

                // Increment
                Button {
                    if viewModel.seatCount < viewModel.maxSeats {
                        viewModel.seatCount += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.seatCount < viewModel.maxSeats
                                ? RafiqColors.primaryFallback
                                : RafiqColors.textSecondaryFallback.opacity(0.3)
                        )
                }
                .disabled(viewModel.seatCount >= viewModel.maxSeats)

                Spacer()

                // Per seat price
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trip.formattedPrice)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.primaryFallback)
                    Text("للمقعد")
                        .font(RafiqFonts.small())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
        }
    }

    // MARK: - Pickup Point (DRIVER_PICKS_UP)

    private var pickupPointCard: some View {
        AppCardWithHeader(
            title: "موقع الالتقاء",
            subtitle: "السائق سيأتي إليك",
            icon: "car.side.fill",
            iconColor: RafiqColors.accentFallback
        ) {
            if let point = viewModel.pickupPoint {
                VStack(spacing: RafiqSpacing.sm) {
                    MapPreviewView(point: point, height: 120)

                    if let address = point.address, !address.isEmpty {
                        Text(address)
                            .font(RafiqFonts.caption())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }

                    Button {
                        viewModel.showPickupMap = true
                    } label: {
                        HStack(spacing: RafiqSpacing.xs) {
                            Image(systemName: "pencil")
                            Text("تعديل الموقع")
                        }
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.primaryFallback)
                    }
                }
            } else {
                PrimaryButton(
                    title: "حدد موقعك على الخريطة",
                    icon: "mappin.circle.fill",
                    style: .outline
                ) {
                    viewModel.showPickupMap = true
                }
            }
        }
    }

    // MARK: - Payment Method

    private var paymentMethodCard: some View {
        AppCardWithHeader(
            title: "طريقة الدفع",
            subtitle: "إلكتروني فقط",
            icon: "creditcard.fill",
            iconColor: RafiqColors.primaryFallback
        ) {
            VStack(spacing: RafiqSpacing.sm) {
                ForEach(BookingConfirmationViewModel.PaymentMethod.allCases, id: \.self) { method in
                    paymentMethodRow(method)
                }
            }
        }
    }

    private func paymentMethodRow(_ method: BookingConfirmationViewModel.PaymentMethod) -> some View {
        let isSelected = viewModel.selectedPayment == method

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedPayment = method
            }
        } label: {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: method.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? RafiqColors.primaryFallback : RafiqColors.textSecondaryFallback)
                    .frame(width: 28)

                Text(method.rawValue)
                    .font(RafiqFonts.body())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isSelected ? RafiqColors.primaryFallback : RafiqColors.textSecondaryFallback.opacity(0.3)
                    )
            }
            .padding(RafiqSpacing.sm + 2)
            .background(
                isSelected
                    ? RafiqColors.primaryFallback.opacity(0.06)
                    : RafiqColors.backgroundFallback
            )
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: RafiqRadius.sm)
                        .stroke(RafiqColors.primaryFallback.opacity(0.3), lineWidth: 1)
                }
            }
        }
    }

    // MARK: - 3-Hour Expiry Warning

    private var expiryWarning: some View {
        HStack(alignment: .top, spacing: RafiqSpacing.sm) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 20))
                .foregroundStyle(RafiqColors.warningFallback)

            VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                Text("مهلة الدفع: 3 ساعات")
                    .font(RafiqFonts.bodyBold())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                Text("بعد تأكيد الحجز، لديك 3 ساعات لإتمام الدفع. إذا لم يتم الدفع خلال هذه المدة، سيتم إلغاء الحجز تلقائياً وإعادة المقاعد للرحلة.")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }
        }
        .padding(RafiqSpacing.md)
        .background(RafiqColors.warningFallback.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
    }

    // MARK: - Cancel Policy

    private var cancelPolicyCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                HStack(spacing: RafiqSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(RafiqColors.primaryFallback)
                    Text("سياسة الإلغاء")
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                }

                policyRow(icon: "checkmark.circle", text: "إلغاء قبل 24 ساعة = استرداد كامل", color: RafiqColors.successFallback)
                policyRow(icon: "xmark.circle", text: "إلغاء خلال 24 ساعة = بدون استرداد", color: RafiqColors.errorFallback)
                policyRow(icon: "xmark.circle", text: "عدم الحضور = بدون استرداد", color: RafiqColors.errorFallback)
            }
        }
    }

    private func policyRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
    }

    // MARK: - Price Breakdown

    private func priceBreakdown(_ trip: Trip) -> some View {
        AppCard(shadow: .medium) {
            VStack(spacing: RafiqSpacing.sm) {
                priceRow("سعر المقعد", trip.formattedPrice)
                priceRow("عدد المقاعد", "× \(viewModel.seatCount)")

                Divider()

                HStack {
                    Text("الإجمالي")
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Spacer()
                    Text(viewModel.totalSAR)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(RafiqColors.primaryFallback)
                }
            }
        }
    }

    private func priceRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
            Spacer()
            Text(value)
                .font(RafiqFonts.bodyBold())
                .foregroundStyle(RafiqColors.textPrimaryFallback)
        }
    }

    // MARK: - Confirm Button (sticky bottom)

    private var confirmButton: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: RafiqSpacing.xs) {
                PrimaryButton(
                    title: "تأكيد ودفع \(viewModel.totalSAR)",
                    icon: viewModel.selectedPayment == .applePay ? "apple.logo" : "lock.fill",
                    isLoading: viewModel.isCreatingBooking || viewModel.isLoadingPayment,
                    isDisabled: !viewModel.canProceed
                ) {
                    viewModel.createBookingAndPay(
                        bookingService: environment.bookings
                    ) { bookingId in
                        router.navigate(to: .bookingDetail(bookingId: bookingId), in: .bookings)
                    }
                }

                Text("الدفع آمن ومشفر عبر Stripe")
                    .font(RafiqFonts.small())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }
            .padding(RafiqSpacing.md)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: RafiqSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(RafiqColors.successFallback)

            Text("تم الحجز بنجاح! 🎉")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("تم تأكيد حجزك ودفعك. يمكنك التواصل مع السائق عبر المحادثة.")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            VStack(spacing: RafiqSpacing.md) {
                PrimaryButton(title: "عرض الحجز", icon: "ticket.fill") {
                    if let id = viewModel.createdBookingId {
                        router.showBookingDetail(id)
                    }
                }

                PrimaryButton(title: "العودة للرئيسية", style: .outline) {
                    router.popToRoot(tab: .home)
                    router.selectedTab = .home
                }
            }
            .padding(.horizontal, RafiqSpacing.lg)

            Spacer()
        }
        .background(RafiqColors.backgroundFallback)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Booking Confirmation") {
    NavigationStack {
        BookingConfirmationView(tripId: "mock_trip_001")
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
