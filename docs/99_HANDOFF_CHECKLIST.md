# رفيق — Handoff Checklist & Build Verification

> PATH: docs/
> FILENAME: 99_HANDOFF_CHECKLIST.md

---

## 1. مشروع رفيق — شجرة الملفات الكاملة

```
rafiq/
│
├── docs/
│   ├── 01_SCHEMA.md                         # Firestore schema (users, trips, bookings, etc.)
│   ├── 02_FUNCTIONS_INDEX.md                 # Cloud Functions index & callable map
│   ├── 03_IOS_ARCHITECTURE.md                # iOS app architecture (MVVM, DI, routing)
│   ├── 04_DOMAIN_RULES.md                    # Business rules (halalas, 24h cancel, 2h rating, etc.)
│   ├── 05_FUNCTIONS_SETUP.md                 # Functions local dev & deploy guide
│   ├── 06_IOS_PACKAGES.md                    # Swift Package Manager dependencies
│   ├── 07_SETUP_FIREBASE.md                  # Firebase project + Firestore + Auth setup
│   ├── 08_SETUP_PUSH.md                      # APNs + FCM push notifications setup
│   ├── 09_SETUP_STRIPE.md                    # Stripe + Apple Pay + webhook setup
│   ├── 10_SETUP_MAPS.md                      # Google Maps SDK + API key setup
│   └── 99_HANDOFF_CHECKLIST.md               # ← هذا الملف
│
├── functions/
│   ├── package.json                          # Node 18, Firebase Functions v2, Stripe
│   ├── .env                                  # ← أنشئه يدوياً (secrets)
│   ├── index.js                              # Exports all functions
│   └── src/
│       ├── trips/
│       │   ├── createTrip.js                 # Callable: create trip (driver only)
│       │   ├── updateTrip.js                 # Callable: update trip (owner, 0 bookings, >24h)
│       │   └── deleteTrip.js                 # Callable: soft-delete trip
│       ├── bookings/
│       │   ├── createBooking.js              # Callable: book seats + reserve (transaction)
│       │   ├── cancelBookingAndMaybeRefund.js # Callable: cancel + conditional Stripe refund
│       │   └── expirePendingBookings.js      # Scheduled: expire unpaid after 3h
│       ├── payments/
│       │   ├── createStripePaymentIntent.js  # Callable: create PaymentIntent (SAR, halalas)
│       │   └── stripeWebhookHandler.js       # HTTPS: Stripe webhook → confirm/fail booking
│       ├── lifecycle/
│       │   └── completeTripAndOpenRatingWindow.js # Scheduled: mark complete + open 2h rating
│       └── ratings/
│           └── submitRating.js               # Callable: submit review + update avgRating
│
├── firestore.rules                           # Security rules
├── firestore.indexes.json                    # Composite indexes
├── firebase.json                             # Firebase config (region, emulators)
│
└── ios-app/
    └── Rafiq/
        ├── Rafiq.xcodeproj                   # ← Xcode project (create via Xcode)
        │
        ├── Resources/
        │   ├── GoogleService-Info.plist      # ← من Firebase Console
        │   ├── Info.plist                    # Arabic permissions, RTL, URL schemes
        │   ├── Rafiq.entitlements            # Push, Apple Pay, Keychain
        │   ├── Keys.plist                    # ← أنشئه يدوياً (API keys)
        │   └── sa_cities.json               # مدن السعودية (bundle)
        │
        ├── Design/
        │   └── Theme.swift                   # Colors, Fonts, Spacing, Radius, Shadow
        │
        ├── Components/
        │   ├── PrimaryButton.swift           # Filled, Outline, Destructive + loading
        │   ├── AppCard.swift                 # Card + CardWithHeader
        │   ├── LoadingView.swift             # Dots, Inline, Overlay
        │   ├── EmptyStateView.swift          # Presets: noTrips, noBookings, etc.
        │   └── ErrorStateView.swift          # Error + Banner + presets
        │
        ├── Models/
        │   └── Models.swift                  # All enums + Codable models + computed props
        │
        ├── App/
        │   ├── RafiqApp.swift                # @main, Firebase init, Stripe init, tabs
        │   ├── AppEnvironment.swift          # 8 service protocols + DI + mocks
        │   ├── AppRouter.swift               # NavigationPath × 4 tabs + sheets + alerts
        │   └── DeepLinks.swift               # URL scheme + push payload routing
        │
        ├── Services/
        │   └── FirebaseServices.swift        # 8 production Firebase implementations
        │
        └── Features/
            ├── Auth/
            │   ├── SplashView.swift          # Animated splash
            │   ├── AuthContainerView.swift   # Auth state machine + OTP verify
            │   ├── LoginView.swift           # Phone +966 input
            │   └── RegisterView.swift        # Name + role selection
            │
            ├── Main/
            │   └── MainTabView.swift         # 4 tabs + HomeTab + MyTripsTab + MessagesTab + AccountTab
            │
            ├── Cities/
            │   └── CityPickerView.swift      # Search + region filter + city list
            │
            ├── Maps/
            │   └── GoogleMapsModule.swift     # Setup, PinPickerView, MapPreviewView
            │
            ├── Trips/
            │   ├── HomeSearchView.swift       # Origin/dest/date search form
            │   ├── TripsListView.swift        # Results + sort (date/price/rating)
            │   ├── TripCardView.swift         # Full card + compact card
            │   └── TripDetailView.swift       # Full detail + meeting modes + WhatsApp
            │
            ├── Bookings/
            │   ├── BookingConfirmationView.swift # Seat picker + payment method + 3h rule
            │   ├── MyTripsView.swift           # Filter: upcoming/completed/cancelled
            │   └── BookingDetailView.swift      # Timeline + payment + actions
            │
            ├── Payments/
            │   └── StripePayments.swift        # PaymentSheet + Apple Pay + confirm watcher
            │
            ├── Chat/
            │   ├── MessagesListView.swift      # Conversations + unread badge
            │   └── ChatView.swift              # RTL bubbles + send + location + report
            │
            ├── Ratings/
            │   └── RatingView.swift            # Star picker + comment + 2h window
            │
            ├── Profile/
            │   └── ProfileView.swift           # Stats + WhatsApp SA/YE + logout
            │
            └── Legal/
                └── LegalPagesView.swift        # Terms + Privacy (Arabic)
```

