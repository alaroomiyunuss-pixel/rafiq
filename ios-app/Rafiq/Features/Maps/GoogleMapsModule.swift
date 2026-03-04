// PATH: ios-app/Rafiq/Features/Maps/
// FILENAME: GoogleMapsModule.swift

import SwiftUI
import GoogleMaps

// ============================================================
// MARK: - Google Maps Setup
// ============================================================

enum GoogleMapsSetup {
    static func configure() {
        let key = KeysManager.googleMapsAPIKey
        guard !key.isEmpty else {
            print("⚠️ Google Maps API key is empty — check Keys.plist")
            return
        }
        GMSServices.provideAPIKey(key)
    }
}

// ============================================================
// MARK: - Pin Picker View (User selects a point on map)
// ============================================================

struct PinPickerView: View {
    let title: String
    var initialLocation: MeetingPoint?
    let onConfirm: (MeetingPoint) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPoint: MeetingPoint
    @State private var addressText: String = ""
    @State private var isGeocoding = false

    // Default: Riyadh center
    private static let defaultLat = 24.7136
    private static let defaultLng = 46.6753

    init(
        title: String,
        initialLocation: MeetingPoint? = nil,
        onConfirm: @escaping (MeetingPoint) -> Void
    ) {
        self.title = title
        self.initialLocation = initialLocation
        self.onConfirm = onConfirm
        _selectedPoint = State(initialValue: initialLocation ?? MeetingPoint(
            lat: Self.defaultLat,
            lng: Self.defaultLng,
            address: nil
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Map
                GoogleMapViewRepresentable(
                    selectedPoint: $selectedPoint,
                    onCameraIdle: { point in
                        reverseGeocode(point)
                    }
                )
                .ignoresSafeArea(edges: .top)

                // Center pin overlay
                VStack {
                    Spacer()
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(RafiqColors.errorFallback)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Bottom card
                bottomCard
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
        }
    }

    // MARK: Bottom Card

    private var bottomCard: some View {
        VStack(spacing: RafiqSpacing.md) {
            // Address display
            HStack(spacing: RafiqSpacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(RafiqColors.primaryFallback)
                    .font(.system(size: 18))

                if isGeocoding {
                    HStack(spacing: RafiqSpacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("جاري تحديد العنوان...")
                            .font(RafiqFonts.caption())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }
                } else {
                    Text(addressText.isEmpty ? "حرّك الخريطة لتحديد النقطة" : addressText)
                        .font(RafiqFonts.body())
                        .foregroundStyle(
                            addressText.isEmpty
                                ? RafiqColors.textSecondaryFallback
                                : RafiqColors.textPrimaryFallback
                        )
                        .lineLimit(2)
                }

                Spacer()
            }

            // Coordinates
            Text(
                String(format: "%.4f, %.4f", selectedPoint.lat, selectedPoint.lng)
            )
            .font(RafiqFonts.small())
            .foregroundStyle(RafiqColors.textSecondaryFallback)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Confirm button
            PrimaryButton(
                title: "تأكيد الموقع",
                icon: "checkmark.circle.fill"
            ) {
                var confirmed = selectedPoint
                confirmed.address = addressText.isEmpty ? nil : addressText
                onConfirm(confirmed)
                dismiss()
            }
        }
        .padding(RafiqSpacing.md)
        .background(RafiqColors.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.xl, style: .continuous))
        .rafiqShadow(.heavy)
        .padding(.horizontal, RafiqSpacing.md)
        .padding(.bottom, RafiqSpacing.md)
    }

    // MARK: Reverse Geocode

    private func reverseGeocode(_ point: MeetingPoint) {
        isGeocoding = true
        let geocoder = GMSGeocoder()
        let coord = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng)

        geocoder.reverseGeocodeCoordinate(coord) { response, error in
            isGeocoding = false
            guard let result = response?.firstResult() else {
                addressText = ""
                return
            }
            let parts = [result.thoroughfare, result.subLocality, result.locality, result.administrativeArea]
            addressText = parts.compactMap { $0 }.joined(separator: "، ")
        }
    }
}

// ============================================================
// MARK: - Map Preview View (Read-only pin display)
// ============================================================

struct MapPreviewView: View {
    let point: MeetingPoint
    var height: CGFloat = 200

    var body: some View {
        GoogleMapStaticRepresentable(point: point)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
            .overlay(alignment: .bottomTrailing) {
                // Open in Maps button
                Button {
                    openInMaps()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 12))
                        Text("فتح الخريطة")
                            .font(RafiqFonts.small())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, RafiqSpacing.sm)
                    .padding(.vertical, 6)
                    .background(RafiqColors.primaryFallback)
                    .clipShape(Capsule())
                }
                .padding(RafiqSpacing.sm)
            }
    }

    private func openInMaps() {
        let urlString = "https://www.google.com/maps?q=\(point.lat),\(point.lng)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// ============================================================
// MARK: - UIViewRepresentable: Interactive Map
// ============================================================

struct GoogleMapViewRepresentable: UIViewRepresentable {
    @Binding var selectedPoint: MeetingPoint
    var onCameraIdle: ((MeetingPoint) -> Void)?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: selectedPoint.lat,
            longitude: selectedPoint.lng,
            zoom: 14
        )
        let options = GMSMapViewOptions()
        options.camera = camera

        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Only animate if significantly different
        let currentCenter = mapView.camera.target
        let distance = abs(currentCenter.latitude - selectedPoint.lat) + abs(currentCenter.longitude - selectedPoint.lng)
        if distance > 0.01 {
            let camera = GMSCameraPosition.camera(
                withLatitude: selectedPoint.lat,
                longitude: selectedPoint.lng,
                zoom: 14
            )
            mapView.animate(to: camera)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        let parent: GoogleMapViewRepresentable

        init(_ parent: GoogleMapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let newPoint = MeetingPoint(
                lat: position.target.latitude,
                lng: position.target.longitude,
                address: nil
            )
            parent.selectedPoint = newPoint
            parent.onCameraIdle?(newPoint)
        }
    }
}

// ============================================================
// MARK: - UIViewRepresentable: Static Map (Preview)
// ============================================================

struct GoogleMapStaticRepresentable: UIViewRepresentable {
    let point: MeetingPoint

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: point.lat,
            longitude: point.lng,
            zoom: 15
        )
        let options = GMSMapViewOptions()
        options.camera = camera

        let mapView = GMSMapView(options: options)
        mapView.isUserInteractionEnabled = false
        mapView.settings.setAllGesturesEnabled(false)

        // Add marker
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng)
        marker.title = point.address
        marker.icon = GMSMarker.markerImage(with: UIColor(RafiqColors.primaryFallback))
        marker.map = mapView

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let camera = GMSCameraPosition.camera(
            withLatitude: point.lat,
            longitude: point.lng,
            zoom: 15
        )
        mapView.camera = camera
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Pin Picker") {
    PinPickerView(
        title: "حدد نقطة التجمع",
        initialLocation: MeetingPoint(lat: 24.7136, lng: 46.6753, address: "حي العليا، الرياض")
    ) { point in
        print("Selected: \(point.lat), \(point.lng) — \(point.address ?? "no address")")
    }
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Map Preview") {
    VStack(spacing: RafiqSpacing.md) {
        MapPreviewView(
            point: MeetingPoint(lat: 24.7136, lng: 46.6753, address: "حي العليا، الرياض")
        )

        MapPreviewView(
            point: MeetingPoint(lat: 21.4858, lng: 39.1925, address: "حي الحمراء، جدة"),
            height: 150
        )
    }
    .padding()
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}
