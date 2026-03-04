const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const db = admin.firestore();

const expirePendingBookings = onSchedule(
  {
    region: "me-central1",
    schedule: "every 15 minutes",
    timeZone: "Asia/Riyadh",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // --- Find all expired pending_payment bookings ---
    const expiredSnap = await db
      .collection("bookings")
      .where("status", "==", "pending_payment")
      .where("expiresAt", "<=", now)
      .get();

    if (expiredSnap.empty) {
      console.log("No expired pending bookings found.");
      return;
    }

    console.log(`Found ${expiredSnap.size} expired pending bookings.`);

    // --- Process each expired booking ---
    const results = { success: 0, failed: 0 };

    for (const bookingDoc of expiredSnap.docs) {
      try {
        await processExpiredBooking(bookingDoc);
        results.success++;
      } catch (err) {
        console.error(`Failed to expire booking ${bookingDoc.id}:`, err.message);
        results.failed++;
      }
    }

    console.log(
      `Expiry complete: ${results.success} succeeded, ${results.failed} failed.`
    );
  }
);

// ============================================================
// Process a single expired booking via transaction
// ============================================================
async function processExpiredBooking(bookingDoc) {
  const bookingId = bookingDoc.id;
  const booking = bookingDoc.data();

  await db.runTransaction(async (txn) => {
    // Re-read booking inside transaction for consistency
    const bookingRef = db.collection("bookings").doc(bookingId);
    const freshSnap = await txn.get(bookingRef);

    if (!freshSnap.exists) return;
    const fresh = freshSnap.data();

    // Double-check: still pending_payment
    if (fresh.status !== "pending_payment") {
      console.log(`Booking ${bookingId} no longer pending, skipping.`);
      return;
    }

    // --- Restore seats on trip ---
    const tripRef = db.collection("trips").doc(fresh.tripId);
    const tripSnap = await txn.get(tripRef);

    if (tripSnap.exists) {
      const trip = tripSnap.data();
      const restoredSeats = trip.availableSeats + fresh.seatCount;
      const restoredBookings = Math.max(0, trip.confirmedBookings - 1);

      const tripUpdate = {
        availableSeats: restoredSeats,
        confirmedBookings: restoredBookings,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Re-open trip if it was full
      if (trip.status === "full" && restoredSeats > 0) {
        tripUpdate.status = "open";
      }

      txn.update(tripRef, tripUpdate);
    }

    // --- Update booking status ---
    txn.update(bookingRef, {
      status: "expired",
      paymentStatus: "expired",
      cancelledBy: "system",
      cancelReason: "انتهت مهلة الدفع (3 ساعات)",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // --- Notify outside transaction ---
  await notifyExpiry(booking);
}

// ============================================================
// Push notifications for expired booking
// ============================================================
async function notifyExpiry(booking) {
  // Load trip for route context
  let routeText = "رحلة";
  try {
    const tripSnap = await db.collection("trips").doc(booking.tripId).get();
    if (tripSnap.exists) {
      const trip = tripSnap.data();
      routeText = `${trip.originNameAr} → ${trip.destNameAr}`;
    }
  } catch (err) {
    // Non-critical, continue with generic text
  }

  // Notify passenger
  await sendPushToUser(booking.passengerId, {
    title: "انتهت مهلة الدفع ⏰",
    body: `انتهت مهلة الدفع لحجزك في رحلة ${routeText}. يمكنك الحجز مرة أخرى`,
    data: { type: "payment_expired", bookingId: booking.tripId },
  });

  // Notify driver
  await sendPushToUser(booking.driverId, {
    title: "إلغاء حجز تلقائي",
    body: `تم إلغاء حجز في رحلة ${routeText} لعدم إتمام الدفع. المقاعد متاحة مرة أخرى`,
    data: { type: "payment_expired", tripId: booking.tripId },
  });
}

// ============================================================
// Helper: send FCM push to a single user
// ============================================================
async function sendPushToUser(uid, notification) {
  try {
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) return;

    const fcmToken = userSnap.data().fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data || {},
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
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

module.exports = { expirePendingBookings };
