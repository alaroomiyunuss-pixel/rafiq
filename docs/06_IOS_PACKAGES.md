# رفيق (Rafiq) — iOS Swift Packages

> PATH: docs/
> FILENAME: 06_IOS_PACKAGES.md

---

## Swift Package Manager (SPM) Dependencies

### 1. Firebase iOS SDK

**URL:** `https://github.com/firebase/firebase-ios-sdk.git`
**Version:** 11.0.0+ (Up to Next Major)

Products to add to target:
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseFunctions`
- `FirebaseMessaging`
- `FirebaseStorage`

---

### 2. Stripe iOS SDK

**URL:** `https://github.com/stripe/stripe-ios.git`
**Version:** 24.0.0+ (Up to Next Major)

Products to add to target:
- `StripePaymentSheet`

StripePaymentSheet includes Apple Pay support. No need to add StripeApplePay separately.

---

### 3. Google Maps iOS SDK

**URL:** `https://github.com/nicklama/google-maps-ios-spm.git`
**Version:** 9.0.0+ (Up to Next Major)

Products to add to target:
- `GoogleMaps`
- `GoogleMapsBase`

Alternative (CocoaPods-free official): Use Google's XCFramework via SPM proxy above since Google does not yet officially publish Maps via SPM.

---

## Xcode Setup Steps

### Step 1: Open project in Xcode

```
File → Open → ios-app/Rafiq.xcodeproj
```

### Step 2: Add each package

```
File → Add Package Dependencies...
```

For each URL above:
1. Paste the URL in the search bar
2. Set Dependency Rule to "Up to Next Major Version"
3. Set the minimum version as listed
4. Click "Add Package"
5. Select ONLY the products listed above
6. Ensure target is "Rafiq"

### Step 3: Verify in Project Navigator

```
Rafiq (project)
  └── Package Dependencies
        ├── firebase-ios-sdk (5 products)
        ├── stripe-ios (1 product)
        └── google-maps-ios-spm (2 products)
```

---

## Required Config Files

### GoogleService-Info.plist

1. Firebase Console → Project Settings → iOS app
2. Download `GoogleService-Info.plist`
3. Drag into `ios-app/Rafiq/Resources/`
4. Ensure "Copy items if needed" is checked
5. Add to `.gitignore`

### Google Maps API Key

1. Google Cloud Console → APIs & Services → Credentials
2. Create API key restricted to "Maps SDK for iOS"
3. Restrict to your app bundle ID
4. Add to `Info.plist` or load from config at runtime

### Stripe Publishable Key

1. Stripe Dashboard → Developers → API Keys
2. Copy publishable key (`pk_test_...` or `pk_live_...`)
3. Store in app constants (not hardcoded in production, use Remote Config)

---

## Info.plist Additions

```xml
<!-- Google Maps -->
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>

<!-- Push Notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<!-- Apple Pay Merchant ID -->
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.rafiq.app</string>
</array>

<!-- Location (for meeting point selection) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج موقعك لتحديد نقطة التجمع</string>
```

---

## Xcode Capabilities

Enable in Signing & Capabilities tab:
- Push Notifications
- Apple Pay (Merchant ID: `merchant.com.rafiq.app`)
- Background Modes → Remote notifications

---

## Summary Table

| Package | URL | Version | Products |
|---------|-----|---------|----------|
| Firebase | github.com/firebase/firebase-ios-sdk | 11.0.0+ | Auth, Firestore, Functions, Messaging, Storage |
| Stripe | github.com/stripe/stripe-ios | 24.0.0+ | StripePaymentSheet |
| Google Maps | github.com/nicklama/google-maps-ios-spm | 9.0.0+ | GoogleMaps, GoogleMapsBase |
