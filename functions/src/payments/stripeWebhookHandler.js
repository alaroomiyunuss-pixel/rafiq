const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const db = admin.firestore();

const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

const stripeWebhookHandler = onRequest(
  { region: "me-central1", cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    let event;
    try {
      const sig = req.headers["stripe-signature"];
      event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    // Idempotency
    const eventRef = db.collection("_stripeEvents").doc(event.id);
    const eventSnap = await eventRef.get();
    if (eventSnap.exists) {
      res.status(200).json({ received: true, duplicate: true });
      return;
    }

    try {
      switch (event.type) {
        case "payment_intent.succeeded":
          await handlePaymentSuccess(event.data.object);
          break;

        // Optional: if you later use refunds webhooks
        case "charge.refunded":
          await handleChargeRefunded(event.data.object);
          break;

        case "payment_intent.payment_failed":
          await handlePaymentFailed(event.data.object);
          break;

        default:
          console.log(`Unhandled event type: ${event.type}`);
      }

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
async function handlePaymentSuccess(paymentIntent) {
  const { bookingId, tripId, passengerId, driverId } = paymentIntent.metadata || {};
  if (!bookingId || !tripId || !passengerId || !driverId) {
    console.error("Missing metadata on PaymentIntent (bookingId/tripId/passengerId/driverId)");
    return;
  }

  const bookingRef = db.collection("bookings").doc(bookingId);

  await db.runTransaction(async (tx) => {
    const bookingSnap = await tx.get(bookingRef);
    if (!bookingSnap.exists) throw new Error(`Booking ${bookingId} not found`);

    const booking = bookingSnap.data();

    // Idempotent: already confirmed+paid
    if (booking.status === "confirmed" && booking.paymentStatus === "paid") return;

    const total = Number(booking.totalAmountHalalas || 0);
    const platformFee = Number(booking.platformFeeHalalas || 0);
    const driverNet = Math.max(total - platformFee, 0);

    // Update booking (electronic)
    tx.update(bookingRef, {
      status: "confirmed",
      paymentStatus: "paid",
      paymentMethod: "stripe",
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      driverNetHalalas: driverNet, // NEW (denormalized)
    });

    // Wallet doc (under user)
    const walletRef = db.collection("users").doc(driverId).collection("finance").doc("wallet");
    const walletSnap = await tx.get(walletRef);
    if (!walletSnap.exists) {
      tx.set(walletRef, {
        currency: "SAR",
        availableBalanceHalalas: 0,
        pendingBalanceHalalas: driverNet,
        lifetimeEarnedHalalas: 0,
        lifetimeWithdrawnHalalas: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      tx.update(walletRef, {
        pendingBalanceHalalas: admin.firestore.FieldValue.increment(driverNet),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Ledger entry (pending)
    const entryRef = db.collection("users").doc(driverId).collection("financeLedger").doc();
    tx.set(entryRef, {
      type: "earning_pending", // pending until trip completion
      bookingId,
      tripId,
      passengerId,
      driverId,
      amountHalalas: driverNet,
      currency: "SAR",
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Create conversation + push after transaction
  await createConversation(bookingId, tripId, passengerId, driverId);
  await sendBookingConfirmedPush(passengerId, driverId, tripId);
}

// ============================================================
// charge.refunded (basic reversal)
// ============================================================
async function handleChargeRefunded(charge) {
  // charge.payment_intent could be string id
  const paymentIntentId = charge.payment_intent;
  if (!paymentIntentId) return;

  // We rely on metadata stored on PI:
  const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
  const { bookingId, tripId, passengerId, driverId } = pi.metadata || {};
  if (!bookingId || !driverId) return;

  const bookingRef = db.collection("bookings").doc(bookingId);

  await db.runTransaction(async (tx) => {
    const bookingSnap = await tx.get(bookingRef);
    if (!bookingSnap.exists) return;
    const booking = bookingSnap.data();

    // Idempotent
    if (booking.paymentStatus === "refunded") return;

    const driverNet = Number(booking.driverNetHalalas || 0);

    tx.update(bookingRef, {
      paymentStatus: "refunded",
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Try remove from pending first; if not enough, remove from available.
    const walletRef = db.collection("users").doc(driverId).collection("finance").doc("wallet");
    const walletSnap = await tx.get(walletRef);
    if (!walletSnap.exists) return;

    const w = walletSnap.data();
    const pending = Number(w.pendingBalanceHalalas || 0);
    const takeFromPending = Math.min(pending, driverNet);
    const remaining = driverNet - takeFromPending;

    const updates = {
      pendingBalanceHalalas: admin.firestore.FieldValue.increment(-takeFromPending),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (remaining > 0) {
      updates.availableBalanceHalalas = admin.firestore.FieldValue.increment(-remaining);
    }

    tx.update(walletRef, updates);

    const entryRef = db.collection("users").doc(driverId).collection("financeLedger").doc();
    tx.set(entryRef, {
      type: "refund_reversal",
      bookingId,
      tripId: tripId || booking.tripId,
      passengerId: passengerId || booking.passengerId,
      driverId,
      amountHalalas: driverNet,
      currency: "SAR",
      status: "posted",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

// ============================================================
// payment_intent.payment_failed
// ============================================================
async function handlePaymentFailed(paymentIntent) {
  const { bookingId } = paymentIntent.metadata || {};
  if (!bookingId) return;

  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) return;

  const booking = bookingSnap.data();
  if (booking.paymentStatus === "failed") return;

  await bookingRef.update({ paymentStatus: "failed" });

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
  const existing = await db
    .collection("conversations")
    .where("bookingId", "==", bookingId)
    .limit(1)
    .get();

  if (!existing.empty) return;

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
// Push: booking confirmed
// ============================================================
async function sendBookingConfirmedPush(passengerId, driverId, tripId) {
  const tripSnap = await db.collection("trips").doc(tripId).get();
  const trip = tripSnap.exists ? tripSnap.data() : null;
  const routeText = trip ? `${trip.originNameAr} → ${trip.destNameAr}` : "رحلة";

  await sendPushToUser(passengerId, {
    title: "تم تأكيد الحجز ✅",
    body: `تم تأكيد حجزك في رحلة ${routeText}`,
    data: { type: "booking_confirmed", tripId },
  });

  await sendPushToUser(driverId, {
    title: "حجز جديد",
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
      console.error(`FCM send failed for ${uid}:`, err.message);
    }
  }
}

module.exports = { stripeWebhookHandler };
