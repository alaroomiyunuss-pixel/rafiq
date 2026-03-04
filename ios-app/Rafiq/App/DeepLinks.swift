// PATH: ios-app/Rafiq/App/
// FILENAME: DeepLinks.swift

import Foundation

// ============================================================
// رفيق (Rafiq) — Deep Link Handler
//
// URL Scheme: rafiq://
// Supported paths:
//   rafiq://trip/{tripId}
//   rafiq://booking/{bookingId}
//   rafiq://chat/{conversationId}
//   rafiq://rate/{bookingId}
//   rafiq://support
//
// Push notification payload keys:
//   type: booking_confirmed | booking_cancelled | new_message
//         | rating_reminder | payment_expired | payment_failed
//   tripId, bookingId, conversationId
// ============================================================

enum DeepLinks {

    // MARK: - URL Scheme Handler

    static func handle(url: URL, router: AppRouter) {
        guard url.scheme == "rafiq" else { return }

        let host = url.host ?? ""
        let pathId = url.pathComponents.count > 1 ? url.pathComponents[1] : nil

        switch host {
        case "trip":
            if let tripId = pathId {
                router.showTripDetail(tripId)
            }

        case "booking":
            if let bookingId = pathId {
                router.showBookingDetail(bookingId)
            }

        case "chat":
            if let conversationId = pathId {
                router.showChat(conversationId)
            }

        case "rate":
            if let bookingId = pathId {
                router.showRating(bookingId)
            }

        case "support":
            router.showSupport()

        case "post-trip":
            router.showPostTrip()

        default:
            break
        }
    }

    // MARK: - Push Notification Payload Handler

    static func handlePushPayload(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        // Router accessed via notification — deferred to next run loop
        // so the app has time to set up the environment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let router = Self.activeRouter else { return }
            routePush(type: type, userInfo: userInfo, router: router)
        }
    }

    // MARK: - Route Push by Type

    private static func routePush(type: String, userInfo: [AnyHashable: Any], router: AppRouter) {
        switch type {
        case "booking_confirmed", "booking_cancelled", "payment_expired", "payment_failed":
            if let bookingId = userInfo["bookingId"] as? String {
                router.showBookingDetail(bookingId)
            }

        case "new_message":
            if let conversationId = userInfo["conversationId"] as? String {
                router.showChat(conversationId)
            }

        case "rating_reminder":
            if let bookingId = userInfo["bookingId"] as? String {
                router.showRating(bookingId)
            }

        default:
            break
        }
    }

    // MARK: - Active Router Reference

    // Set by RootView on appear; used by push handler
    @MainActor
    static weak var activeRouter: AppRouter?

    // MARK: - URL Builders (for sharing)

    static func tripURL(tripId: String) -> URL? {
        URL(string: "rafiq://trip/\(tripId)")
    }

    static func bookingURL(bookingId: String) -> URL? {
        URL(string: "rafiq://booking/\(bookingId)")
    }

    static func chatURL(conversationId: String) -> URL? {
        URL(string: "rafiq://chat/\(conversationId)")
    }

    // MARK: - WhatsApp Support URLs

    static func whatsappURL(phone: String, message: String = "") -> URL? {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let cleanPhone = phone.replacingOccurrences(of: "+", with: "")
        return URL(string: "https://wa.me/\(cleanPhone)?text=\(encoded)")
    }

    static func saudiSupportURL() -> URL? {
        whatsappURL(
            phone: KeysManager.whatsappSaudi,
            message: "مرحباً، أحتاج مساعدة في تطبيق رفيق"
        )
    }

    static func yemenSupportURL() -> URL? {
        whatsappURL(
            phone: KeysManager.whatsappYemen,
            message: "مرحباً، أحتاج مساعدة في تطبيق رفيق"
        )
    }
}
