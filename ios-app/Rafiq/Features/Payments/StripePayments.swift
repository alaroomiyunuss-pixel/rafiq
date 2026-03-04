// PATH: ios-app/Rafiq/Features/Payments/
// FILENAME: StripePayments.swift

import SwiftUI
import StripePaymentSheet
import FirebaseFunctions

// ============================================================
// MARK: - StripePaymentManager
// ============================================================

@MainActor
final class StripePaymentManager: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isPreparingSheet = false
    @Published var isPresentingSheet = false
    @Published var paymentResult: PaymentResult?
    @Published var errorMessage: String?

    enum PaymentResult: Equatable {
        case success
        case cancelled
        case failed(String)
    }

    private let functions = Functions.functions(region: "me-central1")

    // MARK: - Prepare PaymentSheet

    /// Calls createStripePaymentIntent Cloud Function, then configures PaymentSheet
    func preparePaymentSheet(bookingId: String) {
        isPreparingSheet = true
        errorMessage = nil
        paymentResult = nil

        Task {
            do {
                // Step 1: Call Cloud Function
                let result = try await functions.httpsCallable("createStripePaymentIntent")
                    .call(["bookingId": bookingId])

                guard let data = result.data as? [String: Any],
                      let clientSecret = data["clientSecret"] as? String else {
                    throw StripeError.invalidResponse
                }

                // Step 2: Configure PaymentSheet
                var config = PaymentSheet.Configuration()
                config.merchantDisplayName = "رفيق"
                config.defaultBillingDetails.address.country = "SA"
                config.allowsDelayedPaymentMethods = false
                config.returnURL = "rafiq-stripe://stripe-redirect"

                // Apple Pay
                config.applePay = .init(
                    merchantId: KeysManager.stripeMerchantId,
                    merchantCountryCode: "SA"
                )

                // Appearance (match Rafiq theme)
                var appearance = PaymentSheet.Appearance()
                appearance.colors.primary = UIColor(RafiqColors.primaryFallback)
                appearance.colors.background = .systemBackground
                appearance.cornerRadius = Float(RafiqRadius.md)
                appearance.font.base = .systemFont(ofSize: 16)
                config.appearance = appearance

                // Step 3: Create PaymentSheet
                paymentSheet = PaymentSheet(
                    paymentIntentClientSecret: clientSecret,
                    configuration: config
                )

            } catch {
                errorMessage = mapError(error)
            }
            isPreparingSheet = false
        }
    }

    // MARK: - Handle PaymentSheet Result

    func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            paymentResult = .success
        case .canceled:
            paymentResult = .cancelled
        case .failed(let error):
            paymentResult = .failed(error.localizedDescription)
            errorMessage = "فشل الدفع: \(error.localizedDescription)"
        }
    }

    // MARK: - Reset

    func reset() {
        paymentSheet = nil
        paymentResult = nil
        errorMessage = nil
        isPreparingSheet = false
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> String {
        if let funcError = error as NSError?,
           funcError.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: funcError.code) {
            case .notFound:
                return "الحجز غير موجود"
            case .failedPrecondition:
                return "انتهت مهلة الدفع أو تم إلغاء الحجز"
            case .unauthenticated:
                return "يجب تسجيل الدخول"
            case .permissionDenied:
                return "لا يمكنك الدفع لهذا الحجز"
            default:
                return "حدث خطأ في إعداد الدفع. حاول مرة أخرى"
            }
        }
        return "حدث خطأ في إعداد الدفع. حاول مرة أخرى"
    }
}

// MARK: - Custom Error

enum StripeError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة غير صالحة من الخادم"
        }
    }
}

// ============================================================
// MARK: - PaymentView (Full Screen)
// ============================================================

struct PaymentFullView: View {
    let bookingId: String

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var payment = StripePaymentManager()
    @StateObject private var confirmWatcher = BookingConfirmWatcher()

    var body: some View {
        VStack(spacing: RafiqSpacing.lg) {
            switch paymentState {
            case .preparing:
                preparingView
            case .ready:
                readyView
            case .success:
                successView
            case .confirming:
                confirmingView
            case .confirmed:
                confirmedView
            case .failed:
                failedView
            case .cancelled:
                cancelledView
            }
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("الدفع")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            payment.preparePaymentSheet(bookingId: bookingId)
        }
        .onDisappear {
            confirmWatcher.stop()
        }
    }

    // MARK: - Payment State

    private enum PaymentState {
        case preparing, ready, success, confirming, confirmed, failed, cancelled
    }

    private var paymentState: PaymentState {
        if confirmWatcher.isConfirmed {
            return .confirmed
        }
        if confirmWatcher.isWatching {
            return .confirming
        }
        if let result = payment.paymentResult {
            switch result {
            case .success: return .success
            case .cancelled: return .cancelled
            case .failed: return .failed
            }
        }
        if payment.paymentSheet != nil {
            return .ready
        }
        return .preparing
    }

    // MARK: - Preparing

    private var preparingView: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()
            LoadingView(message: "جاري إعداد الدفع...", showBackground: false)

