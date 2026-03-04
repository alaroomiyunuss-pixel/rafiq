const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const db = admin.firestore();

const TRIP_AUTO_COMPLETE_HOURS = 6;
const RATING_WINDOW_MINUTES = 120; // 2 hours

const completeTripAndOpenRatingWindow = onSchedule(
  {
    region: "me-central1",
    schedule: "every 15 minutes",
    timeZone: "Asia/Riyadh",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // ============================================================
    // STEP 1: Mark in_progress trips as completed
    // Trips where dateTime + 6h < now
    // ============================================================
    const cutoff = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - TRIP_AUTO_COMPLETE_HOURS * 60 * 60 * 1000
    );

    // Find open/full trips that should move to in_progress
    const activeTripsSnap = await db
      .collection("trips")
      .where("status", "in", ["open", "full"])
      .where("dateTime", "<=", now)
      .get();

    for (const tripDoc of activeTripsSnap.docs) {
      try {
        await tripDoc.ref.update({
          status: "in_progress",
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Trip ${tripDoc.id} → in_progress`);
      } catch (err) {
        console.error(`Failed to start trip ${tripDoc.id}:`, err.message);
      }
    }

    // Find in_progress trips that should complete
    const inProgressSnap = await db
      .collection("trips")
      .where("status", "==", "in_progress")
      .where("dateTime", "<=", cutoff)
      .get();

    for (const tripDoc of inProgressSnap.docs) {
      try {
        await completeSingleTrip(tripDoc, now);
      } catch (err) {
        console.error(`Failed to complete trip ${tripDoc.id}:`, err.message);
      }
    }

    // ============================================================
    // STEP 2: Close expired rating windows
    // ============================================================
    await closeExpiredRatingWindows(now);

    console.log("completeTripAndOpenRatingWindow cycle done.");
  }
);

// ============================================================
// Complete a single trip + open rating windows
// ============================================================
async function completeSingleTrip(tripDoc, now) {
  const tripId = tripDoc.id;
  const trip = tripDoc.data();

  // Update trip to completed
  await tripDoc.ref.update({
    status: "completed",
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Trip ${tripId} → completed`);

  // Find all confirmed bookings for this trip
  const bookingsSnap = await db
    .collection("bookings")
    .where("tripId", "==", tripId)
    .where("status", "==", "confirmed")
    .get();

  const ratingWindowClosesAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + RATING_WINDOW_MINUTES * 60 * 1000
  );

  for (const bookingDoc of bookingsSnap.docs) {
    const booking = bookingDoc.data();

    // Mark booking completed
    await bookingDoc.ref.update({
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      ratingWindowClosesAt,
      ratingWindowStatus: "open",
    });

    // Send rating reminder push to both parties
    const routeText = `${trip.originNameAr} → ${trip.destNameAr}`;

    await sendPushToUser(booking.passengerId, {
      title: "قيّم رحلتك ⭐",
      body: `اكتملت رحلة ${routeText}. قيّم تجربتك خلال ساعتين`,
      data: { type: "rating_reminder", bookingId: bookingDoc.id, tripId },
    });

    await sendPushToUser(booking.driverId, {
      title: "قيّم الراكب ⭐",
      body: `اكتملت رحلة ${routeText}. قيّم الراكب خلال ساعتين`,
      data: { type: "rating_reminder", bookingId: bookingDoc.id, tripId },
    });
  }
}

// ============================================================
// Close expired rating windows
// ============================================================
async function closeExpiredRatingWindows(now) {
  const expiredSnap = await db
    .collection("bookings")
    .where("ratingWindowStatus", "==", "open")
    .where("ratingWindowClosesAt", "<=", now)
    .get();

  for (const doc of expiredSnap.docs) {
    try {
      await doc.ref.update({
        ratingWindowStatus: "closed",
      });
      console.log(`Rating window closed for booking ${doc.id}`);
    } catch (err) {
      console.error(`Failed to close rating window ${doc.id}:`, err.message);
    }
  }
}

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

module.exports = { completeTripAndOpenRatingWindow };
