// PATH: ios-app/Rafiq/Features/Ratings/
// FILENAME: RatingView.swift

import SwiftUI

// ============================================================
// MARK: - RatingViewModel
// ============================================================

@MainActor
final class RatingViewModel: ObservableObject {
    @Published var rating: Int = 0
    @Published var comment = ""
    @Published var isSubmitting = false
    @Published var isSubmitted = false
    @Published var errorMessage: String?
    @Published var booking: Booking?

    let maxComment = 200

    var canSubmit: Bool {
        rating >= 1 && rating <= 5 && !isSubmitting
    }

    var ratingLabel: String {
        switch rating {
        case 1: return "سيء 😞"
        case 2: return "ضعيف 😐"
        case 3: return "مقبول 🙂"
        case 4: return "جيد 😊"
        case 5: return "ممتاز 🌟"
        default: return "اختر تقييمك"
        }
    }

    func loadBooking(bookingId: String, service: BookingServiceProtocol) {
        Task {
            do {
                booking = try await service.getBooking(id: bookingId)
            } catch {
                errorMessage = "فشل في تحميل بيانات الحجز"
            }
        }
    }

    func submit(
        bookingId: String,
        service: RatingsServiceProtocol,
        onSuccess: @escaping () -> Void
    ) {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let trimmed = comment.trimmingCharacters(in: .whitespaces)
                _ = try await service.submitRating(
                    bookingId: bookingId,
                    rating: rating,
                    comment: trimmed.isEmpty ? nil : trimmed
                )
                isSubmitted = true
                onSuccess()
            } catch {
                errorMessage = "فشل في إرسال التقييم. حاول مرة أخرى"
            }
            isSubmitting = false
        }
    }
}

// ============================================================
// MARK: - RatingView
// ============================================================

struct RatingFullView: View {
    let bookingId: String

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = RatingViewModel()

    var body: some View {
        Group {
            if viewModel.isSubmitted {
                successView
            } else {
                ratingForm
            }
        }
        .navigationTitle("تقييم الرحلة")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadBooking(bookingId: bookingId, service: environment.bookings)
        }
    }

    // MARK: - Rating Form

    private var ratingForm: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.xl) {
                Spacer().frame(height: RafiqSpacing.md)

                // Header
                VStack(spacing: RafiqSpacing.md) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(RafiqColors.warningFallback)

                    Text("كيف كانت رحلتك؟")
                        .font(RafiqFonts.heading1())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    if let booking = viewModel.booking {
                        Text("حجز #\(booking.bookingId.prefix(6))")
                            .font(RafiqFonts.caption())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }
                }

                // Stars
                starPicker

                // Rating label
                Text(viewModel.ratingLabel)
                    .font(RafiqFonts.heading3())
                    .foregroundStyle(
                        viewModel.rating > 0
                            ? RafiqColors.textPrimaryFallback
                            : RafiqColors.textSecondaryFallback
                    )
                    .animation(.easeInOut(duration: 0.15), value: viewModel.rating)

                // Comment
                commentSection

                // Time warning
                timeWarning

                // Error
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) { viewModel.errorMessage = nil }
                }

                // Submit
                PrimaryButton(
                    title: "إرسال التقييم",
                    icon: "paperplane.fill",
                    isLoading: viewModel.isSubmitting,
                    isDisabled: !viewModel.canSubmit
                ) {
                    viewModel.submit(
                        bookingId: bookingId,
                        service: environment.ratings
                    ) {
                        // Success handled by isSubmitted
                    }
                }

                // Skip
                Button {
                    router.popCurrent()
                } label: {
                    Text("تخطي")
                        .font(RafiqFonts.body())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
                .padding(.bottom, RafiqSpacing.lg)
            }
            .padding(.horizontal, RafiqSpacing.md)
        }
        .background(RafiqColors.backgroundFallback)
    }

    // MARK: - Star Picker

    private var starPicker: some View {
        HStack(spacing: RafiqSpacing.md) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        viewModel.rating = star
                    }
                } label: {
                    Image(systemName: star <= viewModel.rating ? "star.fill" : "star")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            star <= viewModel.rating
                                ? RafiqColors.warningFallback
                                : RafiqColors.textSecondaryFallback.opacity(0.3)
                        )
                        .scaleEffect(star <= viewModel.rating ? 1.1 : 1.0)
                }
            }
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                Text("تعليق (اختياري)")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)

                TextField("شاركنا تجربتك...", text: $viewModel.comment, axis: .vertical)
                    .font(RafiqFonts.body())
                    .lineLimit(3...6)
                    .onChange(of: viewModel.comment) { _, newValue in
                        viewModel.comment = String(newValue.prefix(viewModel.maxComment))
                    }

                HStack {
                    Spacer()
                    Text("\(viewModel.comment.count)/\(viewModel.maxComment)")
                        .font(RafiqFonts.small())
                        .foregroundStyle(
                            viewModel.comment.count >= viewModel.maxComment
                                ? RafiqColors.errorFallback
                                : RafiqColors.textSecondaryFallback
                        )
                }
            }
        }
    }

    // MARK: - Time Warning

    private var timeWarning: some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14))
                .foregroundStyle(RafiqColors.warningFallback)

            Text("نافذة التقييم مفتوحة لمدة ساعتين بعد اكتمال الرحلة")
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
        .padding(RafiqSpacing.sm)
        .background(RafiqColors.warningFallback.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: RafiqSpacing.xl) {
            Spacer()

            // Stars animation
            HStack(spacing: 8) {
                ForEach(1...viewModel.rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(RafiqColors.warningFallback)
                }
            }

            Text("شكراً لتقييمك! ⭐")
                .font(RafiqFonts.heading1())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("تقييمك يساعد المجتمع على تحسين تجربة الرحلات")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            PrimaryButton(title: "تم", icon: "checkmark") {
                router.popCurrent()
            }
            .padding(.horizontal, RafiqSpacing.xl)

            Spacer()
        }
        .background(RafiqColors.backgroundFallback)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Rating View") {
    NavigationStack {
        RatingFullView(bookingId: "mock_booking_001")
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
