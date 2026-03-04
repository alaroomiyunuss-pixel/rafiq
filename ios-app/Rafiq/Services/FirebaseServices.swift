// PATH: ios-app/Rafiq/Services/
// FILENAME: FirebaseServices.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging

private let db = Firestore.firestore()
private let functions = Functions.functions(region: "me-central1")

// ============================================================
// MARK: - FirebaseAuthService
// ============================================================

final class FirebaseAuthService: AuthServiceProtocol {
    var currentUserId: String? { Auth.auth().currentUser?.uid }
    var isLoggedIn: Bool { Auth.auth().currentUser != nil }

    func sendOTP(phone: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil) { verificationId, error in
                if let error { cont.resume(throwing: error); return }
                guard let id = verificationId else {
                    cont.resume(throwing: ServiceError.unknown("No verification ID")); return
                }
                cont.resume(returning: id)
            }
        }
    }

    func verifyOTP(verificationId: String, code: String) async throws -> AppUser {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: code
        )
        let result = try await Auth.auth().signIn(with: credential)
        let uid = result.user.uid

        // Check if user doc exists
        let snap = try await db.collection("users").document(uid).getDocument()
        if snap.exists, let user = try? snap.data(as: AppUser.self) {
            return user
        }

        // New user — create stub
        let newUser = AppUser(
            id: uid,
            name: "",
            phone: result.user.phoneNumber ?? "",
            photoURL: nil,
            role: .passenger,
            avgRating: 0,
            totalRatings: 0,
            fcmToken: nil,
            lastActive: Timestamp(date: Date()),
            createdAt: Timestamp(date: Date()),
            verificationStatus: nil,
            companyId: nil
        )
        try db.collection("users").document(uid).setData(from: newUser)
        return newUser
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func fetchCurrentUser() async throws -> AppUser {
        guard let uid = currentUserId else { throw ServiceError.unauthenticated }
        let snap = try await db.collection("users").document(uid).getDocument()
        guard let user = try? snap.data(as: AppUser.self) else { throw ServiceError.notFound }
        return user
    }

    func updateProfile(name: String?, photoURL: String?) async throws -> AppUser {
        guard let uid = currentUserId else { throw ServiceError.unauthenticated }
        var fields: [String: Any] = ["lastActive": FieldValue.serverTimestamp()]
        if let name { fields["name"] = name }
        if let photoURL { fields["photoURL"] = photoURL }
        try await db.collection("users").document(uid).updateData(fields)
        return try await fetchCurrentUser()
    }

    func updateFCMToken(_ token: String) async throws {
        guard let uid = currentUserId else { return }
        try await db.collection("users").document(uid).updateData([
            "fcmToken": token,
            "lastActive": FieldValue.serverTimestamp()
        ])
    }
}

// ============================================================
// MARK: - FirebaseTripsService
// ============================================================

final class FirebaseTripsService: TripsServiceProtocol {

    func searchTrips(from originId: String?, to destId: String?, date: Date?) async throws -> [Trip] {
        var query: Query = db.collection("trips")
            .whereField("status", isEqualTo: TripStatus.open.rawValue)
            .whereField("dateTime", isGreaterThan: Timestamp(date: Date()))
            .order(by: "dateTime")
            .limit(to: 50)

        if let originId {
            query = db.collection("trips")
                .whereField("status", isEqualTo: TripStatus.open.rawValue)
                .whereField("originCityId", isEqualTo: originId)
                .whereField("dateTime", isGreaterThan: Timestamp(date: Date()))
                .order(by: "dateTime")
                .limit(to: 50)
        }

        let snap = try await query.getDocuments()
        var trips = snap.documents.compactMap { try? $0.data(as: Trip.self) }

        // Client-side filters
        if let destId {
            trips = trips.filter { $0.destCityId == destId }
        }
        if let date {
            let calendar = Calendar.current
            trips = trips.filter { calendar.isDate($0.tripDate, inSameDayAs: date) }
        }

        return trips
    }

    func getTrip(id: String) async throws -> Trip {
        let snap = try await db.collection("trips").document(id).getDocument()
        guard let trip = try? snap.data(as: Trip.self) else { throw ServiceError.notFound }
        return trip
    }

