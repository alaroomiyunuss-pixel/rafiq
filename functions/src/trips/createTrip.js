// PATH: functions/src/trips/createTrip.js

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

// MVP: allowed Saudi city IDs (must match cities collection / sa_cities.json)
const ALLOWED_CITIES = [
  "riyadh","jeddah","makkah","madinah","dammam","khobar","dhahran",
  "jubail","taif","tabuk","buraidah","unaizah","hail","abha",
  "khamis_mushait","najran","jazan","yanbu","hofuf","mubarraz",
  "qatif","ahsa","sakaka","arar","rafha","dawadmi","afif",
  "qurayyat","wadi_dawasir","bisha","al_baha","shaqra","al_kharj",
  "majmaah","zulfi","muzahmiyya","al_ula","rabigh","al_lith",
  "al_qunfudhah","khulays","badr","al_wajh","duba","haql","umluj",
  "tayma","baljurashi","namas","muhail_asir","sabya","abu_arish",
  "samtah","sharurah","turaif","hafar_al_batin","khafji",
  "ras_tanura","buqayq","al_rass","al_badayea","neom","thuwal","diriyah",
];

const VALID_MEETING_MODES = ["MAP_PIN", "MANUAL_ADDRESS", "DRIVER_PICKS_UP"];

const MIN_LEAD_TIME_MS = 4 * 60 * 60 * 1000; // 4 hours
const MIN_PRICE_HALALAS = 1000; // 10 SAR
const MAX_SEATS = 7;
const MAX_NOTES_LENGTH = 200;

const createTrip = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const uid = request.auth.uid;

  // Load user
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) throw new HttpsError("not-found", "المستخدم غير موجود");
  const user = userSnap.data();

  // Role
  if (user.role !== "driver" && user.role !== "both") {
    throw new HttpsError("permission-denied", "يجب أن تكون سائقاً لإنشاء رحلة");
  }

  // ✅ Verification gate (MVP)
  // Allowed when:
  // - user.isDriverVerified === true
  // OR user.verificationStatus === "approved"
  // (both supported because older docs may only have one field)
  const isVerified =
    user.isDriverVerified === true || user.verificationStatus === "approved";

  if (!isVerified) {
    throw new HttpsError(
      "failed-precondition",
      "لا يمكنك إضافة رحلة قبل توثيق حساب السائق"
    );
  }

  const {
    originCityId,
    destCityId,
    dateTime,
    totalSeats,
    pricePerSeatHalalas,
    vehicleId,
    meetingMode,
    meetingPoint,
    notes,
  } = request.data || {};

  // Required
  if (
    !originCityId ||
    !destCityId ||
    !dateTime ||
    !totalSeats ||
    !pricePerSeatHalalas ||
    !vehicleId ||
    !meetingMode
  ) {
    throw new HttpsError("invalid-argument", "جميع الحقول المطلوبة يجب تعبئتها");
  }

  // Cities
  if (!ALLOWED_CITIES.includes(originCityId)) {
    throw new HttpsError("invalid-argument", "مدينة الانطلاق غير صالحة");
  }
  if (!ALLOWED_CITIES.includes(destCityId)) {
    throw new HttpsError("invalid-argument", "مدينة الوصول غير صالحة");
  }
  if (originCityId === destCityId) {
    throw new HttpsError(
      "invalid-argument",
      "مدينة الانطلاق والوصول يجب أن تكونا مختلفتين"
    );
  }

  // DateTime
  const tripDate = new Date(dateTime);
  if (Number.isNaN(tripDate.getTime())) {
    throw new HttpsError("invalid-argument", "تاريخ غير صالح");
  }
  if (tripDate.getTime() - Date.now() < MIN_LEAD_TIME_MS) {
    throw new HttpsError(
      "invalid-argument",
      "يجب أن يكون موعد الرحلة بعد 4 ساعات على الأقل"
    );
  }

  // Seats
  if (!Number.isInteger(totalSeats) || totalSeats < 1 || totalSeats > MAX_SEATS) {
    throw new HttpsError("invalid-argument", "عدد المقاعد يجب أن يكون بين 1 و 7");
  }

  // Price
  if (
    !Number.isInteger(pricePerSeatHalalas) ||
    pricePerSeatHalalas < MIN_PRICE_HALALAS
  ) {
    throw new HttpsError("invalid-argument", "السعر يجب أن يكون 10 ريال على الأقل");
  }

  // Vehicle
  const vehicleSnap = await db
    .collection("users")
    .doc(uid)
    .collection("vehicles")
    .doc(vehicleId)
    .get();

  if (!vehicleSnap.exists || !vehicleSnap.data().isActive) {
    throw new HttpsError("not-found", "المركبة غير موجودة أو غير مفعّلة");
  }
  const vehicle = vehicleSnap.data();

  if (totalSeats > vehicle.maxSeats) {
    throw new HttpsError("invalid-argument", "عدد المقاعد يتجاوز سعة المركبة");
  }

  // Meeting mode
  if (!VALID_MEETING_MODES.includes(meetingMode)) {
    throw new HttpsError("invalid-argument", "نوع نقطة التجمع غير صالح");
  }

  if (meetingMode === "MAP_PIN") {
    if (
      !meetingPoint ||
      typeof meetingPoint.lat !== "number" ||
      typeof meetingPoint.lng !== "number"
    ) {
      throw new HttpsError("invalid-argument", "MAP_PIN يتطلب إحداثيات نقطة التجمع");
    }
  }

  if (meetingMode === "MANUAL_ADDRESS") {
    if (
      !meetingPoint ||
      !meetingPoint.address ||
      typeof meetingPoint.address !== "string"
    ) {
      throw new HttpsError("invalid-argument", "MANUAL_ADDRESS يتطلب عنوان نصي");
    }
  }

  // Notes
  const trimmedNotes = notes ? String(notes).substring(0, MAX_NOTES_LENGTH) : "";

  // City names (denormalize)
  const [originSnap, destSnap] = await Promise.all([
    db.collection("cities").doc(originCityId).get(),
    db.collection("cities").doc(destCityId).get(),
  ]);

  const originNameAr = originSnap.exists ? originSnap.data().nameAr : originCityId;
  const destNameAr = destSnap.exists ? destSnap.data().nameAr : destCityId;

  const now = admin.firestore.FieldValue.serverTimestamp();
  const vehicleSummary = `${vehicle.make} ${vehicle.model} ${vehicle.year} ${vehicle.color}`;

  const tripData = {
    driverId: uid,
    driverName: user.name,
    driverPhoto: user.photoURL || "",
    driverRating: user.avgRating || 0,

    originCityId,
    originNameAr,
    destCityId,
    destNameAr,

    dateTime: admin.firestore.Timestamp.fromDate(tripDate),

    totalSeats,
    availableSeats: totalSeats,

    pricePerSeatHalalas,

    vehicleId,
    vehicleSummary,

    meetingMode,
    meetingPoint: meetingPoint || null,

    notes: trimmedNotes,

    status: "open",
    confirmedBookings: 0,

    createdAt: now,
    updatedAt: now,

    // Reserved hooks
    companyId: null,
    recurringId: null,
  };

  const tripRef = await db.collection("trips").add(tripData);

  return { tripId: tripRef.id, status: "open" };
});

module.exports = { createTrip };
