# رفيق (Rafiq) — Architecture v1.0

> PATH: docs/
> FILENAME: 02_ARCHITECTURE.md

---

## Block 1: iOS Layers/Modules

```
RafiqApp (Entry)
    |
    +-- Presentation Layer (Views/)
    |     SwiftUI screens grouped by feature
    |     RTL layout, Arabic strings via Localizable
    |
    +-- State Layer (ViewModels/)
    |     @Observable classes, one per feature
    |     Owns business logic + validation
    |     Calls Services, never Firestore directly
    |
    +-- Service Layer (Services/)
    |     AuthService      - Firebase Auth (phone OTP)
    |     TripService      - CRUD + seat transactions
    |     BookingService   - Lifecycle + cancel logic
    |     PaymentService   - Stripe SDK + Apple Pay
    |     ChatService      - Realtime listener
    |     LocationService  - Google Maps SDK
    |     PushService      - FCM token registration
    |     FirestoreService - Generic Codable wrapper
    |
    +-- Data Layer (Models/)
    |     Codable structs matching Firestore docs
    |     All monetary fields: Int (halalas)
    |
    +-- Resources/
          Assets, Fonts, Localizable.xcstrings
```

Dependencies: FirebaseAuth, FirebaseFirestore, FirebaseMessaging, StripePaymentSheet, GoogleMaps

---

## Block 2: Firebase Services Used

| Service | Purpose |
|---------|---------|
| Authentication | Phone OTP sign-in (+966) |
| Firestore | Primary database (all collections) |
| Cloud Functions | Server logic, Stripe webhooks, scheduled jobs |
| Cloud Messaging (FCM) | Push notifications |
| Cloud Storage | Profile photos, vehicle photos |
| Remote Config | Feature flags, platform fee %, WhatsApp numbers |

Region: me-central1 (Dammam) for Functions + Firestore

---

## Block 3: Firestore Collections

### MVP Collections

```
users/{uid}
  - name, phone, photoURL, role (passenger|driver|both)
  - avgRating, totalRatings, createdAt
  - fcmToken, lastActive
  - HOOK: verificationStatus, companyId

users/{uid}/vehicles/{vehicleId}
  - make, model, year, color, plateNumber, photoURL, seats

cities/{cityId}
  - nameAr, nameEn, lat, lng, isActive
  - HOOK: country

trips/{tripId}
  - driverId, originCityId, destCityId
  - dateTime, totalSeats, availableSeats
  - pricePerSeatHalalas, meetingMode
  - meetingPoint {lat, lng, address}
  - vehicleId, notes, status
  - createdAt, updatedAt
  - HOOK: companyId, recurringId

bookings/{bookingId}
  - tripId, passengerId, driverId
  - seatCount, totalAmountHalalas
  - paymentIntentId, paymentStatus
  - status, cancelledBy, cancelReason
  - createdAt, confirmedAt, expiresAt
  - HOOK: promoCodeId, refundId

bookings/{bookingId}/messages/{messageId}
  - senderId, text, timestamp, readBy
  - HOOK: messageType, mediaURL

reviews/{reviewId}
  - tripId, bookingId, reviewerId, revieweeId
  - rating (1-5), comment, createdAt
  - type (passenger_to_driver | driver_to_passenger)
```

### Reserved Collections (Post-MVP)

```
companies/{companyId}         - Fleet company profiles
adminUsers/{uid}              - Admin accounts + permissions
supportTickets/{ticketId}     - In-app ticketing
promoCodes/{codeId}           - Discount codes
notifications/{notifId}       - In-app inbox
verifications/{verifId}       - Driver ID/license review
```

### Config (Single Doc)

```
config/app
  - platformFeePercent: 10
  - minPriceHalalas: 1000
  - paymentExpiryMinutes: 180
  - ratingWindowMinutes: 120
  - whatsappSaudi: "+966..."
  - whatsappYemen: "+967..."
  - minTripLeadTimeHours: 4
```

---

## Block 4: Stripe Payment Flow

```
CLIENT (iOS)                    FUNCTIONS                     STRIPE
    |                               |                            |
    |-- 1. Book trip -------------->|                            |
    |                               |-- 2. Create PaymentIntent->|
    |                               |<--- clientSecret ----------|
    |<-- 3. Return clientSecret ----|                            |
    |                               |                            |
    |-- 4. PaymentSheet.present --->|                            |
    |   (Card or Apple Pay)         |                            |
    |                               |                            |
    |                               |<-- 5. Webhook: succeeded --|
    |                               |   - Update booking.status  |
    |                               |   - Decrement seats (txn)  |
    |                               |   - Send push to both      |
    |<-- 6. Push: confirmed --------|                            |
    |                               |                            |
    === CANCEL FLOW ===             |                            |
    |-- Cancel request ------------>|                            |
    |                               |-- Check 24h rule           |
    |                               |-- If refundable: Refund -->|
    |                               |   - Restore seats (txn)    |
    |                               |   - Send push              |
    |<-- Push: cancelled -----------|                            |
```

Key rules:
- Client NEVER calls Stripe directly (except PaymentSheet)
- All booking mutations happen in Cloud Functions
- Seat changes ONLY via Firestore transactions
- PaymentIntent metadata: {bookingId, tripId, passengerId}

---

## Block 5: Scheduled Jobs (Cloud Functions)

| Job | Schedule | Action |
|-----|----------|--------|
| expirePendingPayments | Every 15 min | Find pending_payment bookings where expiresAt < now, set status=expired |
| autoCompleteTrips | Every 30 min | Find in_progress trips where dateTime + 6h < now, set status=completed |
| sendRatingReminders | Every 15 min | Find completed trips without reviews within 2h window, send push |
| closeRatingWindow | Every 30 min | Find completed trips where endTime + 2h < now, lock rating |

All functions deployed to me-central1. Pub/Sub scheduler.

---

## Block 6: Expansion Hooks

| Hook | Where | Purpose |
|------|-------|---------|
| companyId | users, trips | Link driver to fleet company |
| verificationStatus | users | Driver ID/license approval flow |
| country | cities | Multi-country expansion (Yemen, UAE) |
| recurringId | trips | Recurring trip templates |
| promoCodeId | bookings | Discount code application |
| messageType | messages | Media messages (photo, voice, location) |
| refundId | bookings | Detailed refund tracking |
| liveLocation | trips | Real-time driver tracking |
| supportTicketId | bookings | Link booking to support case |
| notificationInbox | users | In-app notification history |

All hooks are nullable fields in MVP schema. No logic, no UI, just reserved in Firestore structure.
