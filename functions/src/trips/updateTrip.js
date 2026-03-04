const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
const MIN_LEAD_TIME_MS = 4 * 60 * 60 * 1000;
const MIN_PRICE_HALALAS = 1000;
const MAX_SEATS = 7;
const MAX_NOTES_LENGTH = 200;
const VALID_MEETING_MODES = ["MAP_PIN", "MANUAL_ADDRESS", "DRIVER_PICKS_UP"];

const updateTrip = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const uid = request.auth.uid;
  const { tripId, updates } = request.data;

  if (!tripId || !updates || typeof updates !== "object") {
    throw new HttpsError("invalid-argument", "tripId و updates مطلوبة");
  }

  // --- Load trip ---
  const tripRef = db.collection("trips").doc(tripId);
  const tripSnap = await tripRef.get();
  if (!tripSnap.exists) {
    throw new HttpsError("not-found", "الرحلة غير موجودة");
  }
  const trip = tripSnap.data();

  // --- Owner check ---
  if (trip.driverId !== uid) {
    throw new HttpsError("permission-denied", "لا يمكنك تعديل رحلة غيرك");
  }

  // --- Status check ---
  if (trip.status !== "open") {
    throw new HttpsError("failed-precondition", "لا يمكن تعديل رحلة بحالة: " + trip.status);
  }

  // --- 24h rule ---
  const tripDateTime = trip.dateTime.toDate().getTime();
  if (tripDateTime - Date.now() < TWENTY_FOUR_HOURS_MS) {
    throw new HttpsError("failed-precondition", "لا يمكن التعديل قبل 24 ساعة من موعد الرحلة");
  }

  // --- Booking count rule ---
  if (trip.confirmedBookings > 0) {
    throw new HttpsError("failed-precondition", "لا يمكن التعديل بعد وجود حجوزات مؤكدة");
  }

  // --- Build safe update ---
  const safeUpdate = {};

  // Disallow protected fields
  const PROTECTED = [
    "driverId", "status", "availableSeats", "confirmedBookings",
    "createdAt", "companyId", "recurringId",
  ];
  for (const key of PROTECTED) {
    if (key in updates) {
      throw new HttpsError("invalid-argument", `لا يمكن تعديل الحقل: ${key}`);
    }
  }

  // dateTime
  if (updates.dateTime) {
    const newDate = new Date(updates.dateTime);
    if (isNaN(newDate.getTime())) {
      throw new HttpsError("invalid-argument", "تاريخ غير صالح");
    }
    if (newDate.getTime() - Date.now() < MIN_LEAD_TIME_MS) {
      throw new HttpsError("invalid-argument", "يجب أن يكون الموعد بعد 4 ساعات على الأقل");
    }
    safeUpdate.dateTime = admin.firestore.Timestamp.fromDate(newDate);
  }

  // totalSeats
  if (updates.totalSeats !== undefined) {
    if (!Number.isInteger(updates.totalSeats) || updates.totalSeats < 1 || updates.totalSeats > MAX_SEATS) {
      throw new HttpsError("invalid-argument", "عدد المقاعد يجب أن يكون بين 1 و 7");
    }
    safeUpdate.totalSeats = updates.totalSeats;
    safeUpdate.availableSeats = updates.totalSeats; // safe: 0 bookings
  }

  // pricePerSeatHalalas
  if (updates.pricePerSeatHalalas !== undefined) {
    if (!Number.isInteger(updates.pricePerSeatHalalas) || updates.pricePerSeatHalalas < MIN_PRICE_HALALAS) {
      throw new HttpsError("invalid-argument", "السعر يجب أن يكون 10 ريال على الأقل");
    }
    safeUpdate.pricePerSeatHalalas = updates.pricePerSeatHalalas;
  }

  // meetingMode + meetingPoint
  if (updates.meetingMode) {
    if (!VALID_MEETING_MODES.includes(updates.meetingMode)) {
      throw new HttpsError("invalid-argument", "نوع نقطة التجمع غير صالح");
    }
    safeUpdate.meetingMode = updates.meetingMode;
  }
  if (updates.meetingPoint !== undefined) {
    safeUpdate.meetingPoint = updates.meetingPoint;
  }

  // notes
  if (updates.notes !== undefined) {
    safeUpdate.notes = String(updates.notes).substring(0, MAX_NOTES_LENGTH);
  }

  // vehicleId
  if (updates.vehicleId) {
    const vSnap = await db
      .collection("users").doc(uid)
      .collection("vehicles").doc(updates.vehicleId)
      .get();
    if (!vSnap.exists || !vSnap.data().isActive) {
      throw new HttpsError("not-found", "المركبة غير موجودة أو غير مفعّلة");
    }
    const v = vSnap.data();
    safeUpdate.vehicleId = updates.vehicleId;
    safeUpdate.vehicleSummary = `${v.make} ${v.model} ${v.year} ${v.color}`;
  }

  if (Object.keys(safeUpdate).length === 0) {
    throw new HttpsError("invalid-argument", "لا توجد تعديلات صالحة");
  }

  safeUpdate.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  await tripRef.update(safeUpdate);

  return { tripId, updated: Object.keys(safeUpdate) };
});

module.exports = { updateTrip };
