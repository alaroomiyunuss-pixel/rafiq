// PATH: ios-app/Rafiq/Features/Trips/
// FILENAME: TripDetailView.swift

import SwiftUI

// ============================================================
// MARK: - TripDetailViewModel
// ============================================================

@MainActor
final class TripDetailViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var listener: Any?

    func load(tripId: String, service: TripsServiceProtocol) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await service.getTrip(id: tripId)
                trip = result
            } catch {
                errorMessage = "فشل في تحميل تفاصيل الرحلة"
            }
            isLoading = false
        }
    }

    func listenToUpdates(tripId: String, service: TripsServiceProtocol) {
        listener = service.listenToTrip(id: tripId) { [weak self] updated in
            Task { @MainActor in
                self?.trip = updated
            }
        }
    }

    var canBook: Bool {
        guard let trip else { return false }
        return trip.isBookable
    }

    var seatOptions: [Int] {
        guard let trip else { return [] }
        return Array(1...trip.availableSeats)
    }
}

// ============================================================
// MARK: - TripDetailView
// ============================================================

struct TripDetailView_Full: View {
    let tripId: String

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = TripDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "جاري تحميل تفاصيل الرحلة...")
            } else if let error = viewModel.errorMessage {
                ErrorStateView(title: "خطأ", message: error) {
                    viewModel.load(tripId: tripId, service: environment.trips)
                }
            } else if let trip = viewModel.trip {
                tripContent(trip)
            }
        }
        .navigationTitle("تفاصيل الرحلة")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load(tripId: tripId, service: environment.trips)
        }
    }

    // MARK: - Trip Content

    @ViewBuilder
    private func tripContent(_ trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: RafiqSpacing.md) {
                // Route card
                routeCard(trip)

                // Date & Time
                dateTimeCard(trip)

                // Driver info
                driverCard(trip)

                // Meeting point
                meetingPointCard(trip)

                // Vehicle
                vehicleCard(trip)

                // Notes
                if let notes = trip.notes, !notes.isEmpty {
                    notesCard(notes)
                }

                // Price summary
                priceCard(trip)

                // Support buttons
                supportCard

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.sm)
        }
        .background(RafiqColors.backgroundFallback)
        .overlay(alignment: .bottom) {
            if viewModel.canBook && trip.driverId != environment.currentUser?.uid {
                bookButton(trip)
            }
        }
    }

    // MARK: - Route Card

    private func routeCard(_ trip: Trip) -> some View {
        AppCard(shadow: .medium) {
            HStack(spacing: RafiqSpacing.md) {
                // Route dots
                VStack(spacing: 0) {
                    Circle().fill(RafiqColors.primaryFallback).frame(width: 12, height: 12)
                    Rectangle()
                        .fill(RafiqColors.textSecondaryFallback.opacity(0.3))
                        .frame(width: 2, height: 40)
                    Circle().fill(RafiqColors.errorFallback).frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: RafiqSpacing.lg + 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("نقطة الانطلاق")
                            .font(RafiqFonts.small())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                        Text(trip.originNameAr)
                            .font(RafiqFonts.heading3())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("الوجهة")
                            .font(RafiqFonts.small())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                        Text(trip.destNameAr)
                            .font(RafiqFonts.heading3())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)
                    }
                }

                Spacer()

                // Status
                statusBadge(trip.status)
            }
        }
    }

    // MARK: - Date & Time

    private func dateTimeCard(_ trip: Trip) -> some View {
        AppCard {
            HStack(spacing: RafiqSpacing.lg) {
                detailItem(icon: "calendar", label: "التاريخ", value: trip.tripDate.arabicFullDate)
                Spacer()
                detailItem(icon: "clock.fill", label: "الوقت", value: trip.tripDate.arabicTime)
            }
        }
    }

    // MARK: - Driver Card

    private func driverCard(_ trip: Trip) -> some View {
        AppCard {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))

                VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                    Text(trip.driverName)
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    HStack(spacing: RafiqSpacing.sm) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(RafiqColors.warningFallback)
                            Text(String(format: "%.1f", trip.driverRating))
                                .font(RafiqFonts.bodyBold())
                                .foregroundStyle(RafiqColors.textPrimaryFallback)
                        }

                        Text("·")
                            .foregroundStyle(RafiqColors.textSecondaryFallback)

                        Button {
                            router.navigate(to: .reviews(userId: trip.driverId))
                        } label: {
                            Text("التقييمات")
                                .font(RafiqFonts.caption())
                                .foregroundStyle(RafiqColors.primaryFallback)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))
            }
        }
    }

    // MARK: - Meeting Point Card

    private func meetingPointCard(_ trip: Trip) -> some View {
        AppCardWithHeader(
            title: "نقطة التجمع",
            subtitle: trip.meetingMode.displayName,
            icon: trip.meetingMode.icon,
            iconColor: RafiqColors.accentFallback
        ) {
            VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                // Mode explanation
                meetingModeExplanation(trip.meetingMode)

                // Address if available
                if let point = trip.meetingPoint, let address = point.address, !address.isEmpty {
                    HStack(spacing: RafiqSpacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(RafiqColors.errorFallback)
                        Text(address)
                            .font(RafiqFonts.body())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)
                    }
                }

                // Map preview if coordinates available
                if let point = trip.meetingPoint {
                    MapPreviewView(point: point, height: 160)
                }
            }
        }
    }

    @ViewBuilder
    private func meetingModeExplanation(_ mode: MeetingMode) -> some View {
        let (text, icon, color): (String, String, Color) = {
            switch mode {
            case .mapPin:
                return ("السائق حدد نقطة التجمع على الخريطة. توجه إليها في الموعد المحدد", "location.fill", RafiqColors.primaryFallback)
            case .manualAddress:
                return ("السائق كتب العنوان أدناه. تواصل معه إذا احتجت توضيح", "text.alignright", RafiqColors.accentFallback)
            case .driverPicksUp:
                return ("السائق يوصلك! حدد موقعك على الخريطة عند الحجز وسيأتي إليك", "car.side.fill", RafiqColors.successFallback)
            }
        }()

        HStack(alignment: .top, spacing: RafiqSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
        }
        .padding(RafiqSpacing.sm)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ trip: Trip) -> some View {
        AppCard {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: "car.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(RafiqColors.primaryFallback)
                    .frame(width: 40, height: 40)
                    .background(RafiqColors.primaryFallback.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.vehicleSummary)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Text("\(trip.totalSeats) مقعد إجمالي · \(trip.availableSeats) متاح")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
                Spacer()
            }
        }
    }

    // MARK: - Notes Card

    private func notesCard(_ notes: String) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: RafiqSpacing.sm) {
                Image(systemName: "note.text")
                    .foregroundStyle(RafiqColors.accentFallback)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ملاحظات السائق")
                        .font(RafiqFonts.small())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                    Text(notes)
                        .font(RafiqFonts.body())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                }
            }
        }
    }

    // MARK: - Price Card

    private func priceCard(_ trip: Trip) -> some View {
        AppCard(shadow: .medium) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("سعر المقعد")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                    Text(trip.formattedPrice)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(RafiqColors.primaryFallback)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("مقاعد متاحة")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                    Text("\(trip.availableSeats)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            trip.availableSeats > 0
                                ? RafiqColors.successFallback
                                : RafiqColors.errorFallback
                        )
                }
            }
        }
    }

    // MARK: - Support Card

    private var supportCard: some View {
        AppCard {
            VStack(spacing: RafiqSpacing.md) {
                HStack(spacing: RafiqSpacing.sm) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                    Text("تحتاج مساعدة؟")
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)
                    Spacer()
                }

                HStack(spacing: RafiqSpacing.md) {
                    // Saudi WhatsApp
                    whatsappButton(
                        label: "دعم السعودية",
                        flag: "🇸🇦",
                        url: DeepLinks.saudiSupportURL()
                    )

                    // Yemen WhatsApp
                    whatsappButton(
                        label: "دعم اليمن",
                        flag: "🇾🇪",
                        url: DeepLinks.yemenSupportURL()
                    )
                }
            }
        }
    }

    private func whatsappButton(label: String, flag: String, url: URL?) -> some View {
        Button {
            if let url { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: RafiqSpacing.xs) {
                Text(flag)
                    .font(.system(size: 18))
                Text(label)
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RafiqSpacing.sm + 2)
            .background(Color(hex: "#25D366").opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
        }
    }

    // MARK: - Book Button (sticky bottom)

    private func bookButton(_ trip: Trip) -> some View {
        VStack(spacing: 0) {
            Divider()
            PrimaryButton(
                title: "احجز مقعدك · \(trip.formattedPrice)",
                icon: "ticket.fill"
            ) {
                router.navigate(to: .bookingFlow(tripId: trip.tripId))
            }
            .padding(RafiqSpacing.md)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func detailItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(RafiqColors.primaryFallback)
                Text(label)
                    .font(RafiqFonts.small())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
            }
            Text(value)
                .font(RafiqFonts.bodyBold())
                .foregroundStyle(RafiqColors.textPrimaryFallback)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusBadge(_ status: TripStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .open: return ("متاح", RafiqColors.successFallback)
            case .full: return ("مكتمل", RafiqColors.warningFallback)
            case .inProgress: return ("جارية", RafiqColors.accentFallback)
            case .completed: return ("منتهية", RafiqColors.textSecondaryFallback)
            case .cancelled: return ("ملغية", RafiqColors.errorFallback)
            }
        }()

        return Text(text)
            .font(RafiqFonts.small())
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Trip Detail") {
    NavigationStack {
        TripDetailView_Full(tripId: "mock_trip_001")
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
