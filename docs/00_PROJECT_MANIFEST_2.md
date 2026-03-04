# رفيق — Project Manifest (Lightweight MVP)

> PATH: docs/
> FILENAME: 00_PROJECT_MANIFEST.md

---

## ios-app/

### Sources/App/
| File | Description |
|------|-------------|
| `RafiqApp.swift` | Entry point, Firebase init, environment setup |
| `AppDelegate.swift` | FCM registration, push token handling |

### Sources/Models/
| File | Description |
|------|-------------|
| `User.swift` | Codable user model (passenger + driver roles) |
| `Trip.swift` | Trip model: route, date, seats, price in halalas |
| `Booking.swift` | Booking model: status, payment method, timestamps |
| `Vehicle.swift` | Vehicle info linked to driver |
| `Review.swift` | Rating model (1-5 stars, 2hr window rule) |

### Sources/Services/
| File | Description |
|------|-------------|
| `AuthService.swift` | Firebase Auth (phone OTP) |
| `FirestoreService.swift` | Generic Firestore CRUD wrapper |
| `TripService.swift` | Trip search, create, seat transactions |
| `BookingService.swift` | Booking lifecycle + cash dual-confirm |
| `PaymentService.swift` | Stripe + Apple Pay integration |
| `LocationService.swift` | Google Maps geocoding + route |
| `PushService.swift` | FCM token management |

### Sources/ViewModels/
| File | Description |
|------|-------------|
| `AuthViewModel.swift` | Login/register/OTP state |
| `HomeViewModel.swift` | Trip search + filter logic |
| `TripViewModel.swift` | Post trip + trip detail state |
| `BookingViewModel.swift` | Booking flow + payment state |
| `ProfileViewModel.swift` | Profile view/edit state |
| `DriverViewModel.swift` | Driver dashboard state |

### Sources/Views/
| Folder | Files | Description |
|--------|-------|-------------|
| `Auth/` | `LoginView`, `OTPView`, `RegisterView` | Authentication screens |
| `Home/` | `HomeView`, `SearchView`, `TripCardView` | Main feed + search |
| `Trip/` | `TripDetailView`, `PostTripView` | Trip details + driver posting |
| `Booking/` | `BookingView`, `PaymentView`, `ConfirmationView` | Booking + pay flow |
| `Profile/` | `ProfileView`, `EditProfileView` | User profile |
| `Driver/` | `DriverDashboardView`, `MyTripsView` | Driver management |
| `Shared/` | `LoadingView`, `ErrorView`, `ArabicTextField`, `PriceLabel` | Reusable components |

### Sources/Resources/
| File | Description |
|------|-------------|
| `Assets.xcassets` | App icons, colors, images |
| `Localizable.xcstrings` | Arabic UI strings |
| `GoogleService-Info.plist` | Firebase config (gitignored) |

---

## functions/

| File | Description |
|------|-------------|
| `package.json` | Dependencies: firebase-functions, stripe, admin SDK |
| `tsconfig.json` | TypeScript config (Node 18, strict) |
| `src/index.ts` | Exports all function groups |
| `src/trips.ts` | onCreate, onUpdate, search index |
| `src/bookings.ts` | Booking create, cash dual-confirm, expire after 24h |
| `src/payments.ts` | Stripe PaymentIntent, webhook, refunds |
| `src/notifications.ts` | FCM triggers on booking/trip events |
| `src/users.ts` | Auth onCreate trigger, profile sync |
| `src/utils/constants.ts` | Shared constants (halalas, timeouts) |
| `src/utils/validators.ts` | Input validation helpers |

> **Region:** `me-central1` (Dammam)
> **Runtime:** Node.js 18, TypeScript

---

## docs/

| File | Description |
|------|-------------|
| `00_PROJECT_MANIFEST.md` | This file — full tree + descriptions |
| `01_FIRESTORE_SCHEMA.md` | Collections, documents, field types, indexes |
| `02_DOMAIN_RULES.md` | Business logic (halalas, cash confirm, rating window) |
| `03_SETUP_FIREBASE.md` | Firebase project setup + deploy steps |
| `04_SETUP_STRIPE.md` | Stripe account, keys, Apple Pay config |
| `05_SETUP_MAPS.md` | Google Maps SDK + API key setup |
| `06_SETUP_PUSH.md` | APNs cert + FCM configuration |
| `07_HANDOFF_CHECKLIST.md` | Go-live checklist for App Store submission |
