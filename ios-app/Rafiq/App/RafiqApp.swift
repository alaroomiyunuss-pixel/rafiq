// PATH: ios-app/Rafiq/App/
// FILENAME: RafiqApp.swift

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import StripePaymentSheet

@main
struct RafiqApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var environment = AppEnvironment.live()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(router)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_SA"))
                .onOpenURL { url in
                    DeepLinks.handle(url: url, router: router)
                }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter

    var body: some View {
        Group {
            if environment.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: environment.isLoggedIn)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var environment: AppEnvironment

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestinations()
            }
            .tabItem {
                Label("الرئيسية", systemImage: "house.fill")
            }
            .tag(AppRouter.Tab.home)

            NavigationStack(path: $router.bookingsPath) {
                MyBookingsView()
                    .navigationDestinations()
            }
            .tabItem {
                Label("حجوزاتي", systemImage: "ticket.fill")
            }
            .tag(AppRouter.Tab.bookings)

            NavigationStack(path: $router.chatPath) {
                ConversationsListView()
                    .navigationDestinations()
            }
            .tabItem {
                Label("المحادثات", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag(AppRouter.Tab.chat)

            NavigationStack(path: $router.profilePath) {
                ProfileView()
                    .navigationDestinations()
            }
            .tabItem {
                Label("حسابي", systemImage: "person.fill")
            }
            .tag(AppRouter.Tab.profile)
        }
        .tint(RafiqColors.primaryFallback)
    }
}

// MARK: - Navigation Destinations Modifier

struct NavigationDestinationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .tripDetail(let tripId):
                    TripDetailView(tripId: tripId)
                case .postTrip:
                    PostTripView()
                case .editTrip(let tripId):
                    EditTripView(tripId: tripId)
                case .bookingFlow(let tripId):
                    BookingFlowView(tripId: tripId)
                case .bookingDetail(let bookingId):
                    BookingDetailView(bookingId: bookingId)
                case .payment(let bookingId):
                    PaymentView(bookingId: bookingId)
                case .chat(let conversationId):
                    ChatView(conversationId: conversationId)
                case .driverDashboard:
                    DriverDashboardView()
                case .myTrips:
                    MyTripsView()
                case .editProfile:
                    EditProfileView()
                case .vehicles:
                    VehiclesListView()
                case .addVehicle:
                    AddVehicleView()
                case .rating(let bookingId):
                    RatingView(bookingId: bookingId)
                case .reviews(let userId):
                    ReviewsListView(userId: userId)
                case .support:
                    SupportView()
                }
            }
    }
}

extension View {
    func navigationDestinations() -> some View {
        modifier(NavigationDestinationsModifier())
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Stripe
        StripeAPI.defaultPublishableKey = KeysManager.stripePublishableKey

        // Push notifications
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: FCM Token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task {
            // Store token — will be picked up by NotificationsService
            UserDefaults.standard.set(token, forKey: "fcmToken")
        }
    }

    // MARK: APNs Token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: Foreground Notification

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: Notification Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        DeepLinks.handlePushPayload(userInfo)
        completionHandler()
    }
}

// MARK: - Keys Manager

enum KeysManager {
    private static var keys: NSDictionary? = {
        guard let path = Bundle.main.path(forResource: "Keys", ofType: "plist") else { return nil }
        return NSDictionary(contentsOfFile: path)
    }()

    static var stripePublishableKey: String {
        keys?["STRIPE_PUBLISHABLE_KEY"] as? String ?? ""
    }

    static var googleMapsAPIKey: String {
        keys?["GOOGLE_MAPS_API_KEY"] as? String ?? ""
    }

    static var stripeMerchantId: String {
        keys?["STRIPE_MERCHANT_ID"] as? String ?? "merchant.com.rafiq.app"
    }

    static var whatsappSaudi: String {
        keys?["WHATSAPP_SUPPORT_SA"] as? String ?? ""
    }

    static var whatsappYemen: String {
        keys?["WHATSAPP_SUPPORT_YE"] as? String ?? ""
    }
}

// ============================================================
// MARK: - Placeholder Views (compile stubs — replaced later)
// ============================================================

struct HomeView: View { var body: some View { Text("الرئيسية").font(RafiqFonts.heading1()) } }
struct LoginView: View { var body: some View { Text("تسجيل الدخول").font(RafiqFonts.heading1()) } }
struct MyBookingsView: View { var body: some View { Text("حجوزاتي").font(RafiqFonts.heading1()) } }
struct ConversationsListView: View { var body: some View { Text("المحادثات").font(RafiqFonts.heading1()) } }
struct ProfileView: View { var body: some View { Text("حسابي").font(RafiqFonts.heading1()) } }
struct TripDetailView: View { let tripId: String; var body: some View { Text("تفاصيل الرحلة") } }
struct PostTripView: View { var body: some View { Text("إنشاء رحلة") } }
struct EditTripView: View { let tripId: String; var body: some View { Text("تعديل الرحلة") } }
struct BookingFlowView: View { let tripId: String; var body: some View { Text("حجز") } }
struct BookingDetailView: View { let bookingId: String; var body: some View { Text("تفاصيل الحجز") } }
struct PaymentView: View { let bookingId: String; var body: some View { Text("الدفع") } }
struct ChatView: View { let conversationId: String; var body: some View { Text("محادثة") } }
struct DriverDashboardView: View { var body: some View { Text("لوحة السائق") } }
struct MyTripsView: View { var body: some View { Text("رحلاتي") } }
struct EditProfileView: View { var body: some View { Text("تعديل الملف") } }
struct VehiclesListView: View { var body: some View { Text("مركباتي") } }
struct AddVehicleView: View { var body: some View { Text("إضافة مركبة") } }
struct RatingView: View { let bookingId: String; var body: some View { Text("تقييم") } }
struct ReviewsListView: View { let userId: String; var body: some View { Text("التقييمات") } }
struct SupportView: View { var body: some View { Text("الدعم") } }
