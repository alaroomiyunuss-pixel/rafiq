// PATH: ios-app/Rafiq/App/
// FILENAME: AppEnvironment.swift

import Foundation
import FirebaseFirestore
import Combine

// ============================================================
// MARK: - Service Protocols
// ============================================================

// MARK: AuthService

protocol AuthServiceProtocol {
    var currentUserId: String? { get }
    var isLoggedIn: Bool { get }
    func sendOTP(phone: String) async throws -> String
    func verifyOTP(verificationId: String, code: String) async throws -> AppUser
    func signOut() throws
    func fetchCurrentUser() async throws -> AppUser
    func updateProfile(name: String?, photoURL: String?) async throws -> AppUser
    func updateFCMToken(_ token: String) async throws
}

// MARK: TripsService

protocol TripsServiceProtocol {
    func searchTrips(from originId: String?, to destId: String?, date: Date?) async throws -> [Trip]
    func getTrip(id: String) async throws -> Trip
    func getDriverTrips(driverId: String) async throws -> [Trip]
    func createTrip(_ data: CreateTripData) async throws -> String
    func updateTrip(id: String, updates: UpdateTripData) async throws
    func deleteTrip(id: String) async throws
    func listenToTrip(id: String, onChange: @escaping (Trip) -> Void) -> ListenerRegistration
}

struct CreateTripData {
    let originCityId: String
    let destCityId: String
    let dateTime: Date
    let totalSeats: Int
    let pricePerSeatHalalas: Int
    let vehicleId: String
    let meetingMode: MeetingMode
    let meetingPoint: MeetingPoint?
    let notes: String?
}

struct UpdateTripData {
    var dateTime: Date?
    var totalSeats: Int?
    var pricePerSeatHalalas: Int?
    var vehicleId: String?
    var meetingMode: MeetingMode?
    var meetingPoint: MeetingPoint?
    var notes: String?
}

// MARK: BookingService

protocol BookingServiceProtocol {
    func createBooking(tripId: String, seatCount: Int, pickupPoint: MeetingPoint?) async throws -> String
    func getBooking(id: String) async throws -> Booking
    func getPassengerBookings(passengerId: String) async throws -> [Booking]
    func getDriverBookings(driverId: String) async throws -> [Booking]
    func cancelBooking(id: String, reason: String?) async throws -> CancelResult
    func createPaymentIntent(bookingId: String) async throws -> PaymentIntentResult
    func listenToBooking(id: String, onChange: @escaping (Booking) -> Void) -> ListenerRegistration
}

struct CancelResult {
    let bookingId: String
    let refunded: Bool
    let refundId: String?
}

struct PaymentIntentResult {
    let clientSecret: String
    let paymentIntentId: String
    let amountHalalas: Int
}

// MARK: ChatService

