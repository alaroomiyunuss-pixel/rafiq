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

// ============================================================
// EXPORTS — Scheduled Functions
// ============================================================
exports.expirePendingBookings = expirePendingBookings;
exports.completeTripAndOpenRatingWindow = completeTripAndOpenRatingWindow;

// ============================================================
// EXPORTS — Callable (Rating)
// ============================================================
exports.submitRating = submitRating;
