// PATH: functions/src/verification/submitDriverVerification.js

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

const submitDriverVerification = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const uid = request.auth.uid;

  // User must be driver/both
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new HttpsError("not-found", "المستخدم غير موجود");

  const user = userSnap.data();
  if (user.role !== "driver" && user.role !== "both") {
    throw new HttpsError("permission-denied", "هذه الخدمة للسائقين فقط");
  }

  // Input: store Storage paths or download URLs (strings)
  const {
    idDocumentURL,
    licenseURL,
    vehicleRegistrationURL,
    selfieURL,
  } = request.data || {};

  if (
    !idDocumentURL ||
    !licenseURL ||
    !vehicleRegistrationURL ||
    !selfieURL
  ) {
    throw new HttpsError(
      "invalid-argument",
      "يجب رفع: الهوية + الرخصة + استمارة السيارة + السيلفي"
    );
  }

  // If already approved, do nothing
  if (user.isDriverVerified === true || user.verificationStatus === "approved") {
    return { ok: true, message: "حسابك موثق بالفعل", status: "approved" };
  }

  // Prevent multiple pending requests
  const pendingSnap = await db
    .collection("driverVerifications")
    .where("driverId", "==", uid)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (!pendingSnap.empty) {
    const existing = pendingSnap.docs[0];
    return { ok: true, verificationId: existing.id, status: "pending" };
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

  const verifRef = await db.collection("driverVerifications").add({
    driverId: uid,

    idDocumentURL: String(idDocumentURL),
    licenseURL: String(licenseURL),
    vehicleRegistrationURL: String(vehicleRegistrationURL),
    selfieURL: String(selfieURL),

    status: "pending",
    rejectionReason: "",

    createdAt: now,
    reviewedAt: null,
    reviewedBy: null,
    updatedAt: now,
  });

  // Update user status
  await userRef.set(
    {
      isDriverVerified: false,
      verificationStatus: "pending",
      updatedAt: now,
    },
    { merge: true }
  );

  return { ok: true, verificationId: verifRef.id, status: "pending" };
});

module.exports = { submitDriverVerification };
