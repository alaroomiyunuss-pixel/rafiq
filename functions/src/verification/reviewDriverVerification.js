// PATH: functions/src/verification/reviewDriverVerification.js

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

async function isAdmin(uid) {
  // Option A: users/{uid}.role == "admin"
  const userSnap = await db.collection("users").doc(uid).get();
  if (userSnap.exists && userSnap.data().role === "admin") return true;

  // Option B: adminUsers/{uid} exists
  const adminSnap = await db.collection("adminUsers").doc(uid).get();
  if (adminSnap.exists) return true;

  return false;
}

const reviewDriverVerification = onCall({ region: "me-central1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const adminUid = request.auth.uid;
  if (!(await isAdmin(adminUid))) {
    throw new HttpsError("permission-denied", "صلاحيات أدمن مطلوبة");
  }

  const { verificationId, action, rejectionReason } = request.data || {};
  if (!verificationId || !action) {
    throw new HttpsError("invalid-argument", "verificationId و action مطلوبين");
  }

  if (!["approve", "reject"].includes(action)) {
    throw new HttpsError("invalid-argument", "action يجب أن يكون approve أو reject");
  }

  const verifRef = db.collection("driverVerifications").doc(String(verificationId));

  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.runTransaction(async (tx) => {
    const verifSnap = await tx.get(verifRef);
    if (!verifSnap.exists) throw new HttpsError("not-found", "طلب التوثيق غير موجود");

    const verif = verifSnap.data();
    const driverId = verif.driverId;

    if (!driverId) throw new HttpsError("failed-precondition", "driverId غير موجود");

    // Idempotency
    if (verif.status === "approved" && action === "approve") return;
    if (verif.status === "rejected" && action === "reject") return;

    const userRef = db.collection("users").doc(driverId);

    if (action === "approve") {
      tx.update(verifRef, {
        status: "approved",
        rejectionReason: "",
        reviewedAt: now,
        reviewedBy: adminUid,
        updatedAt: now,
      });

      tx.set(
        userRef,
        {
          isDriverVerified: true,
          verificationStatus: "approved",
          updatedAt: now,
        },
        { merge: true }
      );
    } else {
      const reason = rejectionReason ? String(rejectionReason).substring(0, 300) : "مرفوض";

      tx.update(verifRef, {
        status: "rejected",
        rejectionReason: reason,
        reviewedAt: now,
        reviewedBy: adminUid,
        updatedAt: now,
      });

      tx.set(
        userRef,
        {
          isDriverVerified: false,
          verificationStatus: "rejected",
          updatedAt: now,
        },
        { merge: true }
      );
    }
  });

  return { ok: true, verificationId, action };
});

module.exports = { reviewDriverVerification };
