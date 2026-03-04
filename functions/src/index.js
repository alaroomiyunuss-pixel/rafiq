// PATH: functions/src/index.js

const admin = require("firebase-admin");
admin.initializeApp();

// ============================================================
// رفيق (Rafiq) — Cloud Functions Entry Point
// Region: me-central1 (Dammam)
// Runtime: Node.js 18, JavaScript
// ============================================================

// --- Trips ---
const { createTrip } = require("./trips/createTrip");
const { updateTrip } = require("./trips/updateTrip");
const { deleteTrip } = require("./trips/deleteTrip");

// --- Bookings ---
const { createBooking } = require("./bookings/createBooking");
const { cancelBookingAndMaybeRefund } = require("./bookings/cancelBooking");
const { expirePendingBookings } = require("./bookings/expirePending");

// --- Payments ---
const { createStripePaymentIntent } = require("./payments/createIntent");
const { stripeWebhookHandler } = require("./payments/webhook");

// --- Trips Lifecycle ---
const { completeTripAndOpenRatingWindow } = require("./lifecycle/completeTrip");

// --- Ratings ---
const { submitRating } = require("./ratings/submitRating");

// --- Verification (NEW) ---
const { submitDriverVerification } = require("./verification/submitDriverVerification");
const { reviewDriverVerification } = require("./verification/reviewDriverVerification");

// ============================================================
// EXPORTS — Callable Functions
// ============================================================

exports.createTrip = createTrip;
exports.updateTrip = updateTrip;
exports.deleteTrip = deleteTrip;

exports.createBooking = createBooking;
exports.cancelBookingAndMaybeRefund = cancelBookingAndMaybeRefund;

exports.createStripePaymentIntent = createStripePaymentIntent;
exports.stripeWebhookHandler = stripeWebhookHandler;

exports.submitRating = submitRating;

// Verification (NEW)
exports.submitDriverVerification = submitDriverVerification;
exports.reviewDriverVerification = reviewDriverVerification;

// ============================================================
// EXPORTS — Scheduled / HTTP (as already used)
// ============================================================

exports.expirePendingBookings = expirePendingBookings;
exports.completeTripAndOpenRatingWindow = completeTripAndOpenRatingWindow;
