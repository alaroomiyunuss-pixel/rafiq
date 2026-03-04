const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

const stripeWebhookHandler = onRequest(
  { region: "me-central1", cors: false },
  async (req, res) => {
    // --- Only POST ---
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // --- Verify Stripe signature ---
    let event;
    try {
      const sig = req.headers["stripe-signature"];
      event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    // --- Idempotency: check if already processed ---
    const eventRef = db.collection("_stripeEvents").doc(event.id);
    const eventSnap = await eventRef.get();
    if (eventSnap.exists) {
      console.log(`Event ${event.id} already processed, skipping.`);
      res.status(200).json({ received: true, duplicate: true });
      return;
    }

    // --- Handle event types ---
    try {
      switch (event.type) {
        case "payment_intent.succeeded":
          await handlePaymentSuccess(event.data.object, event.id);
          break;

        case "payment_intent.payment_failed":
          await handlePaymentFailed(event.data.object, event.id);
          break;

        default:
          console.log(`Unhandled event type: ${event.type}`);
      }

      // Mark event as processed
      await eventRef.set({
        type: event.type,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).json({ received: true });
    } catch (err) {
      console.error("Webhook processing error:", err);
      res.status(500).send("Internal error");
    }
  }
);

// ============================================================
// payment_intent.succeeded
// ============================================================
async function handlePaymentSuccess(paymentIntent, eventId) {
  const { bookingId, tripId, passengerId, driverId } = paymentIntent.metadata;

  if (!bookingId) {
    console.error("No bookingId in PaymentIntent metadata");
    return;
  }

  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();

  if (!bookingSnap.exists) {
    console.error(`Booking ${bookingId} not found`);
    return;
  }

  const booking = bookingSnap.data();

  // Idempotent: skip if already confirmed
  if (booking.status === "confirmed" && booking.paymentStatus === "paid") {
    console.log(`Booking ${bookingId} already confirmed, skipping.`);
    return;
  }

  // Update booking
  await bookingRef.update({
    status: "confirmed",
    paymentStatus: "paid",
    confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create conversation for chat
  await createConversation(bookingId, tripId, passengerId, driverId);

  // Send push notifications
  await sendBookingConfirmedPush(passengerId, driverId, tripId);
}

// ============================================================
// payment_intent.payment_failed
// ============================================================
async function handlePaymentFailed(paymentIntent, eventId) {
  const { bookingId } = paymentIntent.metadata;

  if (!bookingId) {
    console.error("No bookingId in PaymentIntent metadata");
    return;
  }

  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();

  if (!bookingSnap.exists) {
    console.error(`Booking ${bookingId} not found`);
    return;
  }

  const booking = bookingSnap.data();

  // Idempotent: skip if already failed
  if (booking.paymentStatus === "failed") {
    return;
  }

  await bookingRef.update({
    paymentStatus: "failed",
  });

  // Notify passenger of failure
  await sendPushToUser(booking.passengerId, {
    title: "فشل الدفع",
    body: "لم يتم الدفع. حاول مرة أخرى قبل انتهاء المهلة",
    data: { type: "payment_failed", bookingId },
  });
}

// ============================================================
// Create conversation on confirmed booking
// ============================================================
async function createConversation(bookingId, tripId, passengerId, driverId) {
  // Check if conversation already exists for this booking
  const existing = await db
    .collection("conversations")
    .where("bookingId", "==", bookingId)
    .limit(1)
    .get();

  if (!existing.empty) {
    return; // Already created
  }

  await db.collection("conversations").add({
    bookingId,
    tripId,
    participants: [passengerId, driverId],
    lastMessage: null,
    lastMessageAt: null,
    unreadCount: { [passengerId]: 0, [driverId]: 0 },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ============================================================
// Push: booking confirmed to both parties
// ============================================================
async function sendBookingConfirmedPush(passengerId, driverId, tripId) {
  // Load trip for context
  const tripSnap = await db.collection("trips").doc(tripId).get();
  const trip = tripSnap.exists ? tripSnap.data() : null;
  const routeText = trip
    ? `${trip.originNameAr} → ${trip.destNameAr}`
    : "رحلة";

  // Notify passenger
  await sendPushToUser(passengerId, {
    title: "تم تأكيد الحجز ✅",
    body: `تم تأكيد حجزك في رحلة ${routeText}`,
    data: { type: "booking_confirmed", tripId },
  });

  // Notify driver
  await sendPushToUser(driverId, {
    title: "حجز جديد 🎉",
    body: `لديك حجز جديد مؤكد في رحلة ${routeText}`,
    data: { type: "booking_confirmed", tripId },
  });
}

// ============================================================
// Helper: send FCM push to a single user
// ============================================================
async function sendPushToUser(uid, notification) {
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) return;

  const fcmToken = userSnap.data().fcmToken;
  if (!fcmToken) return;

  try {
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
    // Token might be stale, log and continue
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      console.warn(`Stale FCM token for user ${uid}, clearing.`);
      await db.collection("users").doc(uid).update({ fcmToken: null });
    } else {
      console.error(`FCM send failed for ${uid}:`, err.message);
    }
  }
}

module.exports = { stripeWebhookHandler };
