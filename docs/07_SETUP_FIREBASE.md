# رفيق — إعداد Firebase

> PATH: docs/
> FILENAME: 07_SETUP_FIREBASE.md

---

## المتطلبات

- حساب Google (Gmail)
- متصفح ويب

---

## الخطوة 1: إنشاء مشروع Firebase

1. افتح https://console.firebase.google.com
2. اضغط **Create a project** (إنشاء مشروع)
3. اسم المشروع: `rafiq-app`
4. أوقف Google Analytics (غير مطلوب للـ MVP)
5. اضغط **Create project**
6. انتظر حتى يكتمل الإنشاء ثم اضغط **Continue**

---

## الخطوة 2: تفعيل Authentication

1. من القائمة الجانبية اختر **Build → Authentication**
2. اضغط **Get started**
3. في تبويب **Sign-in method**، اضغط **Phone**
4. فعّل الخيار ثم اضغط **Save**
5. في تبويب **Settings → Authorized domains**: تأكد أن نطاقك مضاف

---

## الخطوة 3: إنشاء Firestore Database

1. من القائمة اختر **Build → Firestore Database**
2. اضغط **Create database**
3. اختر الموقع: **me-central1 (Dammam)** — مهم جداً
4. اختر **Start in production mode**
5. اضغط **Create**

بعد الإنشاء:
- ستقوم لاحقاً بنشر قواعد الأمان من ملف `firestore.rules`
- لا تعدّل القواعد يدوياً من الواجهة

---

## الخطوة 4: إضافة تطبيق iOS

1. من صفحة المشروع الرئيسية، اضغط أيقونة **iOS** (التفاحة)
2. أدخل Bundle ID: `com.rafiq.app`
3. App nickname: `Rafiq iOS`
4. اضغط **Register app**
5. حمّل ملف **GoogleService-Info.plist**
6. انقل الملف إلى: `ios-app/Rafiq/Resources/GoogleService-Info.plist`
7. في Xcode: اسحب الملف إلى المشروع مع تفعيل "Copy items if needed"
8. اضغط **Next** حتى تنتهي الخطوات

---

## الخطوة 5: تفعيل Cloud Functions

1. من القائمة اختر **Build → Functions**
2. اضغط **Get started**
3. سيُطلب منك الترقية إلى **Blaze plan** (الدفع حسب الاستخدام)
4. أضف بطاقة دفع — الاستخدام المنخفض مجاني عملياً
5. بعد الترقية، Functions جاهزة للنشر

---

## الخطوة 6: تفعيل Cloud Storage (اختياري - للصور)

1. من القائمة اختر **Build → Storage**
2. اضغط **Get started**
3. اختر **Start in production mode**
4. الموقع: **me-central1**

---

## الخطوة 7: نشر القواعد والبيانات

من Terminal في مجلد المشروع:

```bash
# تسجيل الدخول
firebase login

# ربط المشروع
firebase use rafiq-app

# نشر قواعد Firestore
firebase deploy --only firestore:rules

# نشر Cloud Functions
cd functions && npm install && cd ..
firebase deploy --only functions

# رفع بيانات المدن (يدوياً أو بسكربت)
node scripts/seedCities.js
```

---

## الخطوة 8: التحقق

1. افتح Firebase Console → Firestore → تأكد أن المجموعات موجودة
2. افتح Functions → تأكد أن جميع الدوال منشورة في me-central1
3. افتح Authentication → تأكد أن Phone مفعّل

---

## ملاحظات مهمة

- **المنطقة**: كل شيء يجب أن يكون في `me-central1` (الدمام)
- **Blaze Plan**: مطلوب لـ Cloud Functions و Stripe webhooks
- **GoogleService-Info.plist**: لا ترفعه على Git — أضفه في `.gitignore`
- **المفاتيح**: لا تشارك مفاتيح Firebase مع أحد