protocol ChatServiceProtocol {
    func getConversations(userId: String) async throws -> [Conversation]
    func sendMessage(conversationId: String, text: String) async throws
    func markAsRead(conversationId: String) async throws
    func listenToMessages(conversationId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration
    func listenToConversations(userId: String, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration
}

// MARK: RatingsService

protocol RatingsServiceProtocol {
    func submitRating(bookingId: String, rating: Int, comment: String?) async throws -> String
    func getReviews(userId: String) async throws -> [Review]
}

// MARK: CitiesService

protocol CitiesServiceProtocol {
    func loadCities() async throws -> [City]
    func searchCities(query: String) -> [City]
}

// MARK: SupportLinksService

protocol SupportLinksServiceProtocol {
    func whatsappURL(for region: SupportRegion) -> URL?
}

enum SupportRegion {
    case saudi, yemen
}

// MARK: NotificationsService

protocol NotificationsServiceProtocol {
    func requestPermission() async throws -> Bool
    func registerToken(_ token: String) async throws
}

// ============================================================
// MARK: - Dependency Container
// ============================================================

@MainActor
final class AppEnvironment: ObservableObject {
    let auth: AuthServiceProtocol
    let trips: TripsServiceProtocol
    let bookings: BookingServiceProtocol
    let chat: ChatServiceProtocol
    let ratings: RatingsServiceProtocol
    let cities: CitiesServiceProtocol
    let support: SupportLinksServiceProtocol
    let notifications: NotificationsServiceProtocol

    @Published var currentUser: AppUser?
    @Published var isLoggedIn: Bool = false

    init(
        auth: AuthServiceProtocol,
        trips: TripsServiceProtocol,
        bookings: BookingServiceProtocol,
        chat: ChatServiceProtocol,
        ratings: RatingsServiceProtocol,
        cities: CitiesServiceProtocol,
        support: SupportLinksServiceProtocol,
        notifications: NotificationsServiceProtocol
    ) {
        self.auth = auth
        self.trips = trips
        self.bookings = bookings
        self.chat = chat
        self.ratings = ratings
        self.cities = cities
        self.support = support
        self.notifications = notifications
        self.isLoggedIn = auth.isLoggedIn
    }

    /// Production environment with real Firebase services
    static func live() -> AppEnvironment {
        // TODO: Replace mocks with real implementations
        AppEnvironment(
            auth: MockAuthService(),
            trips: MockTripsService(),
            bookings: MockBookingService(),
            chat: MockChatService(),
            ratings: MockRatingsService(),
            cities: MockCitiesService(),
            support: MockSupportLinksService(),
            notifications: MockNotificationsService()
        )
    }

    /// Preview/testing environment with mocks
    static func preview() -> AppEnvironment {
        let env = AppEnvironment(
            auth: MockAuthService(),
            trips: MockTripsService(),
            bookings: MockBookingService(),
            chat: MockChatService(),
            ratings: MockRatingsService(),
            cities: MockCitiesService(),
            support: MockSupportLinksService(),
            notifications: MockNotificationsService()
        )
        env.currentUser = .mock
        env.isLoggedIn = true
        return env
    }
}

// ============================================================
// MARK: - Mock Data
// ============================================================

extension AppUser {
    static let mock = AppUser(
        id: "mock_user_001",
        name: "يونس",
        phone: "+966501234567",
        photoURL: nil,
        role: .both,
        avgRating: 4.8,
        totalRatings: 23,
        fcmToken: nil,
        lastActive: Timestamp(date: Date()),
        createdAt: Timestamp(date: Date()),
        verificationStatus: nil,
        companyId: nil
    )

    static let mockDriver = AppUser(
        id: "mock_driver_001",
        name: "أحمد",
        phone: "+966509876543",
        photoURL: nil,
        role: .driver,
        avgRating: 4.9,
        totalRatings: 87,
        fcmToken: nil,
        lastActive: Timestamp(date: Date()),
        createdAt: Timestamp(date: Date()),
        verificationStatus: nil,
        companyId: nil
    )
}

extension Trip {
    static let mock = Trip(
        id: "mock_trip_001",
        driverId: "mock_driver_001",
        driverName: "أحمد",
        driverPhoto: nil,
        driverRating: 4.9,
        originCityId: "riyadh",
        originNameAr: "الرياض",
        destCityId: "jeddah",
        destNameAr: "جدة",
        dateTime: Timestamp(date: Date().addingTimeInterval(48 * 3600)),
        totalSeats: 3,
        availableSeats: 2,
        pricePerSeatHalalas: 15000,
        vehicleId: "v_001",
        vehicleSummary: "Toyota كامري 2023 أبيض",
        meetingMode: .mapPin,
        meetingPoint: MeetingPoint(lat: 24.7136, lng: 46.6753, address: "حي العليا، الرياض"),
        notes: "رحلة مباشرة بدون توقف",
        status: .open,
        confirmedBookings: 1,
        createdAt: Timestamp(date: Date()),
        updatedAt: Timestamp(date: Date()),
        cancelledAt: nil,
        startedAt: nil,
        completedAt: nil,
        companyId: nil,
        recurringId: nil
    )

    static let mockList: [Trip] = [
        .mock,
        Trip(
            id: "mock_trip_002",
            driverId: "mock_driver_002",
            driverName: "سعد",
            driverPhoto: nil,
            driverRating: 4.5,
            originCityId: "dammam",
            originNameAr: "الدمام",
            destCityId: "riyadh",
            destNameAr: "الرياض",
            dateTime: Timestamp(date: Date().addingTimeInterval(72 * 3600)),
            totalSeats: 4,
            availableSeats: 4,
            pricePerSeatHalalas: 12000,
            vehicleId: "v_002",
            vehicleSummary: "Hyundai سوناتا 2024 رمادي",
            meetingMode: .manualAddress,
            meetingPoint: MeetingPoint(lat: 26.42, lng: 50.09, address: "أمام مطار الدمام"),
            notes: nil,
            status: .open,
            confirmedBookings: 0,
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date()),
            cancelledAt: nil, startedAt: nil, completedAt: nil,
            companyId: nil, recurringId: nil
        ),
    ]
}

extension Booking {
    static let mock = Booking(
        id: "mock_booking_001",
        tripId: "mock_trip_001",
        passengerId: "mock_user_001",
        passengerName: "يونس",
        driverId: "mock_driver_001",
        seatCount: 1,
        totalAmountHalalas: 15000,
        platformFeeHalalas: 1500,
        paymentIntentId: "pi_mock",
        paymentStatus: .paid,
        status: .confirmed,
        cancelledBy: nil,
        cancelReason: nil,
        pickupPoint: nil,
        createdAt: Timestamp(date: Date()),
        expiresAt: Timestamp(date: Date().addingTimeInterval(3 * 3600)),
        confirmedAt: Timestamp(date: Date()),
        completedAt: nil,
        cancelledAt: nil,
        refundedAt: nil,
        ratingWindowStatus: nil,
        ratingWindowClosesAt: nil,
        passengerRated: nil,
        driverRated: nil,
        promoCodeId: nil,
        refundId: nil
    )
}

extension Conversation {
    static let mock = Conversation(
        id: "mock_convo_001",
        bookingId: "mock_booking_001",
        tripId: "mock_trip_001",
        participants: ["mock_user_001", "mock_driver_001"],
        lastMessage: "أنا في الطريق",
        lastMessageAt: Timestamp(date: Date()),
        unreadCount: ["mock_user_001": 1, "mock_driver_001": 0],
        createdAt: Timestamp(date: Date())
    )
}

extension ChatMessage {
    static let mockList: [ChatMessage] = [
        ChatMessage(
            id: "msg_001",
            senderId: "mock_driver_001",
            text: "أهلاً، الرحلة مؤكدة إن شاء الله",
            timestamp: Timestamp(date: Date().addingTimeInterval(-3600)),
            readBy: ["mock_driver_001", "mock_user_001"],
            messageType: "text", mediaURL: nil
        ),
        ChatMessage(
            id: "msg_002",
            senderId: "mock_user_001",
            text: "تمام، وين نقطة التجمع بالضبط؟",
            timestamp: Timestamp(date: Date().addingTimeInterval(-1800)),
            readBy: ["mock_user_001", "mock_driver_001"],
            messageType: "text", mediaURL: nil
        ),
        ChatMessage(
            id: "msg_003",
            senderId: "mock_driver_001",
            text: "أمام مول الرياض بارك، البوابة الشمالية",
            timestamp: Timestamp(date: Date().addingTimeInterval(-600)),
            readBy: ["mock_driver_001"],
            messageType: "text", mediaURL: nil
        ),
    ]
}

// ============================================================
// MARK: - Mock Implementations
// ============================================================

// MARK: MockAuthService

final class MockAuthService: AuthServiceProtocol {
    var currentUserId: String? = "mock_user_001"
    var isLoggedIn: Bool = true