**إجمالي الملفات**: 10 Cloud Functions + 28 Swift files + 10 docs

---

## 2. المفاتيح والأسرار المطلوبة

### functions/.env

```env
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxx
```

### ios-app/Rafiq/Resources/Keys.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GOOGLE_MAPS_API_KEY</key>
    <string>AIzaSy_xxxxxxxxxxxxxxxxxxxxxxx</string>
    <key>STRIPE_PUBLISHABLE_KEY</key>
    <string>pk_test_xxxxxxxxxxxxxxxxxxxx</string>
    <key>STRIPE_MERCHANT_ID</key>
    <string>merchant.com.rafiq.app</string>
    <key>WHATSAPP_SUPPORT_SA</key>
    <string>966XXXXXXXXX</string>
    <key>WHATSAPP_SUPPORT_YE</key>
    <string>967XXXXXXXXX</string>
</dict>
</plist>
```

### ios-app/Rafiq/Resources/GoogleService-Info.plist

- حمّله من Firebase Console → Project Settings → iOS app
- لا تُنشئه يدوياً

### ملفات يجب ألا تُرفع على Git

```gitignore
# .gitignore
functions/.env
ios-app/Rafiq/Resources/Keys.plist
ios-app/Rafiq/Resources/GoogleService-Info.plist
*.p8
```

---

## 3. أوامر Backend (Cloud Functions)

### المتطلبات

```bash
node --version      # يجب أن يكون 18.x
npm --version       # 9+
firebase --version  # 13+

# إذا لم يكن مثبتاً:
npm install -g firebase-tools
```

### تسجيل الدخول وربط المشروع

```bash
firebase login
firebase use rafiq-app
```

### تشغيل المحاكي المحلي

```bash
cd functions
npm install
cd ..

# تشغيل جميع المحاكيات (Firestore + Functions + Auth)
firebase emulators:start

# المحاكي يعمل على:
# Firestore:  http://localhost:8080
# Functions:  http://localhost:5001
# Auth:       http://localhost:9099
# UI:         http://localhost:4000
```

### توجيه Stripe Webhooks للمحاكي

```bash
# في terminal منفصل:
stripe listen --forward-to http://localhost:5001/rafiq-app/me-central1/stripeWebhookHandler
# انسخ whsec_... وضعه في functions/.env
```

### النشر للإنتاج

```bash
# نشر كل شيء
firebase deploy

