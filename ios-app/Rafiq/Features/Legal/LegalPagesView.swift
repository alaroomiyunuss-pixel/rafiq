// PATH: ios-app/Rafiq/Features/Legal/
// FILENAME: LegalPagesView.swift

import SwiftUI

// ============================================================
// MARK: - LegalPage Type
// ============================================================

enum LegalPageType: String, CaseIterable, Identifiable {
    case terms = "شروط الاستخدام"
    case privacy = "سياسة الخصوصية"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .terms: return "doc.text.fill"
        case .privacy: return "lock.shield.fill"
        }
    }

    var lastUpdated: String {
        "2025/01/01" // Update with each release
    }
}

// ============================================================
// MARK: - LegalPagesView (Index)
// ============================================================

struct LegalPagesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.md) {
                ForEach(LegalPageType.allCases) { page in
                    NavigationLink(value: page) {
                        legalRow(page)
                    }
                    .buttonStyle(.plain)
                }

                // App version
                appVersionFooter
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("القانونية")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: LegalPageType.self) { page in
            LegalDetailView(pageType: page)
        }
    }

    private func legalRow(_ page: LegalPageType) -> some View {
        AppCard {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: page.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(RafiqColors.primaryFallback)
                    .frame(width: 36, height: 36)
                    .background(RafiqColors.primaryFallback.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.rawValue)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Text("آخر تحديث: \(page.lastUpdated)")
                        .font(RafiqFonts.small())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
            }
        }
    }

    private var appVersionFooter: some View {
        VStack(spacing: RafiqSpacing.xs) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 24))
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.3))

            Text("رفيق")
                .font(RafiqFonts.bodyBold())
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.5))

            Text("الإصدار 1.0.0")
                .font(RafiqFonts.small())
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, RafiqSpacing.xl)
    }
}

// ============================================================
// MARK: - Legal Detail View
// ============================================================

struct LegalDetailView: View {
    let pageType: LegalPageType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RafiqSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                    Image(systemName: pageType.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(RafiqColors.primaryFallback)

                    Text(pageType.rawValue)
                        .font(RafiqFonts.heading1())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    Text("آخر تحديث: \(pageType.lastUpdated)")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }

                Divider()

                // Content
                switch pageType {
                case .terms:
                    termsContent
                case .privacy:
                    privacyContent
                }
            }
            .padding(RafiqSpacing.md)
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle(pageType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Terms Content

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: RafiqSpacing.lg) {
            legalSection(
                title: "1. مقدمة",
                body: "مرحباً بك في تطبيق رفيق. باستخدامك للتطبيق، فإنك توافق على الالتزام بهذه الشروط والأحكام. يرجى قراءتها بعناية قبل استخدام خدماتنا."
            )

            legalSection(
                title: "2. وصف الخدمة",
                body: "رفيق هو تطبيق لمشاركة الرحلات يربط بين السائقين والركاب داخل المملكة العربية السعودية. التطبيق يوفر منصة للتواصل وحجز المقاعد ولا يعتبر شركة نقل."
            )

            legalSection(
                title: "3. التسجيل والحساب",
                body: "يجب أن يكون عمرك 18 سنة أو أكثر لاستخدام التطبيق. أنت مسؤول عن الحفاظ على سرية حسابك وجميع الأنشطة التي تتم من خلاله."
            )

            legalSection(
                title: "4. الحجز والدفع",
                body: "جميع المدفوعات تتم إلكترونياً عبر بطاقات الدفع أو Apple Pay. مهلة الدفع 3 ساعات من وقت الحجز. بعد انتهاء المهلة يتم إلغاء الحجز تلقائياً."
            )

            legalSection(
                title: "5. سياسة الإلغاء",
                body: "الإلغاء قبل 24 ساعة من موعد الرحلة: استرداد كامل المبلغ. الإلغاء خلال 24 ساعة: لا يوجد استرداد. عدم الحضور: لا يوجد استرداد."
            )

            legalSection(
                title: "6. التقييمات",
                body: "نافذة التقييم مفتوحة لمدة ساعتين بعد اكتمال الرحلة. التقييمات يجب أن تكون صادقة وبناءة. يحق لنا إزالة التقييمات المسيئة."
            )

            legalSection(
                title: "7. المسؤولية",
                body: "رفيق ليس مسؤولاً عن أي أضرار ناتجة عن الرحلات. السائقون مسؤولون عن التأمين والتراخيص المطلوبة. يُنصح الركاب بالتحقق من هوية السائق قبل الركوب."
            )

            legalSection(
                title: "8. التواصل",
                body: "للاستفسارات والدعم، تواصل معنا عبر واتساب من خلال أرقام الدعم المتوفرة في التطبيق."
            )
        }
    }

    // MARK: - Privacy Content

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: RafiqSpacing.lg) {
            legalSection(
                title: "1. البيانات التي نجمعها",
                body: "نجمع: الاسم، رقم الجوال، الموقع الجغرافي (عند استخدام الخريطة)، بيانات الدفع (تُعالج عبر Stripe ولا نخزنها)، وسجل الرحلات والحجوزات."
            )

            legalSection(
                title: "2. كيف نستخدم بياناتك",
                body: "نستخدم بياناتك لتقديم خدمة مشاركة الرحلات، معالجة المدفوعات، إرسال الإشعارات، تحسين تجربة المستخدم، والتواصل بخصوص حجوزاتك."
            )

            legalSection(
                title: "3. مشاركة البيانات",
                body: "نشارك اسمك ورقم جوالك مع الطرف الآخر في الرحلة (السائق أو الراكب) فقط بعد تأكيد الحجز. لا نبيع بياناتك لأي طرف ثالث."
            )

            legalSection(
                title: "4. تخزين البيانات",
                body: "بياناتك مخزنة بشكل آمن على خوادم Firebase (Google Cloud) في منطقة الشرق الأوسط (الدمام). نستخدم التشفير لحماية بياناتك."
            )

            legalSection(
                title: "5. الإشعارات",
                body: "نرسل إشعارات push لتحديثات الحجز، الرسائل الجديدة، وتذكيرات التقييم. يمكنك إيقاف الإشعارات من إعدادات جهازك."
            )

            legalSection(
                title: "6. حقوقك",
                body: "يحق لك طلب حذف حسابك وجميع بياناتك. يحق لك طلب نسخة من بياناتك. تواصل معنا عبر واتساب لأي طلبات تتعلق بالخصوصية."
            )

            legalSection(
                title: "7. الأمان",
                body: "نستخدم بروتوكولات أمان متقدمة لحماية بياناتك. المدفوعات تُعالج عبر Stripe المتوافق مع PCI DSS. نراجع إجراءاتنا الأمنية بشكل دوري."
            )
        }
    }

    // MARK: - Section Helper

    private func legalSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
            Text(title)
                .font(RafiqFonts.heading3())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text(body)
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Legal Pages") {
    NavigationStack {
        LegalPagesView()
    }
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Terms") {
    NavigationStack {
        LegalDetailView(pageType: .terms)
    }
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Privacy") {
    NavigationStack {
        LegalDetailView(pageType: .privacy)
    }
    .environment(\.layoutDirection, .rightToLeft)
}
