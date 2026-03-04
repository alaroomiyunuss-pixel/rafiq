// PATH: ios-app/Rafiq/Features/Trips/
// FILENAME: HomeSearchView.swift

import SwiftUI

// ============================================================
// MARK: - HomeSearchViewModel
// ============================================================

@MainActor
final class HomeSearchViewModel: ObservableObject {
    @Published var originCity: City?
    @Published var destCity: City?
    @Published var selectedDate: Date = Date()
    @Published var useDate = false
    @Published var showOriginPicker = false
    @Published var showDestPicker = false
    @Published var showDatePicker = false
    @Published var showResults = false

    var canSearch: Bool {
        originCity != nil && destCity != nil
    }

    var searchSummary: String {
        guard let origin = originCity, let dest = destCity else { return "" }
        var text = "\(origin.nameAr) → \(dest.nameAr)"
        if useDate {
            text += " · \(selectedDate.arabicShortDate)"
        }
        return text
    }

    func swapCities() {
        let temp = originCity
        originCity = destCity
        destCity = temp
    }

    func search() {
        guard canSearch else { return }
        showResults = true
    }

    func reset() {
        originCity = nil
        destCity = nil
        selectedDate = Date()
        useDate = false
        showResults = false
    }
}

// ============================================================
// MARK: - HomeSearchView
// ============================================================

struct HomeSearchView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = HomeSearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Search card
            searchCard
                .padding(.horizontal, RafiqSpacing.md)
                .padding(.top, RafiqSpacing.sm)

            // Results
            if viewModel.showResults {
                TripsListView(
                    originCityId: viewModel.originCity?.cityId,
                    destCityId: viewModel.destCity?.cityId,
                    date: viewModel.useDate ? viewModel.selectedDate : nil
                )
            } else {
                searchHints
            }
        }
        .background(RafiqColors.backgroundFallback)
        .sheet(isPresented: $viewModel.showOriginPicker) {
            CityPickerView(title: "مدينة الانطلاق") { city in
                viewModel.originCity = city
            }
        }
        .sheet(isPresented: $viewModel.showDestPicker) {
            CityPickerView(title: "مدينة الوصول") { city in
                viewModel.destCity = city
            }
        }
    }

    // MARK: - Search Card

    private var searchCard: some View {
        AppCard(shadow: .medium) {
            VStack(spacing: RafiqSpacing.md) {
                // Origin + Destination + Swap
                HStack(spacing: RafiqSpacing.sm) {
                    VStack(spacing: RafiqSpacing.sm) {
                        citySelector(
                            label: "من",
                            city: viewModel.originCity,
                            placeholder: "مدينة الانطلاق",
                            dotColor: RafiqColors.primaryFallback
                        ) {
                            viewModel.showOriginPicker = true
                        }

                        citySelector(
                            label: "إلى",
                            city: viewModel.destCity,
                            placeholder: "مدينة الوصول",
                            dotColor: RafiqColors.errorFallback
                        ) {
                            viewModel.showDestPicker = true
                        }
                    }

                    // Swap button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.swapCities()
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(RafiqColors.primaryFallback)
                            .frame(width: 40, height: 40)
                            .background(RafiqColors.primaryFallback.opacity(0.1))
                            .clipShape(Circle())
                    }
                }

                Divider()

                // Date toggle + picker
                dateRow

                // Search button
                PrimaryButton(
                    title: "ابحث عن رحلة",
                    icon: "magnifyingglass",
                    isDisabled: !viewModel.canSearch
                ) {
                    viewModel.search()
                }
            }
        }
    }

    // MARK: City Selector Row

    private func citySelector(
        label: String,
        city: City?,
        placeholder: String,
        dotColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: RafiqSpacing.sm) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)

                Text(label)
                    .font(RafiqFonts.small())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
                    .frame(width: 24)

                Text(city?.nameAr ?? placeholder)
                    .font(RafiqFonts.bodyBold())
                    .foregroundStyle(
                        city != nil
                            ? RafiqColors.textPrimaryFallback
                            : RafiqColors.textSecondaryFallback.opacity(0.6)
                    )

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.5))
            }
            .padding(RafiqSpacing.sm + 2)
            .background(RafiqColors.backgroundFallback)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
        }
    }

    // MARK: Date Row

    private var dateRow: some View {
        VStack(spacing: RafiqSpacing.sm) {
            HStack {
                Toggle(isOn: $viewModel.useDate) {
                    HStack(spacing: RafiqSpacing.sm) {
                        Image(systemName: "calendar")
                            .foregroundStyle(RafiqColors.primaryFallback)
                        Text("تحديد تاريخ")
                            .font(RafiqFonts.body())
                            .foregroundStyle(RafiqColors.textPrimaryFallback)
                    }
                }
                .tint(RafiqColors.primaryFallback)
            }

            if viewModel.useDate {
                DatePicker(
                    "التاريخ",
                    selection: $viewModel.selectedDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ar_SA"))
                .labelsHidden()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.useDate)
    }

    // MARK: Search Hints

    private var searchHints: some View {
        VStack(spacing: RafiqSpacing.lg) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.3))

            Text("اختر مدينة الانطلاق والوصول للبحث")
                .font(RafiqFonts.body())
                .foregroundStyle(RafiqColors.textSecondaryFallback)

            // Popular routes
            VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                Text("مسارات شائعة")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
                    .padding(.horizontal, RafiqSpacing.md)

                popularRouteChip("الرياض", "جدة")
                popularRouteChip("الدمام", "الرياض")
                popularRouteChip("مكة المكرمة", "المدينة المنورة")
            }

            Spacer()
        }
    }

    private func popularRouteChip(_ from: String, _ to: String) -> some View {
        Button {
            // Set cities from popular routes
            let loader = CitiesLoader.shared
            loader.loadIfNeeded()
            viewModel.originCity = loader.cities.first(where: { $0.nameAr == from })
            viewModel.destCity = loader.cities.first(where: { $0.nameAr == to })
        } label: {
            HStack(spacing: RafiqSpacing.sm) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(RafiqColors.primaryFallback)
                Text("\(from) → \(to)")
                    .font(RafiqFonts.caption())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)
                Spacer()
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
            .background(RafiqColors.surfaceFallback)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
            .padding(.horizontal, RafiqSpacing.md)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Home Search") {
    NavigationStack {
        HomeSearchView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Home Search - Filled") {
    NavigationStack {
        HomeSearchView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
