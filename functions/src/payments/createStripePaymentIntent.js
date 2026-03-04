const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

const createStripePaymentIntent = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const uid = request.auth.uid;
  const { bookingId } = request.data;

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

  // --- Ownership check ---
  if (booking.passengerId !== uid) {
    throw new HttpsError("permission-denied", "لا يمكنك الدفع لحجز غيرك");
  }

  // --- Status check ---
  if (booking.status !== "pending_payment") {
    throw new HttpsError("failed-precondition", "حالة الحجز لا تسمح بالدفع: " + booking.status);
  }

  // --- Expiry check ---
  if (booking.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError("failed-precondition", "انتهت مهلة الدفع (3 ساعات)");
  }

  // --- If PaymentIntent already exists, return it ---
  if (booking.paymentIntentId) {
    try {
      const existingPI = await stripe.paymentIntents.retrieve(booking.paymentIntentId);
      if (existingPI.status === "requires_payment_method" ||
          existingPI.status === "requires_confirmation" ||
          existingPI.status === "requires_action") {
        return {
          clientSecret: existingPI.client_secret,
          paymentIntentId: existingPI.id,
          amountHalalas: booking.totalAmountHalalas,
        };
      }
    } catch (err) {
      // PI invalid, create new one below
    }
  }

  // --- Create Stripe PaymentIntent ---
  const paymentIntent = await stripe.paymentIntents.create({
    amount: booking.totalAmountHalalas, // Stripe uses smallest unit = halalas
    currency: "sar",
    payment_method_types: ["card", "apple_pay"],
    metadata: {
      bookingId: bookingId,
      tripId: booking.tripId,
      passengerId: uid,
      driverId: booking.driverId,
      seatCount: String(booking.seatCount),
    },
    description: `رفيق — حجز رحلة #${booking.tripId}`,
  });

  // --- Store paymentIntentId on booking ---
  await bookingRef.update({
    paymentIntentId: paymentIntent.id,
    paymentStatus: "unpaid",
  });

  return {
    clientSecret: paymentIntent.client_secret,
    paymentIntentId: paymentIntent.id,
    amountHalalas: booking.totalAmountHalalas,
  };
});

module.exports = { createStripePaymentIntent };