# أو نشر أجزاء محددة:
firebase deploy --only functions              # Cloud Functions فقط
firebase deploy --only firestore:rules        # قواعد الأمان فقط
firebase deploy --only firestore:indexes      # الفهارس فقط

# نشر function واحدة:
firebase deploy --only functions:createTrip

# التحقق من النشر:
firebase functions:list
```

### رفع بيانات المدن

```bash
node scripts/seedCities.js
# أو يدوياً عبر Firebase Console → Firestore → cities
```

---

## 4. فتح مشروع iOS وبناء ناجح

### المتطلبات

```
- macOS 14+ (Sonoma أو أحدث)
- Xcode 15.4+ (أو 16+)
- Apple Developer Account (لـ Push + Apple Pay)
- جهاز حقيقي للاختبار الكامل (Push لا يعمل على Simulator)
```

### خطوات البناء الأول

```
1. افتح Terminal في مجلد ios-app/

2. أنشئ مشروع Xcode جديد (إذا لم يكن موجوداً):
   - Open Xcode → New Project → App
   - Product Name: Rafiq
   - Bundle ID: com.rafiq.app
   - Language: Swift
   - Interface: SwiftUI
   - احفظه في مجلد ios-app/

3. أضف Swift Packages (File → Add Package Dependencies):
   - Firebase iOS SDK: https://github.com/firebase/firebase-ios-sdk (11.0.0+)
     ✓ FirebaseAuth, FirebaseFirestore, FirebaseFunctions, FirebaseMessaging, FirebaseStorage
   - Stripe iOS: https://github.com/stripe/stripe-ios (24.0.0+)
     ✓ StripePaymentSheet
   - Google Maps: https://github.com/nicklama/google-maps-ios-spm (9.0.0+)
     ✓ GoogleMaps

4. انسخ الملفات إلى المشروع:
   - اسحب جميع ملفات .swift إلى Xcode Navigator
   - فعّل "Copy items if needed" و "Create folder references"
   - رتبها حسب الـ PATH المكتوب في أعلى كل ملف

5. أضف Resource files:
   - GoogleService-Info.plist → Resources/
   - Keys.plist → Resources/
   - Info.plist → استبدل الموجود أو ادمج المحتوى
   - Rafiq.entitlements → Resources/
   - sa_cities.json → Resources/ (أنشئ من seedCities أو يدوياً)

6. Signing & Capabilities:
   - اختر Team (Apple Developer account)
   - أضف: Push Notifications
   - أضف: Background Modes → Remote notifications
   - أضف: Apple Pay → merchant.com.rafiq.app

7. Build Settings:
   - SWIFT_VERSION = 5.9
   - IPHONEOS_DEPLOYMENT_TARGET = 17.0

8. Build (⌘B):
   - إذا نجح: ✅ جاهز
   - إذا فشل: انظر قسم استكشاف الأخطاء أدناه
