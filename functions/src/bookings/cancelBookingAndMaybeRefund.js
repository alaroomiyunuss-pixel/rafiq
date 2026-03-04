const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;

const cancelBookingAndMaybeRefund = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const uid = request.auth.uid;
  const { bookingId, reason } = request.data;

  if (!bookingId) {
    throw new HttpsError("invalid-argument", "bookingId مطلوب");
  }

  // --- Load booking ---
  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();

  if (!bookingSnap.exists) {
    throw new HttpsError("not-found", "الحجز غير موجود");
  }
  const booking = bookingSnap.data();

  // --- Ownership ---
  if (booking.passengerId !== uid) {
    throw new HttpsError("permission-denied", "لا يمكنك إلغاء حجز غيرك");
  }

  // --- Status check ---
  if (booking.status !== "confirmed" && booking.status !== "pending_payment") {
    throw new HttpsError("failed-precondition", "لا يمكن إلغاء حجز بحالة: " + booking.status);
  }

  // --- Load trip for 24h check ---
  const tripRef = db.collection("trips").doc(booking.tripId);
  const tripSnap = await tripRef.get();

  if (!tripSnap.exists) {
    throw new HttpsError("not-found", "الرحلة غير موجودة");
  }
  const trip = tripSnap.data();

  const tripDateTime = trip.dateTime.toDate().getTime();
  const timeUntilTrip = tripDateTime - Date.now();

  // --- 24h rule for confirmed bookings ---
  if (booking.status === "confirmed" && timeUntilTrip <= TWENTY_FOUR_HOURS_MS) {
    throw new HttpsError(
      "failed-precondition",
      "لا يمكن الإلغاء قبل 24 ساعة من موعد الرحلة. لا يوجد استرداد"
    );
  }

  // --- Determine refund eligibility ---
  let refunded = false;
  let stripeRefundId = null;

  if (booking.status === "confirmed" && booking.paymentStatus === "paid" && booking.paymentIntentId) {
    // More than 24h before trip = full refund
    try {
      const refund = await stripe.refunds.create({
        payment_intent: booking.paymentIntentId,
        reason: "requested_by_customer",
        metadata: {
          bookingId,
          tripId: booking.tripId,
          cancelledBy: uid,
        },
      });
      refunded = true;
      stripeRefundId = refund.id;
    } catch (err) {
      console.error(`Stripe refund failed for booking ${bookingId}:`, err.message);
      throw new HttpsError("internal", "فشل في عملية الاسترداد. حاول مرة أخرى");
    }
  }

  // --- Transaction: cancel booking + restore seats ---
  await db.runTransaction(async (txn) => {
    const freshBookingSnap = await txn.get(bookingRef);
    const freshBooking = freshBookingSnap.data();

    // Re-check status inside transaction
    if (freshBooking.status !== "confirmed" && freshBooking.status !== "pending_payment") {
      throw new HttpsError("failed-precondition", "تم تغيير حالة الحجز");
    }

    // Update booking
    const bookingUpdate = {
      status: "cancelled",
      cancelledBy: "passenger",
      cancelReason: reason || "إلغاء من قبل الراكب",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (refunded) {
      bookingUpdate.paymentStatus = "refunded";
      bookingUpdate.refundedAt = admin.firestore.FieldValue.serverTimestamp();
      bookingUpdate.refundId = stripeRefundId;
    }
    if (freshBooking.status === "pending_payment") {
      bookingUpdate.paymentStatus = "expired";
    }
    txn.update(bookingRef, bookingUpdate);

    // Restore seats on trip
    const freshTripSnap = await txn.get(tripRef);
    if (freshTripSnap.exists) {
      const freshTrip = freshTripSnap.data();
      const restoredSeats = freshTrip.availableSeats + freshBooking.seatCount;
      const restoredBookings = Math.max(0, freshTrip.confirmedBookings - 1);

      const tripUpdate = {
        availableSeats: restoredSeats,
        confirmedBookings: restoredBookings,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (freshTrip.status === "full" && restoredSeats > 0) {
        tripUpdate.status = "open";
      }
      txn.update(tripRef, tripUpdate);
    }
  });

  // --- Notify both parties ---
  const routeText = `${trip.originNameAr} → ${trip.destNameAr}`;

  await sendPushToUser(booking.passengerId, {
    title: refunded ? "تم الإلغاء والاسترداد ✅" : "تم إلغاء الحجز",
    body: refunded
      ? `تم إلغاء حجزك في رحلة ${routeText} وسيتم استرداد المبلغ`
      : `تم إلغاء حجزك في رحلة ${routeText}`,
    data: { type: "booking_cancelled", bookingId },
  });

  await sendPushToUser(booking.driverId, {
    title: "إلغاء حجز",
    body: `تم إلغاء حجز في رحلة ${routeText}. المقاعد متاحة مرة أخرى`,
    data: { type: "booking_cancelled", tripId: booking.tripId },
  });

  return {
    bookingId,
    status: "cancelled",
    refunded,
    refundId: stripeRefundId,
  };
});

// ============================================================
// Helper: send FCM push
// ============================================================
async function sendPushToUser(uid, notification) {
  try {
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) return;
    const fcmToken = userSnap.data().fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title: notification.title, body: notification.body },
      data: notification.data || {},
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  } catch (err) {
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      await db.collection("users").doc(uid).update({ fcmToken: null });
    } else {
      console.error(`FCM failed for ${uid}:`, err.message);
    }
  }
}

module.exports = { cancelBookingAndMaybeRefund };
