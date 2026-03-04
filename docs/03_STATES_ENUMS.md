# رفيق (Rafiq) — Enums and State Machines v1.0

> PATH: docs/
> FILENAME: 03_STATES_ENUMS.md

---

## 1. Role

```
passenger   ← MVP (default on signup)
driver      ← MVP (user enables via profile)
both        ← MVP (user has both active)
company     ← RESERVED (fleet operator)
admin       ← RESERVED (dashboard access)
```

Transitions:
- passenger -> both (user adds vehicle + enables driver mode)
- both -> passenger (user disables driver mode)
- No direct passenger -> driver (always goes through both)
- company/admin assigned via backend only (post-MVP)

---

## 2. TripStatus

```
        +--------+
        |  open  |  ← Driver creates trip
        +--------+
         /   |   \
        v    |    v
   +------+  |  +-----------+
   | full |  |  | cancelled |  ← Driver cancels (0 confirmed bookings)
   +------+  |  +-----------+
        \    |
         v   v
   +-------------+
   | in_progress |  ← tripDateTime reached (auto or manual)
   +-------------+
         |
         v
   +-----------+
   | completed |  ← auto after tripDateTime + 6h
   +-----------+
```

| From | To | Actor | Condition | Timestamp |
|------|----|-------|-----------|-----------|
| - | open | driver | Creates trip (min 4h future) | createdAt |
| open | full | system | availableSeats == 0 | updatedAt |
| full | open | system | Booking cancelled, seats restored | updatedAt |
| open | cancelled | driver | Zero confirmed bookings | cancelledAt |
| open/full | in_progress | scheduled fn | now >= tripDateTime | startedAt |
| in_progress | completed | scheduled fn | now >= tripDateTime + 6h | completedAt |

Reserved transitions (post-MVP):
- open -> suspended (admin action)
- suspended -> open (admin action)

---

## 3. BookingStatus

```
   +-----------------+
   | pending_payment |  ← Passenger initiates booking
   +-----------------+
      /      |       \
     v       v        v
+--------+ +-------+ +---------+
|confirmed| |expired| |cancelled|
+--------+ +-------+ +---------+
     |                     ^
     v                     |
+-----------+              |
| completed |              |
+-----------+         (cancel rules)
     |
     v
  +---------+
  | no_show |  ← RESERVED
  +---------+
```

| From | To | Actor | Condition | Timestamp |
|------|----|-------|-----------|-----------|
| - | pending_payment | passenger | Selects seats, PaymentIntent created | createdAt, expiresAt = now+3h |
| pending_payment | confirmed | webhook | payment_intent.succeeded | confirmedAt |
| pending_payment | expired | scheduled fn | now > expiresAt (3h) | expiredAt |
| pending_payment | cancelled | passenger | Cancels before paying | cancelledAt |
| confirmed | cancelled | passenger | > 24h before trip = refund | cancelledAt, refundedAt |
| confirmed | cancelled | passenger | <= 24h before trip = no refund | cancelledAt |
| confirmed | completed | system | Trip status -> completed | completedAt |
| confirmed | no_show | RESERVED | Driver marks no-show (post-MVP) | noShowAt |

Cancel refund matrix:
- tripDateTime - now > 24h: full Stripe refund
- tripDateTime - now <= 24h: no refund, amount kept
- no_show: no refund (reserved)

---

## 4. PaymentStatus

```
   +--------+
   | unpaid |  ← PaymentIntent created
   +--------+
    /   |    \
   v    v     v
+----+ +------+ +-------+
|paid| |failed| |expired|
+----+ +------+ +-------+
  |
  v
+----------+     +----------------+
| refunded | or  | partial_refund |  ← RESERVED
+----------+     +----------------+
```

| From | To | Actor | Condition | Timestamp |
|------|----|-------|-----------|-----------|
| - | unpaid | cloud fn | PaymentIntent created | paymentCreatedAt |
| unpaid | paid | webhook | payment_intent.succeeded | paidAt |
| unpaid | failed | webhook | payment_intent.payment_failed | failedAt |
| unpaid | expired | scheduled fn | 3h timeout | expiredAt |
| paid | refunded | cloud fn | Cancel > 24h, Stripe refund issued | refundedAt |
| paid | partial_refund | RESERVED | Post-MVP partial refund logic | refundedAt |

---

## 5. RatingWindowStatus

```
   +--------+
   | closed |  ← Trip not yet completed
   +--------+
       |
       v  (trip.status -> completed)
   +------+
   | open |  ← 2h window starts
   +------+
    /     \
   v       v
+-------+ +---------+
| rated | | expired |
+-------+ +---------+
```

| From | To | Actor | Condition | Timestamp |
|------|----|-------|-----------|-----------|
| closed | open | system | trip.status = completed | windowOpensAt = trip.completedAt |
| open | rated | user | Submits rating within 2h | ratedAt |
| open | expired | scheduled fn | now > windowOpensAt + 2h | windowClosedAt |

Push notification sent at: closed -> open transition
No re-rating. One review per side per booking.

---

## 6. MeetingMode

```
MAP_PIN          ← Driver drops pin on map. Passenger navigates to it.
MANUAL_ADDRESS   ← Driver types text address. Shown to passenger as-is.
DRIVER_PICKS_UP  ← Passenger drops pin on map. Driver navigates to it.
```

| Mode | Pin setter | Coordinates stored | Address stored |
|------|------------|-------------------|----------------|
| MAP_PIN | driver | lat, lng (required) | reverse-geocoded (auto) |
| MANUAL_ADDRESS | driver | optional | text (required) |
| DRIVER_PICKS_UP | passenger | lat, lng (required) | reverse-geocoded (auto) |

Stored on trip document as meetingMode + meetingPoint {lat, lng, address}.
For DRIVER_PICKS_UP, passenger sets point during booking flow (stored on booking).

---

## 7. VehicleType

```
MVP:
  car        ← Standard car (1-7 seats)

RESERVED:
  bus        ← Company bus (post-MVP)
  van        ← Large vehicle (post-MVP)
```

| Type | Seat range | Available | Requires |
|------|-----------|-----------|----------|
| car | 1-7 | MVP | driver role |
| bus | 8-50 | RESERVED | company role |
| van | 1-15 | RESERVED | driver or company role |

Vehicle fields: make, model, year, color, plateNumber, type, maxSeats, photoURL, isActive