```

### أخطاء شائعة في البناء الأول

| الخطأ | الحل |
|-------|------|
| `Missing module 'FirebaseAuth'` | تأكد من إضافة Firebase SDK كـ Package Dependency |
| `Missing module 'StripePaymentSheet'` | أضف Stripe iOS SDK وحدد StripePaymentSheet |
| `Missing module 'GoogleMaps'` | أضف google-maps-ios-spm (nicklama proxy) |
| `No such file 'GoogleService-Info.plist'` | حمّله من Firebase Console وأضفه للمشروع |
| `Cannot find 'KeysManager'` | تأكد من وجود Keys.plist في Bundle |
| `Signing error` | اختر Team في Signing & Capabilities |
| `RafiqColors has no member` | تأكد أن Theme.swift مضاف للـ target |
| `Type 'AppUser' has no member` | تأكد أن Models.swift مضاف للـ target |
| Deployment target error | اضبط iOS 17.0 minimum |

### Fallback Colors

الملفات تستخدم `RafiqColors.primaryFallback` بدلاً من `RafiqColors.primary` لتجنب أخطاء Asset Catalog. إذا أردت استخدام Asset Catalog:
1. أنشئ Colors.xcassets
2. أضف الألوان بأسمائها
3. غيّر `Fallback` suffix في Theme.swift

---

## 5. سيناريوهات الاختبار

### ✅ السيناريو 1: إنشاء رحلة (سائق)

```
□ سجّل دخول برقم سعودي
□ اختر دور "سائق" أو "راكب وسائق" في التسجيل
□ أضف مركبة (الاسم، اللون، عدد المقاعد)
□ اضغط "أنشئ رحلة" من الصفحة الرئيسية
□ اختر: مدينة الانطلاق → مدينة الوصول
□ حدد: التاريخ والوقت (مستقبلي)
□ أدخل: السعر للمقعد (بالريال، يُحفظ بالهللات)
□ اختر: نوع نقطة التجمع (MAP_PIN / MANUAL_ADDRESS / DRIVER_PICKS_UP)
□ إذا MAP_PIN: حدد النقطة على الخريطة
□ اضغط "أنشئ" → تأكد أن الرحلة ظهرت في Firestore
□ تأكد: status=open, availableSeats=totalSeats
```

### ✅ السيناريو 2: البحث عن رحلة (راكب)

```
□ سجّل دخول بحساب راكب مختلف
□ من الصفحة الرئيسية → اختر مدينة الانطلاق والوصول
□ اختياري: حدد تاريخ
□ اضغط "ابحث عن رحلة"
□ تأكد: الرحلة المنشأة في السيناريو 1 تظهر في النتائج
□ جرّب الترتيب: بالتاريخ / بالسعر / بالتقييم
□ اضغط على بطاقة الرحلة → تفاصيل الرحلة تفتح
□ تأكد: كل المعلومات صحيحة (السعر، التاريخ، السائق، نقطة التجمع)
```

### ✅ السيناريو 3: حجز ودفع

```
□ من تفاصيل الرحلة، اضغط "احجز مقعدك"
□ اختر عدد المقاعد
□ إذا DRIVER_PICKS_UP: حدد موقعك على الخريطة
□ اختر طريقة الدفع (بطاقة أو Apple Pay)
□ تأكد: تحذير 3 ساعات ظاهر
□ تأكد: سياسة الإلغاء ظاهرة
□ اضغط "تأكيد ودفع"
□ PaymentSheet يظهر → أدخل بطاقة اختبارية: 4242 4242 4242 4242
□ تأكد: booking.status = pending_payment → confirmed
□ تأكد: booking.paymentStatus = paid
□ تأكد: trip.availableSeats نقصت بعدد المقاعد المحجوزة
□ تأكد: إشعار push وصل للسائق "حجز جديد"
□ تأكد: محادثة جديدة أُنشئت بين الراكب والسائق
```

### ✅ السيناريو 4: فشل الدفع

```
□ كرر السيناريو 3 لكن استخدم بطاقة: 4000 0000 0000 0002
□ تأكد: PaymentSheet يُظهر خطأ "رفض البطاقة"
□ تأكد: booking.paymentStatus = failed أو يبقى unpaid
□ تأكد: المقاعد لم تُحجز نهائياً
```

### ✅ السيناريو 5: انتهاء مهلة الدفع (3 ساعات)

```
□ أنشئ حجز بدون إكمال الدفع
□ انتظر تشغيل expirePendingBookings (أو شغّله يدوياً في المحاكي)
□ تأكد: booking.status = expired بعد 3 ساعات
□ تأكد: trip.availableSeats عادت للعدد الأصلي
□ تأكد: إشعار "انتهت مهلة الدفع" وصل للراكب
```

### ✅ السيناريو 6: إلغاء واسترداد

```
□ أنشئ حجز وادفع بنجاح (السيناريو 3)
□ اذهب لـ "رحلاتي" → الحجز المؤكد
□ اضغط "إلغاء الحجز"

  حالة أ — قبل 24 ساعة من الرحلة:
  □ تأكد: الرسالة "استرداد كامل"
  □ تأكد: booking.paymentStatus = refunded
  □ تأكد: Stripe Dashboard يُظهر Refund
  □ تأكد: trip.availableSeats عادت

  حالة ب — خلال 24 ساعة من الرحلة:
  □ تأكد: الرسالة "بدون استرداد" أو رفض الإلغاء
  □ تأكد: الحجز يبقى confirmed