    func getDriverTrips(driverId: String) async throws -> [Trip] {
        let snap = try await db.collection("trips")
            .whereField("driverId", isEqualTo: driverId)
            .order(by: "dateTime", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Trip.self) }
    }

    func createTrip(_ data: CreateTripData) async throws -> String {
        let params: [String: Any] = [
            "originCityId": data.originCityId,
            "destCityId": data.destCityId,
            "dateTime": data.dateTime.timeIntervalSince1970 * 1000,
            "totalSeats": data.totalSeats,
            "pricePerSeatHalalas": data.pricePerSeatHalalas,
            "vehicleId": data.vehicleId,
            "meetingMode": data.meetingMode.rawValue,
            "meetingPoint": data.meetingPoint?.asDictionary as Any,
            "notes": data.notes as Any
        ]
        let result = try await functions.httpsCallable("createTrip").call(params)
        guard let dict = result.data as? [String: Any],
              let tripId = dict["tripId"] as? String else {
            throw ServiceError.invalidResponse
        }
        return tripId
    }

    func updateTrip(id: String, updates: UpdateTripData) async throws {
        var params: [String: Any] = ["tripId": id]
        if let dt = updates.dateTime { params["dateTime"] = dt.timeIntervalSince1970 * 1000 }
        if let s = updates.totalSeats { params["totalSeats"] = s }
        if let p = updates.pricePerSeatHalalas { params["pricePerSeatHalalas"] = p }
        if let v = updates.vehicleId { params["vehicleId"] = v }
        if let m = updates.meetingMode { params["meetingMode"] = m.rawValue }
        if let mp = updates.meetingPoint { params["meetingPoint"] = mp.asDictionary }
        if let n = updates.notes { params["notes"] = n }
        _ = try await functions.httpsCallable("updateTrip").call(params)
    }

    func deleteTrip(id: String) async throws {
        _ = try await functions.httpsCallable("deleteTrip").call(["tripId": id])
    }

    func listenToTrip(id: String, onChange: @escaping (Trip) -> Void) -> ListenerRegistration {
        db.collection("trips").document(id).addSnapshotListener { snap, _ in
            guard let snap, snap.exists,
                  let trip = try? snap.data(as: Trip.self) else { return }
            onChange(trip)
        }
    }
}

// ============================================================
// MARK: - FirebaseBookingService
// ============================================================

final class FirebaseBookingService: BookingServiceProtocol {

    func createBooking(tripId: String, seatCount: Int, pickupPoint: MeetingPoint?) async throws -> String {
        var params: [String: Any] = [
            "tripId": tripId,
            "seatCount": seatCount
        ]
        if let pp = pickupPoint { params["pickupPoint"] = pp.asDictionary }
        let result = try await functions.httpsCallable("createBooking").call(params)
        guard let dict = result.data as? [String: Any],
              let bookingId = dict["bookingId"] as? String else {
            throw ServiceError.invalidResponse
        }
        return bookingId
    }

    func getBooking(id: String) async throws -> Booking {
        let snap = try await db.collection("bookings").document(id).getDocument()
        guard let booking = try? snap.data(as: Booking.self) else { throw ServiceError.notFound }
        return booking
    }

    func getPassengerBookings(passengerId: String) async throws -> [Booking] {
        let snap = try await db.collection("bookings")
            .whereField("passengerId", isEqualTo: passengerId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Booking.self) }
    }

    func getDriverBookings(driverId: String) async throws -> [Booking] {
        let snap = try await db.collection("bookings")
            .whereField("driverId", isEqualTo: driverId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Booking.self) }
    }

    func cancelBooking(id: String, reason: String?) async throws -> CancelResult {
        let params: [String: Any] = [
            "bookingId": id,
            "reason": reason ?? "إلغاء من قبل الراكب"
        ]
        let result = try await functions.httpsCallable("cancelBookingAndMaybeRefund").call(params)
        guard let dict = result.data as? [String: Any] else { throw ServiceError.invalidResponse }
        return CancelResult(
            bookingId: dict["bookingId"] as? String ?? id,
            refunded: dict["refunded"] as? Bool ?? false,
            refundId: dict["refundId"] as? String
        )
    }

    func createPaymentIntent(bookingId: String) async throws -> PaymentIntentResult {
        let result = try await functions.httpsCallable("createStripePaymentIntent")
            .call(["bookingId": bookingId])
        guard let dict = result.data as? [String: Any],
              let clientSecret = dict["clientSecret"] as? String,
              let piId = dict["paymentIntentId"] as? String,
              let amount = dict["amountHalalas"] as? Int else {
            throw ServiceError.invalidResponse
        }
        return PaymentIntentResult(
            clientSecret: clientSecret,
            paymentIntentId: piId,
            amountHalalas: amount
        )
    }

    func listenToBooking(id: String, onChange: @escaping (Booking) -> Void) -> ListenerRegistration {
        db.collection("bookings").document(id).addSnapshotListener { snap, _ in
            guard let snap, snap.exists,
                  let booking = try? snap.data(as: Booking.self) else { return }
            onChange(booking)
        }
    }
}

// ============================================================
// MARK: - FirebaseChatService
// ============================================================

final class FirebaseChatService: ChatServiceProtocol {

