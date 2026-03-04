// PATH: ios-app/Rafiq/Features/Cities/
// FILENAME: CityPickerView.swift

import SwiftUI

// ============================================================
// MARK: - Cities Loader (from sa_cities.json)
// ============================================================

@MainActor
final class CitiesLoader: ObservableObject {
    static let shared = CitiesLoader()

    @Published var cities: [City] = []
    @Published var isLoaded = false

    private init() {}

    func loadIfNeeded() {
        guard !isLoaded else { return }

        guard let url = Bundle.main.url(forResource: "sa_cities", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ sa_cities.json not found in bundle")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([CityJSON].self, from: data)
            cities = decoded.map { json in
                City(
                    id: json.id,
                    nameAr: json.nameAr,
                    nameEn: json.nameEn,
                    lat: json.lat,
                    lng: json.lng,
                    region: json.region,
                    country: "SA"
                )
            }
            isLoaded = true
        } catch {
            print("⚠️ Failed to decode sa_cities.json: \(error)")
        }
    }

    func search(query: String) -> [City] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return cities }

        return cities.filter {
            $0.nameAr.localizedCaseInsensitiveContains(trimmed) ||
            $0.nameEn.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func city(byId id: String) -> City? {
        cities.first(where: { $0.id == id })
    }
}

// JSON shape matching sa_cities.json
private struct CityJSON: Decodable {
    let id: String
    let nameAr: String
    let nameEn: String
    let lat: Double
    let lng: Double
    let region: String
}

// ============================================================
// MARK: - Region Helpers
// ============================================================

private enum SaudiRegion: String, CaseIterable {
    case all = "all"
    case central = "central"
    case western = "western"
    case eastern = "eastern"
    case northern = "northern"
    case southern = "southern"

    var displayName: String {
        switch self {
        case .all: return "الكل"
        case .central: return "الوسطى"
        case .western: return "الغربية"
        case .eastern: return "الشرقية"
        case .northern: return "الشمالية"
        case .southern: return "الجنوبية"
        }
    }
}

// ============================================================
// MARK: - CityPickerView
// ============================================================

struct CityPickerView: View {
    let title: String
    let onSelect: (City) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = CitiesLoader.shared
    @State private var searchText = ""
    @State private var selectedRegion: SaudiRegion = .all

