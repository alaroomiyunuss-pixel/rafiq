const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

const PAYMENT_EXPIRY_MS = 3 * 60 * 60 * 1000; // 3 hours

const createBooking = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const uid = request.auth.uid;

  const { tripId, seatCount, pickupPoint } = request.data;

  if (!tripId || !seatCount) {
    throw new HttpsError("invalid-argument", "tripId و seatCount مطلوبة");
  }
  if (!Number.isInteger(seatCount) || seatCount < 1) {
    throw new HttpsError("invalid-argument", "عدد المقاعد غير صالح");
  }

  // --- Verify passenger role ---
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }
  const user = userSnap.data();
  if (user.role !== "passenger" && user.role !== "both") {
    throw new HttpsError("permission-denied", "يجب أن تكون راكباً لإنشاء حجز");
  }

  // --- Load config for platform fee ---
  const configSnap = await db.collection("config").doc("app").get();
  const platformFeePercent = configSnap.exists
    ? configSnap.data().platformFeePercent || 10
    : 10;

  // --- Transaction: validate + decrement seats + create booking ---
  const bookingId = db.collection("bookings").doc().id;

  await db.runTransaction(async (txn) => {
    const tripRef = db.collection("trips").doc(tripId);
    const tripSnap = await txn.get(tripRef);

    if (!tripSnap.exists) {
      throw new HttpsError("not-found", "الرحلة غير موجودة");
    }
    const trip = tripSnap.data();

    // Cannot book own trip
    if (trip.driverId === uid) {
      throw new HttpsError("failed-precondition", "لا يمكنك حجز رحلتك الخاصة");
    }

    // Trip must be open
    if (trip.status !== "open") {
      throw new HttpsError("failed-precondition", "الرحلة غير متاحة للحجز");
    }

    // Seat availability
    if (seatCount > trip.availableSeats) {
      throw new HttpsError(
        "failed-precondition",
        `المقاعد المتاحة: ${trip.availableSeats} فقط`
      );
    }

    // DRIVER_PICKS_UP requires pickup point from passenger
    if (trip.meetingMode === "DRIVER_PICKS_UP") {
      if (!pickupPoint || typeof pickupPoint.lat !== "number" || typeof pickupPoint.lng !== "number") {
        throw new HttpsError("invalid-argument", "يجب تحديد نقطة الالتقاء على الخريطة");
      }
    }

    // Calculate amounts
    const totalAmountHalalas = trip.pricePerSeatHalalas * seatCount;
    const platformFeeHalalas = Math.round(totalAmountHalalas * platformFeePercent / 100);

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + PAYMENT_EXPIRY_MS
    );

    // Decrement seats
    const newAvailable = trip.availableSeats - seatCount;
    const newConfirmed = trip.confirmedBookings + 1;
    const tripUpdate = {
      availableSeats: newAvailable,
      confirmedBookings: newConfirmed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    // Auto-full if no seats left
    if (newAvailable === 0) {
      tripUpdate.status = "full";
    }
    txn.update(tripRef, tripUpdate);

    // Create booking
    const bookingRef = db.collection("bookings").doc(bookingId);
    txn.set(bookingRef, {
      tripId,
      passengerId: uid,
      passengerName: user.name,
      driverId: trip.driverId,
      seatCount,
      totalAmountHalalas,
      platformFeeHalalas,
      paymentIntentId: null,
      paymentStatus: "unpaid",
      status: "pending_payment",
      cancelledBy: null,
      cancelReason: null,
      pickupPoint: pickupPoint || null,
      createdAt: now,
      expiresAt,
      confirmedAt: null,
      completedAt: null,
      cancelledAt: null,
      refundedAt: null,
      // Reserved
      promoCodeId: null,
      refundId: null,
    });
  });

  return {
    bookingId,
    status: "pending_payment",
    message: "تم إنشاء الحجز. أكمل الدفع خلال 3 ساعات",
  };
});

module.exports = { createBooking };
