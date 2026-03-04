const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

const submitRating = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const uid = request.auth.uid;
  const { bookingId, rating, comment } = request.data;

  // --- Validate input ---
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "bookingId مطلوب");
  }
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new HttpsError("invalid-argument", "التقييم يجب أن يكون بين 1 و 5");
  }
  const trimmedComment = comment ? String(comment).substring(0, 200) : "";

  // --- Load booking ---
  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();

  if (!bookingSnap.exists) {
    throw new HttpsError("not-found", "الحجز غير موجود");
  }
  const booking = bookingSnap.data();

  // --- Must be participant ---
  const isPassenger = booking.passengerId === uid;
  const isDriver = booking.driverId === uid;
  if (!isPassenger && !isDriver) {
    throw new HttpsError("permission-denied", "يمكن فقط للمشاركين في الرحلة التقييم");
  }

  // --- Booking must be completed ---
  if (booking.status !== "completed") {
    throw new HttpsError("failed-precondition", "لا يمكن التقييم قبل اكتمال الرحلة");
  }

  // --- Rating window must be open ---
  if (booking.ratingWindowStatus !== "open") {
    throw new HttpsError(
      "failed-precondition",
      booking.ratingWindowStatus === "closed"
        ? "انتهت مهلة التقييم (ساعتين)"
        : "نافذة التقييم غير مفتوحة"
    );
  }

  // --- Determine review type and reviewee ---
  const reviewType = isPassenger ? "passenger_to_driver" : "driver_to_passenger";
  const reviewerId = uid;
  const revieweeId = isPassenger ? booking.driverId : booking.passengerId;

  // --- Check for duplicate review ---
  const existingSnap = await db
    .collection("reviews")
    .where("bookingId", "==", bookingId)
    .where("reviewerId", "==", reviewerId)
    .limit(1)
    .get();

  if (!existingSnap.empty) {
    throw new HttpsError("already-exists", "لقد قمت بالتقييم مسبقاً لهذا الحجز");
  }

  // --- Create review + update user average in transaction ---
  const reviewId = db.collection("reviews").doc().id;

  await db.runTransaction(async (txn) => {
    // Read reviewee user doc
    const revieweeRef = db.collection("users").doc(revieweeId);
    const revieweeSnap = await txn.get(revieweeRef);

    if (!revieweeSnap.exists) {
      throw new HttpsError("not-found", "المستخدم المراد تقييمه غير موجود");
    }
    const reviewee = revieweeSnap.data();

    // Calculate new average
    const currentTotal = reviewee.totalRatings || 0;
    const currentAvg = reviewee.avgRating || 0;
    const currentSum = currentAvg * currentTotal;

    const newTotal = currentTotal + 1;
    const newAvg = Math.round(((currentSum + rating) / newTotal) * 100) / 100;

    // Create review
    const reviewRef = db.collection("reviews").doc(reviewId);
    txn.set(reviewRef, {
      tripId: booking.tripId,
      bookingId,
      reviewerId,
      revieweeId,
      type: reviewType,
      rating,
      comment: trimmedComment,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update reviewee average
    txn.update(revieweeRef, {
      avgRating: newAvg,
      totalRatings: newTotal,
    });

    // Update booking: mark which side rated
    const ratingField = isPassenger ? "passengerRated" : "driverRated";
    const bookingUpdate = { [ratingField]: true };

    // If both sides rated, close window
    const otherField = isPassenger ? "driverRated" : "passengerRated";
    if (booking[otherField] === true) {
      bookingUpdate.ratingWindowStatus = "closed";
    }
    txn.update(bookingRef, bookingUpdate);
  });

  return {
    reviewId,
    rating,
    type: reviewType,
    message: "تم التقييم بنجاح",
  };
});

module.exports = { submitRating };