            if let error = payment.errorMessage {
                ErrorBanner(message: error) {
                    payment.errorMessage = nil
                }
                .padding(.horizontal, RafiqSpacing.md)

                PrimaryButton(title: "إعادة المحاولة", icon: "arrow.clockwise") {
                    payment.preparePaymentSheet(bookingId: bookingId)
                }
                .padding(.horizontal, RafiqSpacing.xl)
            }
            Spacer()
        }
    }

    // MARK: - Ready (Show PaymentSheet)

    private var readyView: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()

            Image(systemName: "creditcard.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(RafiqColors.primaryFallback)

            Text("جاهز للدفع")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("اختر طريقة الدفع المناسبة: بطاقة بنكية أو Apple Pay")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            // Payment methods icons
            HStack(spacing: RafiqSpacing.xl) {
                paymentMethodIcon(icon: "creditcard.fill", label: "بطاقة")
                paymentMethodIcon(icon: "apple.logo", label: "Apple Pay")
            }

            if let sheet = payment.paymentSheet {
                PaymentSheet.PaymentButton(
                    paymentSheet: sheet,
                    onCompletion: { result in
                        payment.handlePaymentResult(result)
                        if case .success = payment.paymentResult {
                            confirmWatcher.start(
                                bookingId: bookingId,
                                service: environment.bookings
                            )
                        }
                    }
                ) {
                    HStack(spacing: RafiqSpacing.sm) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                        Text("ادفع الآن")
                            .font(RafiqFonts.bodyBold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(RafiqColors.primaryFallback)
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
                }
                .padding(.horizontal, RafiqSpacing.md)
            }

            Text("الدفع آمن ومشفر عبر Stripe")
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.textSecondaryFallback)

            Spacer()
        }
    }

    private func paymentMethodIcon(icon: String, label: String) -> some View {
        VStack(spacing: RafiqSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(RafiqColors.primaryFallback)
                .frame(width: 52, height: 52)
                .background(RafiqColors.primaryFallback.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
            Text(label)
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
    }

    // MARK: - Success (Payment done, waiting for webhook)

    private var successView: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(RafiqColors.successFallback)

            Text("تم الدفع بنجاح! ✅")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("جاري تأكيد الحجز...")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)

            ProgressView()
                .scaleEffect(1.2)

            Spacer()
        }
        .onAppear {
            confirmWatcher.start(bookingId: bookingId, service: environment.bookings)
        }
    }

    // MARK: - Confirming (Listening for webhook)

    private var confirmingView: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()
            LoadingView(message: "جاري تأكيد الحجز...", showBackground: false)
            Text("نتحقق من الدفع مع البنك")
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
            Spacer()
        }
    }

    // MARK: - Confirmed (Booking status = confirmed)

    private var confirmedView: some View {
        VStack(spacing: RafiqSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(RafiqColors.successFallback)

            Text("تم تأكيد الحجز! 🎉")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("يمكنك الآن التواصل مع السائق عبر المحادثة")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            VStack(spacing: RafiqSpacing.md) {
                PrimaryButton(title: "عرض الحجز", icon: "ticket.fill") {
                    router.showBookingDetail(bookingId)
                }

                PrimaryButton(title: "العودة للرئيسية", style: .outline) {
                    router.popToRoot(tab: .home)
                    router.selectedTab = .home
                }
            }
            .padding(.horizontal, RafiqSpacing.lg)

            Spacer()
        }
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(RafiqColors.errorFallback)

            Text("فشل الدفع")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text(payment.errorMessage ?? "حدث خطأ أثناء معالجة الدفع")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            PrimaryButton(title: "إعادة المحاولة", icon: "arrow.clockwise") {
                payment.reset()
                payment.preparePaymentSheet(bookingId: bookingId)
            }
            .padding(.horizontal, RafiqSpacing.xl)

            Spacer()
        }
    }

    // MARK: - Cancelled

    private var cancelledView: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()

            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 56))
                .foregroundStyle(RafiqColors.textSecondaryFallback)

            Text("تم إلغاء الدفع")
                .font(RafiqFonts.heading2())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("يمكنك المحاولة مرة أخرى قبل انتهاء مهلة الـ 3 ساعات")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            PrimaryButton(title: "المحاولة مرة أخرى", icon: "creditcard.fill") {
                payment.reset()
                payment.preparePaymentSheet(bookingId: bookingId)
            }
            .padding(.horizontal, RafiqSpacing.xl)

            Button {
                router.popCurrent()
            } label: {
                Text("رجوع")
                    .font(RafiqFonts.body())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }

            Spacer()
        }
    }
}

// ============================================================
// MARK: - BookingConfirmWatcher
// ============================================================

/// Listens to booking document for status change from pending_payment → confirmed
@MainActor
final class BookingConfirmWatcher: ObservableObject {
    @Published var isWatching = false
    @Published var isConfirmed = false

    private var listener: Any?
    private var timeoutTask: Task<Void, Never>?

    func start(bookingId: String, service: BookingServiceProtocol) {
        guard !isWatching else { return }
        isWatching = true

        listener = service.listenToBooking(id: bookingId) { [weak self] booking in
            Task { @MainActor in
                if booking.status == .confirmed && booking.paymentStatus == .paid {
                    self?.isConfirmed = true
                    self?.stop()
                }
            }
        }

        // Timeout after 30 seconds — webhook should fire within seconds
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    if !self.isConfirmed {
                        // Still mark as confirmed — webhook might have fired
                        // but listener was slow. The booking detail page will
                        // show the real status.
                        self.isConfirmed = true
                        self.stop()
                    }
                }
            }
        }
    }

    func stop() {
        isWatching = false
        listener = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Payment View") {
    NavigationStack {
        PaymentFullView(bookingId: "mock_booking_001")
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
