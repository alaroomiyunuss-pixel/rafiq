const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

const deleteTrip = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const uid = request.auth.uid;
  const { tripId } = request.data;

  if (!tripId) {
    throw new HttpsError("invalid-argument", "tripId مطلوب");
  }

  const tripRef = db.collection("trips").doc(tripId);
  const tripSnap = await tripRef.get();

  if (!tripSnap.exists) {
    throw new HttpsError("not-found", "الرحلة غير موجودة");
  }
  const trip = tripSnap.data();

  // Owner check
  if (trip.driverId !== uid) {
    throw new HttpsError("permission-denied", "لا يمكنك حذف رحلة غيرك");
  }

  // Cannot delete if confirmed bookings exist
  if (trip.confirmedBookings > 0) {
    throw new HttpsError(
      "failed-precondition",
      "لا يمكن حذف رحلة لديها حجوزات مؤكدة، يمكنك إلغاؤها بدلاً من ذلك"
    );
  }

  // Set status to cancelled (soft delete)
  await tripRef.update({
    status: "cancelled",
    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Expire any pending_payment bookings for this trip
  const pendingSnap = await db
    .collection("bookings")
    .where("tripId", "==", tripId)
    .where("status", "==", "pending_payment")
    .get();

  const batch = db.batch();
  pendingSnap.docs.forEach((doc) => {
    batch.update(doc.ref, {
      status: "expired",
      paymentStatus: "expired",
      cancelledBy: "system",
      cancelReason: "تم إلغاء الرحلة من قبل السائق",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  if (!pendingSnap.empty) {
    await batch.commit();
  }

  return { tripId, status: "cancelled" };
});

module.exports = { deleteTrip };
