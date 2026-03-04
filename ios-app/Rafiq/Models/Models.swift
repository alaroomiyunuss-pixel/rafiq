// PATH: ios-app/Rafiq/Models/
// FILENAME: Models.swift

import Foundation
import FirebaseFirestore

// ============================================================
// MARK: - Enums
// ============================================================

enum UserRole: String, Codable, CaseIterable {
    case passenger
    case driver
    case both
    // Reserved
    case company
    case admin
}

enum TripStatus: String, Codable, CaseIterable {
    case open
    case full
    case inProgress = "in_progress"
    case completed
    case cancelled
}

enum BookingStatus: String, Codable, CaseIterable {
    case pendingPayment = "pending_payment"
    case confirmed
    case completed
    case cancelled
    case expired
}

enum PaymentStatus: String, Codable, CaseIterable {
    case unpaid
    case paid
    case failed
    case expired
    case refunded
    // Reserved
    case partialRefund = "partial_refund"
}

enum MeetingMode: String, Codable, CaseIterable {
    case mapPin = "MAP_PIN"
    case manualAddress = "MANUAL_ADDRESS"
    case driverPicksUp = "DRIVER_PICKS_UP"

    var displayName: String {
        switch self {
        case .mapPin: return "نقطة على الخريطة"
        case .manualAddress: return "عنوان يدوي"
        case .driverPicksUp: return "السائق يوصلك"
        }
    }

    var icon: String {
        switch self {
        case .mapPin: return "mappin.circle.fill"
        case .manualAddress: return "text.alignright"
        case .driverPicksUp: return "car.side.fill"
        }
    }
}

enum VehicleType: String, Codable, CaseIterable {
    case car
    // Reserved
    case bus
    case van
}

enum RatingWindowStatus: String, Codable {
    case closed
    case open
}

enum ReviewType: String, Codable {
    case passengerToDriver = "passenger_to_driver"
    case driverToPassenger = "driver_to_passenger"
}

// ============================================================
// MARK: - GeoPoint Model
// ============================================================

struct MeetingPoint: Codable, Equatable {
    let lat: Double
    let lng: Double
    var address: String?

    init(lat: Double, lng: Double, address: String? = nil) {
        self.lat = lat
        self.lng = lng
        self.address = address
    }

    init?(from data: [String: Any]?) {
        guard let data,
              let lat = data["lat"] as? Double,
              let lng = data["lng"] as? Double else { return nil }
        self.lat = lat
        self.lng = lng
        self.address = data["address"] as? String
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = ["lat": lat, "lng": lng]
        if let address { dict["address"] = address }
        return dict
    }
}

// ============================================================
// MARK: - AppUser
// ============================================================

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let phone: String
    var photoURL: String?
    var role: UserRole
    var avgRating: Double
    var totalRatings: Int
    var fcmToken: String?
    var lastActive: Timestamp?
    let createdAt: Timestamp?
    // Reserved
    var verificationStatus: String?
    var companyId: String?

    var uid: String { id ?? "" }
    var isDriver: Bool { role == .driver || role == .both }
    var isPassenger: Bool { role == .passenger || role == .both }
    var formattedRating: String { String(format: "%.1f", avgRating) }
}

// ============================================================
// MARK: - Vehicle
// ============================================================

struct Vehicle: Codable, Identifiable {
    @DocumentID var id: String?
    let make: String
    let model: String
    let year: Int
    let color: String
    let plateNumber: String
    var photoURL: String?
    var type: VehicleType
    let maxSeats: Int
    var isActive: Bool
    let createdAt: Timestamp?

    var summary: String { "\(make) \(model) \(year) \(color)" }
}

// ============================================================
// MARK: - City
// ============================================================

struct City: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let nameAr: String
    let nameEn: String
    let lat: Double
    let lng: Double
    var region: String?
    // Reserved
    var country: String?

    var cityId: String { id ?? "" }
}

// ============================================================
// MARK: - Trip
// ============================================================

struct Trip: Codable, Identifiable {
    @DocumentID var id: String?
    let driverId: String
    let driverName: String
    var driverPhoto: String?
    var driverRating: Double
    let originCityId: String
    let originNameAr: String
    let destCityId: String
    let destNameAr: String
    let dateTime: Timestamp
    let totalSeats: Int
    var availableSeats: Int
    let pricePerSeatHalalas: Int
    let vehicleId: String
    let vehicleSummary: String
    let meetingMode: MeetingMode
    var meetingPoint: MeetingPoint?
    var notes: String?
    var status: TripStatus
    var confirmedBookings: Int
    let createdAt: Timestamp?
    var updatedAt: Timestamp?
    var cancelledAt: Timestamp?
    var startedAt: Timestamp?
    var completedAt: Timestamp?
    // Reserved
    var companyId: String?
    var recurringId: String?

    // MARK: Computed

    var tripId: String { id ?? "" }
    var routeText: String { "\(originNameAr) → \(destNameAr)" }
    var priceInSAR: Double { Double(pricePerSeatHalalas) / 100.0 }
    var formattedPrice: String { String(format: "%.0f ر.س", priceInSAR) }
    var tripDate: Date { dateTime.dateValue() }
    var isEditable: Bool {
        status == .open &&
        confirmedBookings == 0 &&
        tripDate.timeIntervalSinceNow > 24 * 3600
    }
    var isDeletable: Bool {
        confirmedBookings == 0
    }
    var isBookable: Bool {
        status == .open && availableSeats > 0
    }

