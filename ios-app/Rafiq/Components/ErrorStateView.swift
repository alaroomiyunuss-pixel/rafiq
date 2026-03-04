// PATH: ios-app/Rafiq/Components/
// FILENAME: ErrorStateView.swift

import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    var icon: String = "exclamationmark.triangle.fill"
    var retryTitle: String = "إعادة المحاولة"
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(RafiqColors.errorFallback.opacity(0.7))
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

            // Retry button
            if let retryAction {
                PrimaryButton(
                    title: retryTitle,
                    icon: "arrow.clockwise",
                    action: retryAction
                )
                .padding(.horizontal, RafiqSpacing.xxl)
                .padding(.top, RafiqSpacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RafiqColors.backgroundFallback)
    }
}

// MARK: - Inline Error Banner

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white)
                .font(.system(size: 18))

            Text(message)
                .font(RafiqFonts.caption())
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(RafiqSpacing.md)
        .background(RafiqColors.errorFallback)
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
        .padding(.horizontal, RafiqSpacing.md)
    }
}

// MARK: - Preset Errors

extension ErrorStateView {
    static func network(retry: @escaping () -> Void) -> ErrorStateView {
        ErrorStateView(
            title: "لا يوجد اتصال",
            message: "تحقق من اتصالك بالإنترنت وحاول مرة أخرى",
            icon: "wifi.slash",
            retryAction: retry
        )
    }

    static func server(retry: @escaping () -> Void) -> ErrorStateView {
        ErrorStateView(
            title: "خطأ في الخادم",
            message: "حدث خطأ غير متوقع. نعمل على إصلاحه في أقرب وقت",
            icon: "server.rack",
            retryAction: retry
        )
    }

    static func notFound() -> ErrorStateView {
        ErrorStateView(
            title: "غير موجود",
            message: "المحتوى المطلوب غير موجود أو تم حذفه",
            icon: "questionmark.folder.fill"
        )
    }

    static func permission() -> ErrorStateView {
        ErrorStateView(
            title: "غير مصرح",
            message: "ليس لديك صلاحية للوصول لهذا المحتوى",
            icon: "lock.fill"
        )
    }
}

// MARK: - Preview

#Preview("Error States") {
    VStack(spacing: 0) {
        ErrorBanner(message: "فشل في حفظ التغييرات") {}
            .padding(.top)

        TabView {
            ErrorStateView.network {}
                .tabItem { Label("شبكة", systemImage: "wifi.slash") }

            ErrorStateView.server {}
                .tabItem { Label("خادم", systemImage: "server.rack") }

            ErrorStateView.notFound()
                .tabItem { Label("غير موجود", systemImage: "questionmark") }

            ErrorStateView.permission()
                .tabItem { Label("صلاحية", systemImage: "lock") }
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