    func sendOTP(phone: String) async throws -> String { "mock_verification_id" }
    func verifyOTP(verificationId: String, code: String) async throws -> AppUser { .mock }
    func signOut() throws { isLoggedIn = false }
    func fetchCurrentUser() async throws -> AppUser { .mock }
    func updateProfile(name: String?, photoURL: String?) async throws -> AppUser { .mock }
    func updateFCMToken(_ token: String) async throws {}
}

// MARK: MockTripsService

final class MockTripsService: TripsServiceProtocol {
    func searchTrips(from originId: String?, to destId: String?, date: Date?) async throws -> [Trip] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return Trip.mockList
    }
    func getTrip(id: String) async throws -> Trip { .mock }
    func getDriverTrips(driverId: String) async throws -> [Trip] { Trip.mockList }
    func createTrip(_ data: CreateTripData) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        return "new_trip_id"
    }
    func updateTrip(id: String, updates: UpdateTripData) async throws {}
    func deleteTrip(id: String) async throws {}
    func listenToTrip(id: String, onChange: @escaping (Trip) -> Void) -> ListenerRegistration {
        onChange(.mock)
        return MockListenerRegistration()
    }
}

// MARK: MockBookingService

final class MockBookingService: BookingServiceProtocol {
    func createBooking(tripId: String, seatCount: Int, pickupPoint: MeetingPoint?) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        return "new_booking_id"
    }
    func getBooking(id: String) async throws -> Booking { .mock }
    func getPassengerBookings(passengerId: String) async throws -> [Booking] { [.mock] }
    func getDriverBookings(driverId: String) async throws -> [Booking] { [.mock] }
    func cancelBooking(id: String, reason: String?) async throws -> CancelResult {
        CancelResult(bookingId: id, refunded: true, refundId: "re_mock")
    }
    func createPaymentIntent(bookingId: String) async throws -> PaymentIntentResult {
        PaymentIntentResult(clientSecret: "pi_mock_secret", paymentIntentId: "pi_mock", amountHalalas: 15000)
    }
    func listenToBooking(id: String, onChange: @escaping (Booking) -> Void) -> ListenerRegistration {
        onChange(.mock)
        return MockListenerRegistration()
    }
}