    // Custom Codable for MeetingPoint (Firestore map)
    enum CodingKeys: String, CodingKey {
        case id, driverId, driverName, driverPhoto, driverRating
        case originCityId, originNameAr, destCityId, destNameAr
        case dateTime, totalSeats, availableSeats
        case pricePerSeatHalalas, vehicleId, vehicleSummary
        case meetingMode, meetingPoint, notes, status, confirmedBookings
        case createdAt, updatedAt, cancelledAt, startedAt, completedAt
        case companyId, recurringId
    }
}

// ============================================================
// MARK: - Booking
// ============================================================

struct Booking: Codable, Identifiable {
    @DocumentID var id: String?
    let tripId: String
    let passengerId: String
    let passengerName: String
    let driverId: String
    let seatCount: Int
    let totalAmountHalalas: Int
    let platformFeeHalalas: Int
    var paymentIntentId: String?
    var paymentStatus: PaymentStatus
    var status: BookingStatus
    var cancelledBy: String?
    var cancelReason: String?
    var pickupPoint: MeetingPoint?
    let createdAt: Timestamp?
    let expiresAt: Timestamp?
    var confirmedAt: Timestamp?
    var completedAt: Timestamp?
    var cancelledAt: Timestamp?
    var refundedAt: Timestamp?
    var ratingWindowStatus: RatingWindowStatus?
    var ratingWindowClosesAt: Timestamp?
    var passengerRated: Bool?
    var driverRated: Bool?
    // Reserved
    var promoCodeId: String?
    var refundId: String?

    // MARK: Computed

    var bookingId: String { id ?? "" }
    var totalInSAR: Double { Double(totalAmountHalalas) / 100.0 }
    var formattedTotal: String { String(format: "%.0f ر.س", totalInSAR) }
    var isCancellable: Bool {
        status == .confirmed || status == .pendingPayment
    }
    var canRate: Bool {
        ratingWindowStatus == .open
    }
    var expiryDate: Date? { expiresAt?.dateValue() }
}

// ============================================================
// MARK: - Conversation
// ============================================================

struct Conversation: Codable, Identifiable {
    @DocumentID var id: String?
    let bookingId: String
    let tripId: String
    let participants: [String]
    var lastMessage: String?
    var lastMessageAt: Timestamp?
    var unreadCount: [String: Int]
    let createdAt: Timestamp?

    var conversationId: String { id ?? "" }

    func unreadFor(uid: String) -> Int {
        unreadCount[uid] ?? 0
    }

    func otherParticipant(myUid: String) -> String {
        participants.first(where: { $0 != myUid }) ?? ""
    }
}

// ============================================================
// MARK: - ChatMessage
// ============================================================

struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let senderId: String
    let text: String
    let timestamp: Timestamp
    var readBy: [String]
    // Reserved
    var messageType: String?
    var mediaURL: String?

    var messageId: String { id ?? "" }
    var sentDate: Date { timestamp.dateValue() }

    func isRead(by uid: String) -> Bool {
        readBy.contains(uid)
    }

    func isMine(uid: String) -> Bool {
        senderId == uid
    }
}

// ============================================================
// MARK: - Review
// ============================================================

struct Review: Codable, Identifiable {
    @DocumentID var id: String?
    let tripId: String
    let bookingId: String
    let reviewerId: String
    let revieweeId: String
    let type: ReviewType
    let rating: Int
    var comment: String?
    let createdAt: Timestamp?

    var reviewId: String { id ?? "" }

    var starsText: String {
        String(repeating: "★", count: rating) +
        String(repeating: "☆", count: 5 - rating)
    }
}

// ============================================================
// MARK: - AppConfig (Firestore config/app)
// ============================================================

struct AppConfig: Codable {
    let platformFeePercent: Int
    let minPriceHalalas: Int
    let paymentExpiryMinutes: Int
    let ratingWindowMinutes: Int
    let minTripLeadTimeHours: Int
    let whatsappSaudi: String
    let whatsappYemen: String
    var appVersion: String?
    var forceUpdate: Bool?

    static let defaults = AppConfig(
        platformFeePercent: 10,
        minPriceHalalas: 1000,
        paymentExpiryMinutes: 180,
        ratingWindowMinutes: 120,
        minTripLeadTimeHours: 4,
        whatsappSaudi: "+966000000000",
        whatsappYemen: "+967000000000",
        appVersion: "1.0.0",
        forceUpdate: false
    )
}

// ============================================================
// MARK: - Helpers: Halalas Formatting
// ============================================================

extension Int {
    /// Convert halalas to SAR string: 15000 → "150 ر.س"
    var asSAR: String {
        let sar = Double(self) / 100.0
        if sar.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f ر.س", sar)
        }
        return String(format: "%.2f ر.س", sar)
    }
}

// ============================================================
// MARK: - Helpers: Date Formatting (Arabic)
// ============================================================

extension Date {
    /// "الجمعة، 10 أبريل 2026"
    var arabicFullDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.dateStyle = .full
        return f.string(from: self)
    }

    /// "10 أبريل"
    var arabicShortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.dateFormat = "d MMMM"
        return f.string(from: self)
    }

    /// "06:00 ص"
    var arabicTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.dateFormat = "hh:mm a"
        return f.string(from: self)
    }

    /// "بعد 3 ساعات"
    var arabicRelative: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.unitsStyle = .full
        return f.localizedString(for: self, relativeTo: Date())
    }
}