```

### ✅ السيناريو 7: المحادثة

```
□ بعد تأكيد الحجز (السيناريو 3)
□ افتح تبويب "الرسائل"
□ تأكد: المحادثة مع السائق/الراكب ظاهرة
□ أرسل رسالة نصية → تأكد أنها تظهر فوراً (realtime)
□ اضغط زر الموقع → تأكد أن رابط الخريطة يُرسل
□ من الجهة الثانية: تأكد أن الرسالة وصلت + unread badge
□ افتح المحادثة → تأكد أن unread badge اختفى (markAsRead)
□ اضغط "إبلاغ" → تأكد أن Sheet الإبلاغ يفتح بالأسباب
```

### ✅ السيناريو 8: اكتمال الرحلة والتقييم

```
□ بعد تأكيد الحجز، انتظر مرور وقت الرحلة
□ انتظر completeTripAndOpenRatingWindow (أو شغّله يدوياً)
□ تأكد: trip.status = in_progress → completed
□ تأكد: booking.status = completed
□ تأكد: booking.ratingWindowStatus = open
□ تأكد: إشعار "قيّم رحلتك" وصل
□ اذهب لـ "رحلاتي" → الحجز المكتمل → "قيّم التجربة"
□ اختر نجوم (1-5) + تعليق اختياري
□ اضغط "إرسال" → تأكد أن التقييم حُفظ
□ تأكد: user.avgRating تحدّث
□ تأكد: بعد ساعتين → ratingWindowStatus = closed
□ لا يمكن تقييم مرتين (يرفض submitRating)
```

### ✅ السيناريو 9: الملف الشخصي والدعم

```
□ افتح تبويب "حسابي"
□ تأكد: الاسم + الرقم + التقييم ظاهرة
□ عدّل الاسم → تأكد أنه يتحدث في Firestore
□ اضغط "دعم السعودية 🇸🇦" → يفتح واتساب
□ اضغط "دعم اليمن 🇾🇪" → يفتح واتساب
□ اضغط "تسجيل الخروج" → يعود لشاشة الدخول
□ اضغط "شروط الاستخدام" → الصفحة تفتح بالعربي
□ اضغط "سياسة الخصوصية" → الصفحة تفتح بالعربي
```

### ✅ السيناريو 10: Deep Links والإشعارات

```
□ ارسل إشعار من Firebase Console بـ payload:
  {"type": "booking_confirmed", "bookingId": "xxx"}
□ اضغط على الإشعار → التطبيق يفتح على تفاصيل الحجز
□ جرّب URL scheme: rafiq://trip/{tripId} → يفتح تفاصيل الرحلة
□ جرّب: rafiq://support → يفتح صفحة الدعم
```

---

## 6. قواعد العمل الأساسية — مرجع سريع

| القاعدة | القيمة |
|---------|--------|
| العملة | ريال سعودي (SAR) |
| التخزين | بالهللات (1 ر.س = 100 هللة) |
| مهلة الدفع | 3 ساعات من إنشاء الحجز |
| الإلغاء مع استرداد | قبل 24 ساعة من الرحلة |
| الإلغاء بدون استرداد | خلال 24 ساعة من الرحلة |
| نافذة التقييم | ساعتان بعد اكتمال الرحلة |
| تأكيد الحجز النقدي | غير مدعوم في MVP (إلكتروني فقط) |
| المقاعد | تُدار حصرياً عبر Firestore Transactions |
| المنطقة | me-central1 (الدمام) |
| الدفع | بطاقة بنكية + Apple Pay عبر Stripe |

---

## 7. ما بعد الـ MVP — خطوات مستقبلية

```
□ Admin Dashboard (Next.js) — لوحة تحكم المشرفين
□ Driver verification — التحقق من رخصة السائق
□ Vehicle photos — صور المركبات
□ Push notification grouping — تجميع الإشعارات
□ Trip route map — عرض المسار على الخريطة
□ In-app calling — اتصال داخلي
□ Promo codes — أكواد خصم
□ Analytics dashboard — إحصائيات الاستخدام
□ Multi-language — إنجليزي + عربي toggle
□ App Store submission — رفع التطبيق
```

---

## 8. جهات الاتصال والدعم

```
المطور:      يونس
واتساب SA:   (من Keys.plist → WHATSAPP_SUPPORT_SA)
واتساب YE:   (من Keys.plist → WHATSAPP_SUPPORT_YE)
Firebase:    https://console.firebase.google.com
Stripe:      https://dashboard.stripe.com
Google Maps: https://console.cloud.google.com
```

---

**آخر تحديث**: مارس 2026
**الإصدار**: MVP 1.0.0
