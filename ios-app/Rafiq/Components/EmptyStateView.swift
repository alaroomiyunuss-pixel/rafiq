// PATH: ios-app/Rafiq/Components/
// FILENAME: EmptyStateView.swift

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.5))
                .padding(.bottom, RafiqSpacing.sm)

            // Title
            Text(title)
                .font(RafiqFonts.heading2())
                .foregroundStyle(RafiqColors.textPrimaryFallback)
                .multilineTextAlignment(.center)

            // Message
            Text(message)
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RafiqSpacing.xl)

            // Optional action button
            if let buttonTitle, let buttonAction {
                PrimaryButton(title: buttonTitle, action: buttonAction)
                    .padding(.horizontal, RafiqSpacing.xxl)
                    .padding(.top, RafiqSpacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RafiqColors.backgroundFallback)
    }
}

// MARK: - Preset Empty States

extension EmptyStateView {
    static var noTrips: EmptyStateView {
        EmptyStateView(
            icon: "car.2.fill",
            title: "لا توجد رحلات",
            message: "لا توجد رحلات متاحة حالياً. جرب البحث بتاريخ أو وجهة مختلفة",
            buttonTitle: "بحث جديد",
            buttonAction: {}
        )
    }

    static var noBookings: EmptyStateView {
        EmptyStateView(
            icon: "ticket.fill",
            title: "لا توجد حجوزات",
            message: "لم تقم بأي حجز بعد. ابحث عن رحلة واحجز مقعدك",
            buttonTitle: "ابحث عن رحلة",
            buttonAction: {}
        )
    }

    static var noMessages: EmptyStateView {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right.fill",
            title: "لا توجد محادثات",
            message: "ستظهر المحادثات هنا بعد تأكيد الحجز"
        )
    }

    static var noReviews: EmptyStateView {
        EmptyStateView(
            icon: "star.fill",
            title: "لا توجد تقييمات",
            message: "لم تحصل على تقييمات بعد"
        )
    }
}

// MARK: - Preview

#Preview("Empty States") {
    TabView {
        EmptyStateView.noTrips
            .tabItem { Label("رحلات", systemImage: "car") }

        EmptyStateView.noBookings
            .tabItem { Label("حجوزات", systemImage: "ticket") }

        EmptyStateView.noMessages
            .tabItem { Label("محادثات", systemImage: "bubble") }

        EmptyStateView.noReviews
            .tabItem { Label("تقييمات", systemImage: "star") }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