// MARK: MockChatService

final class MockChatService: ChatServiceProtocol {
    func getConversations(userId: String) async throws -> [Conversation] { [.mock] }
    func sendMessage(conversationId: String, text: String) async throws {}
    func markAsRead(conversationId: String) async throws {}
    func listenToMessages(conversationId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        onChange(ChatMessage.mockList)
        return MockListenerRegistration()
    }
    func listenToConversations(userId: String, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        onChange([.mock])
        return MockListenerRegistration()
    }
}

// MARK: MockRatingsService

final class MockRatingsService: RatingsServiceProtocol {
    func submitRating(bookingId: String, rating: Int, comment: String?) async throws -> String { "review_mock" }
    func getReviews(userId: String) async throws -> [Review] { [] }
}

// MARK: MockCitiesService

final class MockCitiesService: CitiesServiceProtocol {
    private let cities: [City] = [
        City(id: "riyadh", nameAr: "الرياض", nameEn: "Riyadh", lat: 24.71, lng: 46.67, region: "central"),
        City(id: "jeddah", nameAr: "جدة", nameEn: "Jeddah", lat: 21.48, lng: 39.19, region: "western"),
        City(id: "dammam", nameAr: "الدمام", nameEn: "Dammam", lat: 26.42, lng: 50.08, region: "eastern"),
        City(id: "makkah", nameAr: "مكة المكرمة", nameEn: "Makkah", lat: 21.38, lng: 39.85, region: "western"),
        City(id: "madinah", nameAr: "المدينة المنورة", nameEn: "Madinah", lat: 24.52, lng: 39.56, region: "western"),
    ]

    func loadCities() async throws -> [City] { cities }
    func searchCities(query: String) -> [City] {
        guard !query.isEmpty else { return cities }
        return cities.filter {
            $0.nameAr.contains(query) || $0.nameEn.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: MockSupportLinksService

final class MockSupportLinksService: SupportLinksServiceProtocol {
    func whatsappURL(for region: SupportRegion) -> URL? {
        switch region {
        case .saudi: return URL(string: "https://wa.me/966000000000")
        case .yemen: return URL(string: "https://wa.me/967000000000")
        }
    }
}

// MARK: MockNotificationsService

final class MockNotificationsService: NotificationsServiceProtocol {
    func requestPermission() async throws -> Bool { true }
    func registerToken(_ token: String) async throws {}
}

// MARK: MockListenerRegistration

final class MockListenerRegistration: NSObject, ListenerRegistration {
    func remove() {}
}
