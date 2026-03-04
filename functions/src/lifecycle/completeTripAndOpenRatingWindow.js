const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const db = admin.firestore();

/**
 * Completes trip + completes confirmed bookings + opens rating window.
 * ALSO: releases driver earnings from pending -> available for STRIPE-paid bookings.
 */
const completeTripAndOpenRatingWindow = onRequest(
  { region: "me-central1", cors: true },
  async (req, res) => {
    try {
      const { tripId } = req.body || {};
      if (!tripId) return res.status(400).json({ error: "tripId required" });

      const tripRef = db.collection("trips").doc(tripId);

      await db.runTransaction(async (tx) => {
        const tripSnap = await tx.get(tripRef);
        if (!tripSnap.exists) throw new Error("Trip not found");

        const trip = tripSnap.data();
        const driverId = trip.driverId;

        // Mark trip completed (idempotent)
        if (trip.status !== "completed") {
          tx.update(tripRef, {
            status: "completed",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Load confirmed bookings for this trip
        const bookingsQuery = db
          .collection("bookings")
          .where("tripId", "==", tripId)
          .where("status", "==", "confirmed");

        const bookingsSnap = await tx.get(bookingsQuery);

        const walletRef = db.collection("users").doc(driverId).collection("finance").doc("wallet");
        const walletSnap = await tx.get(walletRef);

        // Ensure wallet exists
        if (!walletSnap.exists) {
          tx.set(walletRef, {
            currency: "SAR",
            availableBalanceHalalas: 0,
            pendingBalanceHalalas: 0,
            lifetimeEarnedHalalas: 0,
            lifetimeWithdrawnHalalas: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        for (const doc of bookingsSnap.docs) {
          const bookingId = doc.id;
          const booking = doc.data();

          // Complete booking
          tx.update(doc.ref, {
            status: "completed",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Rating window: store "ratingAllowedUntil" if you want
          // (Your app already has rating window logic elsewhere)

          // Release driver earnings ONLY if stripe-paid
          if (booking.paymentMethod === "stripe" && booking.paymentStatus === "paid") {
            const driverNet = Number(booking.driverNetHalalas || 0);
            if (driverNet > 0) {
              // pending -> available
              tx.update(walletRef, {
                pendingBalanceHalalas: admin.firestore.FieldValue.increment(-driverNet),
                availableBalanceHalalas: admin.firestore.FieldValue.increment(driverNet),
                lifetimeEarnedHalalas: admin.firestore.FieldValue.increment(driverNet),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              const entryRef = db
                .collection("users")
                .doc(driverId)
                .collection("financeLedger")
                .doc();

              tx.set(entryRef, {
                type: "earning_released",
                bookingId,
                tripId,
                passengerId: booking.passengerId,
                driverId,
                amountHalalas: driverNet,
                currency: "SAR",
                status: "posted",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }

          // CASH policy (MVP): just mark reminder state; no money movement
          if (booking.paymentMethod === "cash") {
            tx.update(doc.ref, {
              cashPolicy: "cash_must_be_paid_to_driver_24h_before",
            });
          }
        }
      });

      return res.json({ ok: true, tripId });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: e.message || "unknown" });
    }
  }
);

module.exports = { completeTripAndOpenRatingWindow };
