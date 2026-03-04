PATH: docs/
FILENAME: 04_FIRESTORE_SCHEMA.md

# رفيق (Rafiq) — Firestore Schema v1.1 (MVP + Manual Ledger)

> هذا الإصدار: MVP خفيف
> - الدفع: Stripe (Cards + Apple Pay)
> - لا يوجد Stripe Connect ولا تحويل تلقائي للسائق
> - التحويل للسائق: **يدوي خارج التطبيق**
> - داخل التطبيق: **Wallet + Ledger** لعرض الأرباح/المعلّق/المتاح وتاريخ الحركات

---

## Collection: `users/{uid}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | YES | Display name |
| phone | string | YES | +966XXXXXXXXX |
| photoURL | string | NO | Cloud Storage path |
| role | string | YES | passenger / driver / both |
| avgRating | number | YES | 0.0 default |
| totalRatings | number | YES | 0 default |
| fcmToken | string | NO | Push token |
| lastActive | timestamp | YES | Auto-updated |
| createdAt | timestamp | YES | On signup |
| verificationStatus | string | NO | RESERVED: pending/approved/rejected |
| companyId | string | NO | RESERVED: fleet link |

### Subcollection: `users/{uid}/vehicles/{vehicleId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| make | string | YES | e.g. Toyota |
| model | string | YES | e.g. Camry |
| year | number | YES | e.g. 2023 |
| color | string | YES | Arabic color name |
| plateNumber | string | YES | Saudi plate |
| photoURL | string | NO | Vehicle photo |
| type | string | YES | car (RESERVED: bus, van) |
| maxSeats | number | YES | 1-7 for car |
| isActive | boolean | YES | true default |
| createdAt | timestamp | YES | |

