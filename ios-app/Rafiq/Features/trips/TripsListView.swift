// PATH: ios-app/Rafiq/Features/Trips/
// FILENAME: TripsListView.swift

import SwiftUI

// ============================================================
// MARK: - TripsListViewModel
// ============================================================

@MainActor
final class TripsListViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sortOption: SortOption = .dateAsc

    enum SortOption: String, CaseIterable {
        case dateAsc = "الأقرب تاريخاً"
        case priceLow = "الأقل سعراً"
        case priceHigh = "الأعلى سعراً"
        case ratingHigh = "الأعلى تقييماً"
    }

    var sortedTrips: [Trip] {
        switch sortOption {
        case .dateAsc:
            return trips.sorted { $0.tripDate < $1.tripDate }
        case .priceLow:
            return trips.sorted { $0.pricePerSeatHalalas < $1.pricePerSeatHalalas }
        case .priceHigh:
            return trips.sorted { $0.pricePerSeatHalalas > $1.pricePerSeatHalalas }
        case .ratingHigh:
            return trips.sorted { $0.driverRating > $1.driverRating }
        }
    }

    func search(
        service: TripsServiceProtocol,
        originCityId: String?,
        destCityId: String?,
        date: Date?
    ) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let results = try await service.searchTrips(
                    from: originCityId,
                    to: destCityId,
                    date: date
                )
                trips = results
            } catch {
                errorMessage = "فشل في تحميل الرحلات. حاول مرة أخرى"
            }
            isLoading = false
        }
    }
}

// ============================================================
// MARK: - TripsListView
// ============================================================

struct TripsListView: View {
    let originCityId: String?
    let destCityId: String?
    let date: Date?

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = TripsListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Sort bar
            if !viewModel.trips.isEmpty {
                sortBar
            }

            // Content
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "جاري البحث عن رحلات...")
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(
                        title: "خطأ",
                        message: error
                    ) {
                        loadTrips()
                    }
                } else if viewModel.sortedTrips.isEmpty {
                    EmptyStateView.noTrips
                } else {
                    tripsList
                }
            }
        }
        .onAppear {
            loadTrips()
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RafiqSpacing.sm) {
                Text("\(viewModel.trips.count) رحلة")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
                    .padding(.trailing, RafiqSpacing.xs)

                ForEach(TripsListViewModel.SortOption.allCases, id: \.self) { option in
                    sortChip(option)
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
        }
        .background(RafiqColors.surfaceFallback)
    }

    private func sortChip(_ option: TripsListViewModel.SortOption) -> some View {
        let isSelected = viewModel.sortOption == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.sortOption = option
            }
        } label: {
            Text(option.rawValue)
                .font(RafiqFonts.small())
                .foregroundStyle(isSelected ? .white : RafiqColors.textPrimaryFallback)
                .padding(.horizontal, RafiqSpacing.sm + 2)
                .padding(.vertical, 6)
                .background(isSelected ? RafiqColors.primaryFallback : RafiqColors.backgroundFallback)
                .clipShape(Capsule())
        }
    }

    // MARK: - Trips List

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: RafiqSpacing.md) {
                ForEach(viewModel.sortedTrips) { trip in
                    Button {
                        router.showTripDetail(trip.tripId)
                    } label: {
                        TripCardView(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
        }
    }

    // MARK: - Load

    private func loadTrips() {
        viewModel.search(
            service: environment.trips,
            originCityId: originCityId,
            destCityId: destCityId,
            date: date
        )
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Trips List - Results") {
    TripsListView(
        originCityId: "riyadh",
        destCityId: "jeddah",
        date: nil
    )
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Trips List - Empty") {
    TripsListView(
        originCityId: "tabuk",
        destCityId: "neom",
        date: nil
    )
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
