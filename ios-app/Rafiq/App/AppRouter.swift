// PATH: ios-app/Rafiq/App/
// FILENAME: AppRouter.swift

import SwiftUI

// ============================================================
// MARK: - Routes
// ============================================================

enum AppRoute: Hashable {
    // Trips
    case tripDetail(tripId: String)
    case postTrip
    case editTrip(tripId: String)

    // Bookings
    case bookingFlow(tripId: String)
    case bookingDetail(bookingId: String)
    case payment(bookingId: String)

    // Chat
    case chat(conversationId: String)

    // Driver
    case driverDashboard
    case myTrips

    // Profile
    case editProfile
    case vehicles
    case addVehicle
    case rating(bookingId: String)
    case reviews(userId: String)
    case support
}

// ============================================================
// MARK: - Router
// ============================================================

@MainActor
final class AppRouter: ObservableObject {

    // MARK: Tabs

    enum Tab: Int, CaseIterable, Hashable {
        case home = 0
        case bookings = 1
        case chat = 2
        case profile = 3

        var title: String {
            switch self {
            case .home: return "الرئيسية"
            case .bookings: return "حجوزاتي"
            case .chat: return "المحادثات"
            case .profile: return "حسابي"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .bookings: return "ticket.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .profile: return "person.fill"
            }
        }
    }

    // MARK: State

    @Published var selectedTab: Tab = .home
    @Published var homePath = NavigationPath()
    @Published var bookingsPath = NavigationPath()
    @Published var chatPath = NavigationPath()
    @Published var profilePath = NavigationPath()

    // Sheet / Alert state
    @Published var presentedSheet: AppSheet?
    @Published var alertItem: AlertItem?

    // MARK: Navigation

    func navigate(to route: AppRoute, in tab: Tab? = nil) {
        let targetTab = tab ?? selectedTab

        // Switch tab if needed
        if targetTab != selectedTab {
            selectedTab = targetTab
        }

        // Push route onto correct stack
        switch targetTab {
        case .home:
            homePath.append(route)
        case .bookings:
            bookingsPath.append(route)
        case .chat:
            chatPath.append(route)
        case .profile:
            profilePath.append(route)
        }
    }

    func popCurrent() {
        switch selectedTab {
        case .home:
            if !homePath.isEmpty { homePath.removeLast() }
        case .bookings:
            if !bookingsPath.isEmpty { bookingsPath.removeLast() }
        case .chat:
            if !chatPath.isEmpty { chatPath.removeLast() }
        case .profile:
            if !profilePath.isEmpty { profilePath.removeLast() }
        }
    }

    func popToRoot(tab: Tab? = nil) {
        let target = tab ?? selectedTab
        switch target {
        case .home: homePath = NavigationPath()
        case .bookings: bookingsPath = NavigationPath()
        case .chat: chatPath = NavigationPath()
        case .profile: profilePath = NavigationPath()
        }
    }

    func popAllToRoot() {
        homePath = NavigationPath()
        bookingsPath = NavigationPath()
        chatPath = NavigationPath()
        profilePath = NavigationPath()
    }

    // MARK: Convenience Navigators

    func showTripDetail(_ tripId: String) {
        navigate(to: .tripDetail(tripId: tripId), in: .home)
    }

    func showBookingDetail(_ bookingId: String) {
        navigate(to: .bookingDetail(bookingId: bookingId), in: .bookings)
    }

    func showChat(_ conversationId: String) {
        navigate(to: .chat(conversationId: conversationId), in: .chat)
    }

    func showPayment(_ bookingId: String) {
        navigate(to: .payment(bookingId: bookingId), in: .bookings)
    }

    func showRating(_ bookingId: String) {
        navigate(to: .rating(bookingId: bookingId), in: .bookings)
    }

    func showPostTrip() {
        navigate(to: .postTrip, in: .home)
    }

    func showSupport() {
        navigate(to: .support, in: .profile)
    }

    // MARK: Sheets

    func present(_ sheet: AppSheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    // MARK: Alerts

    func showAlert(title: String, message: String, primaryAction: AlertAction? = nil) {
        alertItem = AlertItem(title: title, message: message, primaryAction: primaryAction)
    }

    func dismissAlert() {
        alertItem = nil
    }
}

// ============================================================
// MARK: - Sheets
// ============================================================

enum AppSheet: Identifiable {
    case cityPicker(mode: CityPickerMode)
    case datePicker(onSelect: (Date) -> Void)
    case vehiclePicker(onSelect: (Vehicle) -> Void)
    case meetingPointMap(mode: MeetingMode, onSelect: (MeetingPoint) -> Void)
    case confirmCancel(bookingId: String)

    var id: String {
        switch self {
        case .cityPicker(let mode): return "cityPicker_\(mode)"
        case .datePicker: return "datePicker"
        case .vehiclePicker: return "vehiclePicker"
        case .meetingPointMap: return "meetingPointMap"
        case .confirmCancel(let id): return "confirmCancel_\(id)"
        }
    }
}

enum CityPickerMode: String {
    case origin, destination
}

// ============================================================
// MARK: - Alert Item
// ============================================================

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var primaryAction: AlertAction?
}

struct AlertAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void

    init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
}
