// PATH: ios-app/Rafiq/Features/Bookings/
// FILENAME: BookingDetailView.swift

import SwiftUI

// ============================================================
// MARK: - BookingDetailViewModel
// ============================================================

@MainActor
final class BookingDetailViewModel: ObservableObject {
    @Published var booking: Booking?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isCancelling = false
    @Published var showCancelConfirm = false
    @Published var cancelResult: CancelResult?

    private var listener: Any?

    func load(bookingId: String, service: BookingServiceProtocol) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                booking = try await service.getBooking(id: bookingId)
            } catch {
                errorMessage = "فشل في تحميل تفاصيل الحجز"
            }
            isLoading = false
        }
    }

    func listen(bookingId: String, service: BookingServiceProtocol) {
        listener = service.listenToBooking(id: bookingId) { [weak self] updated in
            Task { @MainActor in
                self?.booking = updated
            }
        }
    }

    var canCancel: Bool {
        guard let booking else { return false }
        return booking.isCancellable
    }

    var isRefundEligible: Bool {
        // Would need trip dateTime — simplified check
        // In production, server validates
        true
    }

    func cancelBooking(service: BookingServiceProtocol) {
        guard let booking else { return }
        isCancelling = true
        errorMessage = nil

        Task {
            do {
                let result = try await service.cancelBooking(id: booking.bookingId, reason: "إلغاء من قبل الراكب")
                cancelResult = result
                // Refresh booking
                self.booking?.status = .cancelled
            } catch {
                errorMessage = "فشل في إلغاء الحجز. حاول مرة أخرى"
            }
            isCancelling = false
        }
    }

    var timelineSteps: [TimelineStep] {
        guard let booking else { return [] }
        var steps: [TimelineStep] = []

        // Created
        steps.append(TimelineStep(
            title: "تم إنشاء الحجز",
            subtitle: booking.createdAt?.dateValue().arabicTime,
            icon: "plus.circle.fill",
            color: RafiqColors.primaryFallback,
            isCompleted: true
        ))

        // Payment
        switch booking.paymentStatus {
        case .paid:
            steps.append(TimelineStep(
                title: "تم الدفع",
                subtitle: booking.confirmedAt?.dateValue().arabicTime,
                icon: "creditcard.fill",
                color: RafiqColors.successFallback,
                isCompleted: true
            ))
        case .failed:
            steps.append(TimelineStep(
                title: "فشل الدفع",
                subtitle: nil,
                icon: "xmark.circle.fill",
                color: RafiqColors.errorFallback,
                isCompleted: true
            ))
        case .expired:
            steps.append(TimelineStep(
                title: "انتهت مهلة الدفع",
                subtitle: nil,
                icon: "clock.fill",
                color: RafiqColors.textSecondaryFallback,
                isCompleted: true
            ))
        case .refunded:
            steps.append(TimelineStep(
                title: "تم الدفع",
                subtitle: booking.confirmedAt?.dateValue().arabicTime,
                icon: "creditcard.fill",
                color: RafiqColors.successFallback,
                isCompleted: true
            ))
            steps.append(TimelineStep(
                title: "تم الاسترداد",
                subtitle: booking.refundedAt?.dateValue().arabicTime,
                icon: "arrow.uturn.backward.circle.fill",
                color: RafiqColors.warningFallback,
                isCompleted: true
            ))
        default:
            steps.append(TimelineStep(
                title: "بانتظار الدفع",
                subtitle: "خلال 3 ساعات",
                icon: "hourglass",
                color: RafiqColors.warningFallback,
                isCompleted: false
            ))
        }

        // Confirmed
        if booking.status == .confirmed || booking.status == .completed {
            steps.append(TimelineStep(
                title: "تم التأكيد",
                subtitle: booking.confirmedAt?.dateValue().arabicTime,
                icon: "checkmark.seal.fill",
                color: RafiqColors.successFallback,
                isCompleted: true
            ))
        }

        // Completed
        if booking.status == .completed {
            steps.append(TimelineStep(
                title: "اكتملت الرحلة",
                subtitle: booking.completedAt?.dateValue().arabicTime,
                icon: "flag.checkered",
                color: RafiqColors.primaryFallback,
                isCompleted: true
            ))
        }

        // Cancelled
        if booking.status == .cancelled {
            steps.append(TimelineStep(
                title: "تم الإلغاء",
                subtitle: booking.cancelledAt?.dateValue().arabicTime ?? "",
                icon: "xmark.circle.fill",
                color: RafiqColors.errorFallback,
                isCompleted: true
            ))
        }

        return steps
    }
}

struct TimelineStep: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let isCompleted: Bool
}

// ============================================================
// MARK: - BookingDetailView
// ============================================================