Example:
```json
{
  "make": "Toyota",
  "model": "كامري",
  "year": 2023,
  "color": "أبيض",
  "plateNumber": "أ ب ج 1234",
  "type": "car",
  "maxSeats": 4,
  "isActive": true
}

Subcollection: users/{uid}/finance/wallet (Doc ID: wallet)

هذه هي "محفظة داخلية" للعرض والمحاسبة فقط.
ليست تحويل تلقائي. السحب/التحويل الحقيقي يتم خارج التطبيق (بنكي/حوالة) ثم لاحقاً يمكن تسجيله كنظام Admin.

Field	Type	Required	Description
currency	string	YES	Always "SAR"
availableBalanceHalalas	number	YES	Available to withdraw (after trip completed)
pendingBalanceHalalas	number	YES	Pending (paid but not completed yet)
lifetimeEarnedHalalas	number	YES	Total earned over time
lifetimeWithdrawnHalalas	number	YES	RESERVED (if you record payouts later)
updatedAt	timestamp	YES	Auto-updated
createdAt	timestamp	YES	

Example:

{
  "currency": "SAR",
  "availableBalanceHalalas": 120000,
  "pendingBalanceHalalas": 35000,
  "lifetimeEarnedHalalas": 250000,
  "lifetimeWithdrawnHalalas": 90000,
  "createdAt": "TIMESTAMP",
  "updatedAt": "TIMESTAMP"
}
Subcollection: users/{uid}/financeLedger/{entryId}

Ledger = سجل حركات يشرح كيف تغيّر الرصيد.
يفيد لمعرفة: كم ربح، كم صار معلّق، كم صار متاح، ومتى تم خصم بسبب Refund.

Field	Type	Required	Description
type	string	YES	earning_pending / earning_released / refund_reversal (RESERVED: payout_recorded, adjustment)
status	string	YES	pending / posted
amountHalalas	number	YES	Amount in halalas
currency	string	YES	"SAR"
driverId	string	YES	Driver uid
tripId	string	NO	Trip ref
bookingId	string	NO	Booking ref
passengerId	string	NO	Passenger uid
note	string	NO	Optional note
createdAt	timestamp	YES	

Example:

{
  "type": "earning_pending",
  "status": "pending",
  "amountHalalas": 45000,
  "currency": "SAR",
  "driverId": "uid_driver",
  "tripId": "trip_001",
  "bookingId": "book_001",
  "passengerId": "uid_pass",
  "createdAt": "TIMESTAMP"
}
Collection: trips/{tripId}
Field	Type	Required	Description
driverId	string	YES	uid ref
driverName	string	YES	Denormalized for list display
driverPhoto	string	NO	Denormalized
driverRating	number	YES	Denormalized
originCityId	string	YES	From sa_cities.json
originNameAr	string	YES	Denormalized
destCityId	string	YES	From sa_cities.json
destNameAr	string	YES	Denormalized
dateTime	timestamp	YES	Trip departure time
totalSeats	number	YES	From vehicle
availableSeats	number	YES	Decremented via transaction
pricePerSeatHalalas	number	YES	Min 1000 (10 SAR)
vehicleId	string	YES	Ref to driver vehicle
vehicleSummary	string	YES	Denormalized "Toyota كامري 2023"
meetingMode	string	YES	MAP_PIN / MANUAL_ADDRESS / DRIVER_PICKS_UP
meetingPoint	map	NO	{lat: number, lng: number, address: string}
manualAddressText	string	NO	For MANUAL_ADDRESS
driverPicksUp	boolean	NO	For DRIVER_PICKS_UP
notes	string	NO	Max 200 chars
status	string	YES	open/full/in_progress/completed/cancelled/deleted
confirmedBookings	number	YES	Count, for edit/delete guard
createdAt	timestamp	YES	
updatedAt	timestamp	YES	
cancelledAt	timestamp	NO	
startedAt	timestamp	NO	
completedAt	timestamp	NO	
deletedAt	timestamp	NO	

Example:

{
  "driverId": "uid_abc",
  "driverName": "أحمد",
  "originCityId": "riyadh",
  "originNameAr": "الرياض",
  "destCityId": "jeddah",
  "destNameAr": "جدة",
  "dateTime": "2026-04-10T06:00:00Z",
  "totalSeats": 3,
  "availableSeats": 2,
  "pricePerSeatHalalas": 15000,
  "vehicleId": "v_001",
  "vehicleSummary": "Toyota كامري 2023 أبيض",
  "meetingMode": "MAP_PIN",
  "meetingPoint": {"lat": 24.7136, "lng": 46.6753, "address": "حي العليا، الرياض"},
  "notes": "رحلة مباشرة بدون توقف",
  "status": "open",
  "confirmedBookings": 1
}
Collection: bookings/{bookingId}

ملاحظة: يوجد "قيمة للسائق" driverNetHalalas تُستخدم للـLedger.

Field	Type	Required	Description
tripId	string	YES	Ref
passengerId	string	YES	uid
passengerName	string	YES	Denormalized
driverId	string	YES	uid (from trip)
seatCount	number	YES	1 to availableSeats
totalAmountHalalas	number	YES	pricePerSeat x seatCount
platformFeeHalalas	number	YES	Calculated at creation
driverNetHalalas	number	NO	Set on payment success (total - fee)
paymentIntentId	string	NO	Stripe PI id
paymentStatus	string	YES	unpaid/paid/failed/expired/refunded
paymentMethod	string	YES	stripe (RESERVED: cash)
status	string	YES	pending_payment/confirmed/completed/cancelled/expired/no_show
cancelledBy	string	NO	passenger / driver / system
cancelReason	string	NO	Optional text
pickupPoint	map	NO	For DRIVER_PICKS_UP: {lat, lng, address}
createdAt	timestamp	YES	
expiresAt	timestamp	YES	createdAt + 3h
confirmedAt	timestamp	NO	
completedAt	timestamp	NO	
cancelledAt	timestamp	NO	
refundedAt	timestamp	NO	
promoCodeId	string	NO	RESERVED
refundId	string	NO	RESERVED

Example:

{
  "tripId": "trip_001",
  "passengerId": "uid_xyz",
  "passengerName": "محمد",
  "driverId": "uid_abc",
  "seatCount": 1,
  "totalAmountHalalas": 15000,
  "platformFeeHalalas": 1500,
  "driverNetHalalas": 13500,
  "paymentIntentId": "pi_abc123",
  "paymentMethod": "stripe",
  "paymentStatus": "paid",
  "status": "confirmed",
  "createdAt": "2026-04-08T10:00:00Z",
  "expiresAt": "2026-04-08T13:00:00Z",
  "confirmedAt": "2026-04-08T10:02:30Z"
}
Collection: conversations/{conversationId}
Field	Type	Required	Description
bookingId	string	YES	1:1 with booking
tripId	string	YES	For queries
participants	array[string]	YES	[passengerId, driverId]
lastMessage	string	NO	Preview text
lastMessageAt	timestamp	NO	For sorting
unreadCount	map	YES	{uid1: number, uid2: number}
createdAt	timestamp	YES	

Subcollection: conversations/{conversationId}/messages/{messageId}

Field	Type	Required	Description
senderId	string	YES	uid
text	string	YES	Message body
timestamp	timestamp	YES	Server timestamp
readBy	array[string]	YES	uids who read it
messageType	string	NO	RESERVED: text/image/voice/location
mediaURL	string	NO	RESERVED

Example message:

{
  "senderId": "uid_xyz",
  "text": "أنا وصلت نقطة التجمع",
  "timestamp": "2026-04-10T05:45:00Z",
  "readBy": ["uid_xyz"],
  "messageType": "text"
}
Collection: reviews/{reviewId}
Field	Type	Required	Description
tripId	string	YES	
bookingId	string	YES	
reviewerId	string	YES	Who wrote it
revieweeId	string	YES	Who received it
type	string	YES	passenger_to_driver / driver_to_passenger
rating	number	YES	1-5
comment	string	NO	Max 200 chars
createdAt	timestamp	YES	
Collection: config/app (Single Document)
Field	Type	Value
platformFeePercent	number	10
minPriceHalalas	number	1000
paymentExpiryMinutes	number	180
ratingWindowMinutes	number	120
minTripLeadTimeHours	number	4
whatsappSaudi	string	+966XXXXXXXXX
whatsappYemen	string	+967XXXXXXXXX
appVersion	string	1.0.0
forceUpdate	boolean	false
Composite Indexes
Collection	Fields	Purpose
trips	status ASC, dateTime ASC	Search open future trips
trips	originCityId ASC, destCityId ASC, dateTime ASC	Route + date search
trips	driverId ASC, status ASC, dateTime DESC	Driver my trips
bookings	passengerId ASC, status ASC, createdAt DESC	Passenger my bookings
bookings	tripId ASC, status ASC	Trip bookings list
bookings	status ASC, expiresAt ASC	Expire pending payments
conversations	participants ARRAY_CONTAINS, lastMessageAt DESC	User chat list
reviews	revieweeId ASC, createdAt DESC	User reviews list
Reserved Collections (Post-MVP)
Collection	Purpose
companies/{companyId}	Fleet company profiles + settings
adminUsers/{uid}	Admin accounts, permissions, audit log
supportTickets/{ticketId}	In-app support (replace WhatsApp)
promoCodes/{codeId}	Discount codes + usage tracking
notifications/{uid}/items/{notifId}	In-app notification inbox
verifications/{verifId}	Driver ID/license upload + review
payoutRequests/{id}	Driver withdrawal requests (future)

No documents created in reserved collections during MVP. Schema only.

Wallet/Ledger Logic Summary (Manual Settlement)

Stripe payment success:

booking.paymentStatus = paid

booking.driverNetHalalas = total - platformFee

wallet.pendingBalance += driverNetHalalas

ledger entry: earning_pending (pending)

Trip completed:

wallet.pendingBalance -= driverNet

wallet.availableBalance += driverNet

wallet.lifetimeEarned += driverNet

ledger entry: earning_released (posted)

Refund:

booking.paymentStatus = refunded

wallet: subtract from pending first, then available if needed

ledger entry: refund_reversal (posted)