    private var filteredCities: [City] {
        var results = loader.search(query: searchText)
        if selectedRegion != .all {
            results = results.filter { $0.region == selectedRegion.rawValue }
        }
        return results
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Region filter
                regionFilter

                // Cities list
                if !loader.isLoaded {
                    LoadingView(message: "جاري تحميل المدن...")
                } else if filteredCities.isEmpty {
                    emptySearchState
                } else {
                    cityList
                }
            }
            .background(RafiqColors.backgroundFallback)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        dismiss()
                    }
                    .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
            .onAppear {
                loader.loadIfNeeded()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: RafiqSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RafiqColors.textSecondaryFallback)
                .font(.system(size: 16))

            TextField("ابحث عن مدينة...", text: $searchText)
                .font(RafiqFonts.body())
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(RafiqSpacing.sm + 4)
        .background(RafiqColors.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
        .padding(.horizontal, RafiqSpacing.md)
        .padding(.top, RafiqSpacing.sm)
    }

    // MARK: - Region Filter

    private var regionFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RafiqSpacing.sm) {
                ForEach(SaudiRegion.allCases, id: \.self) { region in
                    regionChip(region)
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
        }
    }

    private func regionChip(_ region: SaudiRegion) -> some View {
        let isSelected = selectedRegion == region
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRegion = region
            }
        } label: {
            Text(region.displayName)
                .font(RafiqFonts.caption())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : RafiqColors.textPrimaryFallback)
                .padding(.horizontal, RafiqSpacing.md)
                .padding(.vertical, RafiqSpacing.sm)
                .background(isSelected ? RafiqColors.primaryFallback : RafiqColors.surfaceFallback)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule()
                            .stroke(RafiqColors.textSecondaryFallback.opacity(0.2), lineWidth: 1)
                    }
                }
        }
    }

    // MARK: - City List

    private var cityList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredCities) { city in
                    cityRow(city)
                }
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.top, RafiqSpacing.xs)
        }
    }

    private func cityRow(_ city: City) -> some View {
        Button {
            onSelect(city)
            dismiss()
        } label: {
            HStack(spacing: RafiqSpacing.md) {
                // City icon
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(RafiqColors.primaryFallback)
                    .frame(width: 36, height: 36)
                    .background(RafiqColors.primaryFallback.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))

                // Names
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.nameAr)
                        .font(RafiqFonts.bodyBold())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    Text(city.nameEn)
                        .font(RafiqFonts.caption())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }

                Spacer()

                // Region badge
                if let region = city.region {
                    Text(regionDisplayName(region))
                        .font(RafiqFonts.small())
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RafiqColors.backgroundFallback)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.5))
            }
            .padding(.vertical, RafiqSpacing.sm + 2)
            .padding(.horizontal, RafiqSpacing.sm)
        }
        .background(RafiqColors.surfaceFallback)
    }

    // MARK: - Empty Search

    private var emptySearchState: some View {
        VStack(spacing: RafiqSpacing.md) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))

            Text("لا توجد نتائج")
                .font(RafiqFonts.heading3())
                .foregroundStyle(RafiqColors.textPrimaryFallback)

            Text("جرب البحث باسم مختلف أو غيّر المنطقة")
                .font(RafiqFonts.caption())
                .foregroundStyle(RafiqColors.textSecondaryFallback)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func regionDisplayName(_ region: String) -> String {
        SaudiRegion(rawValue: region)?.displayName ?? region
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("City Picker - Origin") {
    CityPickerView(title: "مدينة الانطلاق") { city in
        print("Selected: \(city.nameAr)")
    }
    .environment(\.layoutDirection, .rightToLeft)
    .onAppear {
        // Inject mock cities for preview
        let loader = CitiesLoader.shared
        if !loader.isLoaded {
            loader.cities = [
                City(id: "riyadh", nameAr: "الرياض", nameEn: "Riyadh", lat: 24.71, lng: 46.67, region: "central"),
                City(id: "jeddah", nameAr: "جدة", nameEn: "Jeddah", lat: 21.48, lng: 39.19, region: "western"),
                City(id: "dammam", nameAr: "الدمام", nameEn: "Dammam", lat: 26.42, lng: 50.08, region: "eastern"),
                City(id: "makkah", nameAr: "مكة المكرمة", nameEn: "Makkah", lat: 21.38, lng: 39.85, region: "western"),
                City(id: "madinah", nameAr: "المدينة المنورة", nameEn: "Madinah", lat: 24.52, lng: 39.56, region: "western"),
                City(id: "tabuk", nameAr: "تبوك", nameEn: "Tabuk", lat: 28.38, lng: 36.55, region: "northern"),
                City(id: "abha", nameAr: "أبها", nameEn: "Abha", lat: 18.21, lng: 42.50, region: "southern"),
                City(id: "hail", nameAr: "حائل", nameEn: "Hail", lat: 27.51, lng: 41.72, region: "northern"),
                City(id: "najran", nameAr: "نجران", nameEn: "Najran", lat: 17.49, lng: 44.12, region: "southern"),
                City(id: "khobar", nameAr: "الخبر", nameEn: "Khobar", lat: 26.21, lng: 50.19, region: "eastern"),
            ]
            loader.isLoaded = true
        }
    }
}

#Preview("City Picker - Destination") {
    CityPickerView(title: "مدينة الوصول") { city in
        print("Selected: \(city.nameAr)")
    }
    .environment(\.layoutDirection, .rightToLeft)
    .onAppear {
        let loader = CitiesLoader.shared
        if !loader.isLoaded {
            loader.cities = [
                City(id: "riyadh", nameAr: "الرياض", nameEn: "Riyadh", lat: 24.71, lng: 46.67, region: "central"),
                City(id: "jeddah", nameAr: "جدة", nameEn: "Jeddah", lat: 21.48, lng: 39.19, region: "western"),
            ]
            loader.isLoaded = true
        }
    }
}