    func getConversations(userId: String) async throws -> [Conversation] {
        let snap = try await db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Conversation.self) }
    }

    func sendMessage(conversationId: String, text: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw ServiceError.unauthenticated }

        let convoRef = db.collection("conversations").document(conversationId)
        let msgRef = convoRef.collection("messages").document()

        let batch = db.batch()

        // Create message
        batch.setData([
            "senderId": uid,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "readBy": [uid]
        ], forDocument: msgRef)

        // Update conversation
        // Increment unread for other participant
        let convoSnap = try await convoRef.getDocument()
        if let convo = try? convoSnap.data(as: Conversation.self) {
            let otherUid = convo.otherParticipant(myUid: uid)
            batch.updateData([
                "lastMessage": text,
                "lastMessageAt": FieldValue.serverTimestamp(),
                "unreadCount.\(otherUid)": FieldValue.increment(Int64(1))
            ], forDocument: convoRef)
        }

        try await batch.commit()
    }

    func markAsRead(conversationId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("conversations").document(conversationId)
            .updateData(["unreadCount.\(uid)": 0])
    }

    func listenToMessages(conversationId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 200)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                let messages = docs.compactMap { try? $0.data(as: ChatMessage.self) }
                onChange(messages)
            }
    }

    func listenToConversations(userId: String, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                let convos = docs.compactMap { try? $0.data(as: Conversation.self) }
                onChange(convos)
            }
    }
}

// ============================================================
// MARK: - FirebaseRatingsService
// ============================================================

final class FirebaseRatingsService: RatingsServiceProtocol {

    func submitRating(bookingId: String, rating: Int, comment: String?) async throws -> String {
        var params: [String: Any] = [
            "bookingId": bookingId,
            "rating": rating
        ]
        if let comment, !comment.isEmpty { params["comment"] = comment }

        let result = try await functions.httpsCallable("submitRating").call(params)
        guard let dict = result.data as? [String: Any],
              let reviewId = dict["reviewId"] as? String else {
            throw ServiceError.invalidResponse
        }
        return reviewId
    }

    func getReviews(userId: String) async throws -> [Review] {
        let snap = try await db.collection("reviews")
            .whereField("revieweeId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Review.self) }
    }
}

// ============================================================
// MARK: - FirebaseCitiesService
// ============================================================

final class FirebaseCitiesService: CitiesServiceProtocol {
    private var cachedCities: [City] = []

    func loadCities() async throws -> [City] {
        if !cachedCities.isEmpty { return cachedCities }

        // Try bundle first (offline)
        let loader = await CitiesLoader.shared
        await loader.loadIfNeeded()
        let bundleCities = await loader.cities

        if !bundleCities.isEmpty {
            cachedCities = bundleCities
            return cachedCities
        }

        // Fallback to Firestore
        let snap = try await db.collection("cities").order(by: "nameAr").getDocuments()
        cachedCities = snap.documents.compactMap { try? $0.data(as: City.self) }
        return cachedCities
    }

    func searchCities(query: String) -> [City] {
        guard !query.isEmpty else { return cachedCities }
        return cachedCities.filter {
            $0.nameAr.localizedCaseInsensitiveContains(query) ||
            $0.nameEn.localizedCaseInsensitiveContains(query)
        }
    }
}

// ============================================================
// MARK: - FirebaseSupportLinksService
// ============================================================

final class FirebaseSupportLinksService: SupportLinksServiceProtocol {
    func whatsappURL(for region: SupportRegion) -> URL? {
        let phone: String
        let message = "مرحباً، أحتاج مساعدة في تطبيق رفيق"

        switch region {
        case .saudi: phone = KeysManager.whatsappSaudi
        case .yemen: phone = KeysManager.whatsappYemen
        }

        return DeepLinks.whatsappURL(phone: phone, message: message)
    }
}

// ============================================================
// MARK: - FirebaseNotificationsService
// ============================================================

final class FirebaseNotificationsService: NotificationsServiceProtocol {

    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return granted
    }

    func registerToken(_ token: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).updateData([
            "fcmToken": token,
            "lastActive": FieldValue.serverTimestamp()
        ])
    }
}

// ============================================================
// MARK: - ServiceError
// ============================================================

enum ServiceError: LocalizedError {
    case unauthenticated
    case notFound
    case invalidResponse
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated: return "يجب تسجيل الدخول"
        case .notFound: return "غير موجود"
        case .invalidResponse: return "استجابة غير صالحة من الخادم"
        case .unknown(let msg): return msg
        }
    }
}

// ============================================================
// MARK: - AppEnvironment + Live Configuration
// ============================================================

extension AppEnvironment {
    /// Production environment with real Firebase services
    static func production() -> AppEnvironment {
        AppEnvironment(
            auth: FirebaseAuthService(),
            trips: FirebaseTripsService(),
            bookings: FirebaseBookingService(),
            chat: FirebaseChatService(),
            ratings: FirebaseRatingsService(),
            cities: FirebaseCitiesService(),
            support: FirebaseSupportLinksService(),
            notifications: FirebaseNotificationsService()
        )
    }
}
