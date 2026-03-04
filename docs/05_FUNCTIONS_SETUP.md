# رفيق (Rafiq) — Functions Setup Guide

> PATH: docs/
> FILENAME: 05_FUNCTIONS_SETUP.md

---

## Prerequisites

- Node.js 18 (use nvm: `nvm use 18`)
- Firebase CLI: `npm install -g firebase-tools`
- Stripe account (test mode for dev)
- Firebase project created in me-central1

---

## 1. Initial Setup

```bash
# Login to Firebase
firebase login

# Init project (select Functions + Firestore)
firebase init

# Navigate to functions
cd functions

# Install dependencies
npm install
```

---

## 2. Environment Variables

```bash
# Copy template
cp .env.example .env

# Fill in real values
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
APP_ENV=development
SUPPORT_WHATSAPP_SA=+966XXXXXXXXX
SUPPORT_WHATSAPP_YE=+967XXXXXXXXX
```

For production, set via Firebase:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

---

## 3. Deploy Security Rules

```bash
# From project root
firebase deploy --only firestore:rules
```

---

## 4. Run Emulators (Local Dev)

```bash
# Start all emulators
firebase emulators:start --only functions,firestore,auth

# Or just functions
cd functions && npm run serve
```

Emulator UI: http://localhost:4000

---

## 5. Stripe Webhook (Local)

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to emulator
stripe listen --forward-to http://localhost:5001/YOUR_PROJECT/me-central1/stripeWebhookHandler

# Copy signing secret from output to .env
```

---

## 6. Seed Cities Data

```bash
# Use Firebase Admin SDK script or console
# Import sa_cities.json into cities collection
node scripts/seedCities.js
```

---

## 7. Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:createTrip

# Deploy with rules
firebase deploy --only functions,firestore:rules
```

---

## 8. Verify Deployment

```bash
# Check function logs
firebase functions:log

# List deployed functions
firebase functions:list
```

All functions deploy to **me-central1** (Dammam).

---

## File Structure

```
functions/
  .env.example          ← Template (committed)
  .env                  ← Real values (gitignored)
  package.json          ← Dependencies
  src/
    index.js            ← Exports all functions
    trips/
      createTrip.js
      updateTrip.js
      deleteTrip.js
    bookings/
      createBooking.js
      cancelBooking.js
      expirePending.js
    payments/
      createIntent.js
      webhook.js
    lifecycle/
      completeTrip.js
    ratings/
      submitRating.js
```
