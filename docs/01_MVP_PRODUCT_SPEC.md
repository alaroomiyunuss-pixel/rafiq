# رفيق (Rafiq) — MVP Product Spec v1.0

> PATH: docs/  
> FILENAME: 01_MVP_PRODUCT_SPEC.md

---

## 1. Overview

Rafiq is a ride-sharing app for the Saudi/Gulf market. Drivers post scheduled trips between cities; passengers search, book, and pay electronically.

**Platform:** iOS (SwiftUI) | **Region:** Saudi Arabia | **Currency:** SAR (stored as halalas, 1 SAR = 100)

---

## 2. Roles

| Role | MVP | Description |
|------|-----|-------------|
| passenger | YES | Search, book, pay, rate |
| driver | YES | Post trips, manage bookings, rate |
| company | Schema only | Fleet management (deferred) |
| admin | Schema only | Dashboard control (deferred) |

User can be both passenger AND driver (role toggle).

---

## 3. Auth

- Phone number OTP via Firebase Auth
- Saudi numbers (+966) required in MVP
- Profile: name, phone, photo, role, createdAt

---

## 4. Cities

- Fixed searchable list (50+ Saudi cities)
- No manual text entry
- Stored as cityId + nameAr + nameEn + lat/lng
- Scalability hook: country field for future expansion

---

## 5. Trips

Driver creates trip with:
- Origin city, destination city
- Date + time (future only, min 4h from now)
- Available seats (1-7)
- Price per seat (in halalas, min 1000 = 10 SAR)
- Vehicle selection (from driver vehicles)
- Meeting mode (see S8)
- Notes (optional, 200 char max)

Edit/Delete constraints:
- No edit if tripDate - now < 24h
- No edit after first confirmed booking
- Delete allowed if zero confirmed bookings
- Trip auto-closes when availableSeats == 0

Trip statuses: open > full > in_progress > completed > cancelled

---

## 6. Bookings

Flow: Search > Select trip > Choose seats (1-max) > Pay > Confirmed

Payment: Stripe only (Cards + Apple Pay). No cash. No Google Pay.

Booking statuses: pending_payment > confirmed > completed > cancelled > expired

Expiry rule: pending_payment expires after 3 hours > auto-cancel via Cloud Function.

Cancel policy:
- Cancel > 24h before trip = Full refund
- Cancel <= 24h before trip = No refund
- No-show = No refund

Refunds processed via Stripe Refund API.

---

## 7. Payments

- Stripe PaymentIntent per booking
- Apple Pay via Stripe
- Amount = pricePerSeat x seatCount (in halalas)
- Platform fee: configurable % (stored in Firestore config)
- Stripe Connect for driver payouts (scalability hook)
- Webhook: payment_intent.succeeded > confirm booking

---

## 8. Meeting Modes

| Mode | Description |
|------|-------------|
| MAP_PIN | Driver sets pin on Google Maps; passenger navigates to it |
| MANUAL_ADDRESS | Driver types address text |
| DRIVER_PICKS_UP | Passenger sets pin; driver comes to them |

Stored per-trip. Coordinates saved as GeoPoint.

---

## 9. Chat

- Realtime in-app messaging (Firestore subcollection)
- 1-to-1: passenger to driver per booking
- Text only in MVP
- Unread count badge
- Scalability hook: messageType field for future media

---

## 10. Ratings

- Both sides rate after trip
- Scale: 1-5 stars + optional comment (200 char)
- Window: 2 hours after trip.endTime
- Push reminder at trip completion
- Email reminder: placeholder (deferred)
- Rating locked after window expires

---

## 11. Notifications (Push Only)

| Event | Recipient |
|-------|-----------|
| Booking confirmed | Passenger + Driver |
| Booking cancelled | Passenger + Driver |
| New chat message | Other party |
| Rating reminder | Both (at trip end) |
| Payment expired | Passenger |

Via FCM. No in-app inbox in MVP.

---

## 12. Support

- WhatsApp deep link only
- Two numbers: Saudi support + Yemen support
- Accessible from profile screen
- Scalability hook: supportType field for future ticket system

---

## 13. Maps

- Google Maps SDK for iOS
- Route preview on trip detail
- Pin selection for meeting point
- Geocoding: coordinates to address
- No live tracking in MVP (scalability hook: liveLocation field)

---

## 14. Deferred (Post-MVP)

| Feature | Notes |
|---------|-------|
| Company role | Fleet management, bulk trips |
| Admin panel | Next.js dashboard |
| In-app ticketing | Replace WhatsApp support |
| Twilio calls | Masked phone calls |
| In-app notification inbox | Persistent notification history |
| Driver verification | ID + license upload + review |
| Promo codes | Discount system |
| Google Pay | Android expansion |
| Live tracking | Real-time driver location |
| Email notifications | Transactional emails |
| Multi-country | Yemen, UAE, etc. |
| Cash payments | Dual-confirm flow |