struct BookingDetailFullView: View {
    let bookingId: String

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = BookingDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "جاري تحميل تفاصيل الحجز...")
            } else if let error = viewModel.errorMessage {
                ErrorStateView(title: "خطأ", message: error) {
                    viewModel.load(bookingId: bookingId, service: environment.bookings)
                }
            } else if let booking = viewModel.booking {
                bookingContent(booking)
            }
        }
        .navigationTitle("تفاصيل الحجز")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load(bookingId: bookingId, service: environment.bookings)
        }
        .alert("إلغاء الحجز", isPresented: $viewModel.showCancelConfirm) {
            Button("نعم، إلغاء", role: .destructive) {
                viewModel.cancelBooking(service: environment.bookings)
            }
            Button("لا، تراجع", role: .cancel) {}
        } message: {
            Text("هل أنت متأكد من إلغاء هذا الحجز؟ سيتم استرداد المبلغ حسب سياسة الإلغاء.")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func bookingContent(_ booking: Booking) -> some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.md) {
                // Status header
                statusHeader(booking)

                // Timeline
                timelineCard

                // Payment details
                paymentCard(booking)

                // Booking info
                bookingInfoCard(booking)

                // Pickup point
                if let pickup = booking.pickupPoint {
                    pickupCard(pickup)
                }

                // Expiry warning
                if booking.status == .pendingPayment {
                    expiryCard(booking)
                }

                // Cancel result
                if let result = viewModel.cancelResult {
                    cancelResultCard(result)
                }

                // Actions
                actionsCard(booking)

                Spacer().frame(height: RafiqSpacing.lg)
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
        }
        .background(RafiqColors.backgroundFallback)
        .loadingOverlay(viewModel.isCancelling, message: "جاري إلغاء الحجز...")
    }

    // MARK: - Status Header

    private func statusHeader(_ booking: Booking) -> some View {
        let (text, color, icon) = statusDisplayFull(booking.status)

        return AppCard(shadow: .medium) {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                    Text(text)
                        .font(RafiqFonts.heading2())
                        .foregroundStyle(color)

                    Text("حجز #\(booking.bookingId.prefix(8))")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }

                Spacer()
            }
        }
    }

    // MARK: - Timeline

    private var timelineCard: some View {
        AppCardWithHeader(
            title: "مسار الحجز",
            icon: "timeline.selection",
            iconColor: RafiqColors.primaryFallback
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.timelineSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: RafiqSpacing.md) {
                        // Icon + line
                        VStack(spacing: 0) {
                            Image(systemName: step.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(step.isCompleted ? step.color : step.color.opacity(0.4))

                            if index < viewModel.timelineSteps.count - 1 {
                                Rectangle()
                                    .fill(step.isCompleted ? step.color.opacity(0.3) : RafiqColors.textSecondaryFallback.opacity(0.15))
                                    .frame(width: 2, height: 28)
                            }
                        }
                        .frame(width: 24)

                        // Text
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(RafiqFonts.bodyBold())
                                .foregroundStyle(
                                    step.isCompleted
                                        ? RafiqColors.textPrimaryFallback
                                        : RafiqColors.textSecondaryFallback
                                )
                            if let subtitle = step.subtitle {
                                Text(subtitle)
                                    .font(RafiqFonts.small())
                                    .foregroundStyle(RafiqColors.textSecondaryFallback)
                            }
                        }
                        .padding(.bottom, index < viewModel.timelineSteps.count - 1 ? RafiqSpacing.sm : 0)

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Payment Card

    private func paymentCard(_ booking: Booking) -> some View {
        AppCard {
            VStack(spacing: RafiqSpacing.sm) {
                HStack {
                    Text("تفاصيل الدفع")
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Spacer()
                    paymentStatusBadge(booking.paymentStatus)
                }

                Divider()

                paymentRow("عدد المقاعد", "\(booking.seatCount)")
                paymentRow("المبلغ الإجمالي", booking.formattedTotal)
                paymentRow("رسوم الخدمة", booking.platformFeeHalalas.asSAR)

                if booking.paymentStatus == .refunded {
                    Divider()
                    HStack {
                        Text("المبلغ المسترد")
                            .font(RafiqFonts.bodyBold())
                            .foregroundStyle(RafiqColors.successFallback)
                        Spacer()
                        Text(booking.formattedTotal)
                            .font(RafiqFonts.bodyBold())
                            .foregroundStyle(RafiqColors.successFallback)
                    }
                }
            }
        }
    }

    private func paymentRow(_ label: String, _ value: String) -> some View {
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

    private func paymentStatusBadge(_ status: PaymentStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .unpaid: return ("غير مدفوع", RafiqColors.warningFallback)
            case .paid: return ("مدفوع", RafiqColors.successFallback)
            case .failed: return ("فشل", RafiqColors.errorFallback)
            case .expired: return ("منتهي", RafiqColors.textSecondaryFallback)
            case .refunded: return ("مسترد", RafiqColors.successFallback)
            case .partialRefund: return ("مسترد جزئياً", RafiqColors.warningFallback)
            }
        }()

        return Text(text)
            .font(RafiqFonts.small())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Booking Info

    private func bookingInfoCard(_ booking: Booking) -> some View {
        AppCard {
            VStack(spacing: RafiqSpacing.sm) {
                infoRow(icon: "person.fill", label: "الراكب", value: booking.passengerName)

                if let created = booking.createdAt?.dateValue() {
                    infoRow(icon: "calendar", label: "تاريخ الحجز", value: created.arabicFullDate)
                }

                if booking.status == .cancelled {
                    if let by = booking.cancelledBy {
                        let cancelledByText = by == "passenger" ? "الراكب" : by == "driver" ? "السائق" : "النظام"
                        infoRow(icon: "xmark.circle", label: "ألغي بواسطة", value: cancelledByText)
                    }
                    if let reason = booking.cancelReason, !reason.isEmpty {
                        infoRow(icon: "text.bubble", label: "سبب الإلغاء", value: reason)
                    }
                }
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(RafiqColors.primaryFallback)
                .frame(width: 20)
            Text(label)
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
            Spacer()
            Text(value)
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textPrimaryFallback)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Pickup Card

    private func pickupCard(_ point: MeetingPoint) -> some View {
        AppCardWithHeader(
            title: "نقطة الالتقاء",
            icon: "mappin.circle.fill",
            iconColor: RafiqColors.accentFallback
        ) {
            VStack(spacing: RafiqSpacing.sm) {
                MapPreviewView(point: point, height: 140)

                if let address = point.address, !address.isEmpty {
                    Text(address)
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Expiry Card

    private func expiryCard(_ booking: Booking) -> some View {
        HStack(spacing: RafiqSpacing.md) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 24))
                .foregroundStyle(RafiqColors.warningFallback)

            VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                Text("أكمل الدفع")
                    .font(RafiqFonts.bodyBold())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                if let expiry = booking.expiryDate {
                    Text("قبل \(expiry.arabicTime) · \(expiry.arabicRelative)")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.warningFallback)
                }
            }

            Spacer()

            PrimaryButton(title: "ادفع الآن", icon: "creditcard.fill") {
                router.showPayment(booking.bookingId)
            }
            .frame(width: 130)
        }
        .padding(RafiqSpacing.md)
        .background(RafiqColors.warningFallback.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
    }

    // MARK: - Cancel Result

    private func cancelResultCard(_ result: CancelResult) -> some View {
        AppCard {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: result.refunded ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(result.refunded ? RafiqColors.successFallback : RafiqColors.warningFallback)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.refunded ? "تم الاسترداد بنجاح" : "تم الإلغاء بدون استرداد")
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Text(result.refunded
                         ? "سيصل المبلغ خلال 5-10 أيام عمل"
                         : "تم الإلغاء خلال 24 ساعة من موعد الرحلة")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsCard(_ booking: Booking) -> some View {
        VStack(spacing: RafiqSpacing.sm) {
            // Chat with driver/passenger
            if booking.status == .confirmed {
                PrimaryButton(
                    title: "محادثة",
                    icon: "bubble.left.and.bubble.right.fill",
                    style: .outline
                ) {
                    // Navigate to chat — would need conversationId lookup
                    router.selectedTab = .chat
                }
            }

            // Rate
            if booking.status == .completed && booking.canRate {
                PrimaryButton(title: "قيّم التجربة", icon: "star.fill") {
                    router.showRating(booking.bookingId)
                }
            }

            // Pay now
            if booking.status == .pendingPayment {
                PrimaryButton(title: "ادفع الآن", icon: "creditcard.fill") {
                    router.showPayment(booking.bookingId)
                }
            }

            // Cancel
            if viewModel.canCancel {
                PrimaryButton(
                    title: "إلغاء الحجز",
                    icon: "xmark.circle.fill",
                    style: .destructive,
                    isLoading: viewModel.isCancelling
                ) {
                    viewModel.showCancelConfirm = true
                }
            }

            // View trip
            PrimaryButton(title: "عرض الرحلة", icon: "car.fill", style: .outline) {
                router.showTripDetail(booking.tripId)
            }
        }
    }

    // MARK: - Helpers

    private func statusDisplayFull(_ status: BookingStatus) -> (String, Color, String) {
        switch status {
        case .pendingPayment: return ("بانتظار الدفع", RafiqColors.warningFallback, "hourglass.circle.fill")
        case .confirmed: return ("مؤكد", RafiqColors.successFallback, "checkmark.seal.fill")
        case .completed: return ("مكتمل", RafiqColors.primaryFallback, "flag.checkered.circle.fill")
        case .cancelled: return ("ملغى", RafiqColors.errorFallback, "xmark.circle.fill")
        case .expired: return ("منتهي", RafiqColors.textSecondaryFallback, "clock.fill")
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Booking Detail - Confirmed") {
    NavigationStack {
        BookingDetailFullView(bookingId: "mock_booking_001")
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
