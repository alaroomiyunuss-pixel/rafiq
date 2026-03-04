# رفيق — إعداد Stripe (المدفوعات)

> PATH: docs/
> FILENAME: 09_SETUP_STRIPE.md

---

## المتطلبات

- حساب Stripe: https://dashboard.stripe.com/register
- مشروع Firebase جاهز مع Cloud Functions
- حساب Apple Developer (لـ Apple Pay)

---

## الخطوة 1: إنشاء حساب Stripe

1. افتح https://dashboard.stripe.com/register
2. سجّل بإيميلك
3. أكمل بيانات النشاط التجاري (يمكنك البدء بـ Test Mode)
4. **مهم**: فعّل العملة **SAR** (ريال سعودي):
   - اذهب إلى **Settings → Account details**
   - تأكد أن البلد **Saudi Arabia** أو أضف SAR كعملة

---

## الخطوة 2: الحصول على المفاتيح

### Test Mode (للتطوير):

1. في Dashboard، تأكد أن **Test mode** مفعّل (الزر في أعلى اليمين)
2. اذهب إلى **Developers → API keys**
3. انسخ:
   - **Publishable key**: `pk_test_...`
   - **Secret key**: `sk_test_...`

### Live Mode (للإنتاج):

1. أوقف Test mode
2. انسخ المفاتيح الحقيقية: `pk_live_...` و `sk_live_...`
3. لا تستخدم المفاتيح الحقيقية أثناء التطوير!

---

## الخطوة 3: إعداد مفاتيح Backend

1. افتح ملف `functions/.env`:

```
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxx
```

2. للإنتاج، استخدم Firebase secrets:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
# أدخل: sk_live_...

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# أدخل: whsec_...
```

---

## الخطوة 4: إعداد مفتاح iOS

1. افتح `ios-app/Rafiq/Resources/Keys.plist`
2. عدّل القيمة:

```xml
<key>STRIPE_PUBLISHABLE_KEY</key>
<string>pk_test_xxxxxxxxxxxxxxx</string>
```

---

## الخطوة 5: إعداد Webhook

Webhook يُبلغ تطبيقك عندما تنجح أو تفشل عملية دفع.

### الحصول على URL:

بعد نشر Cloud Functions:

```bash
firebase deploy --only functions:stripeWebhookHandler
```

سيظهر URL مثل:
```
https://me-central1-rafiq-app.cloudfunctions.net/stripeWebhookHandler
```

### تسجيل Webhook في Stripe:

1. اذهب إلى **Developers → Webhooks**
2. اضغط **Add endpoint**
3. الصق URL الخاص بالـ function
4. في **Events to send**، اختر:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
5. اضغط **Add endpoint**
6. انسخ **Signing secret** (يبدأ بـ `whsec_`)
7. أضفه في `.env` كـ `STRIPE_WEBHOOK_SECRET`

### للتطوير المحلي:

```bash
# تثبيت Stripe CLI
brew install stripe/stripe-cli/stripe

# تسجيل الدخول
stripe login

# توجيه webhooks للمحاكي
stripe listen --forward-to http://localhost:5001/rafiq-app/me-central1/stripeWebhookHandler

# انسخ signing secret من الخرج وضعه في .env
```

---

## الخطوة 6: إعداد Apple Pay

### في Apple Developer:

1. اذهب إلى **Identifiers → Merchant IDs**
2. اضغط **+** لإنشاء Merchant ID جديد
3. الوصف: `Rafiq Payments`
4. Identifier: `merchant.com.rafiq.app`
5. اضغط **Continue** ثم **Register**

### في Stripe Dashboard:

1. اذهب إلى **Settings → Payments → Apple Pay**
2. اضغط **Add new domain** (لو عندك موقع ويب)
3. Apple Pay عبر iOS SDK لا يحتاج domain verification

### في Xcode:

1. افتح **Signing & Capabilities**
2. أضف **Apple Pay** capability
3. فعّل `merchant.com.rafiq.app`
4. تأكد من وجوده في `Rafiq.entitlements`

---

## الخطوة 7: اختبار المدفوعات

### بطاقات اختبارية (Test Mode):

| البطاقة | السلوك |
|---------|--------|
| `4242 4242 4242 4242` | نجاح دائماً |
| `4000 0000 0000 0002` | رفض دائماً |
| `4000 0025 0000 3155` | يتطلب 3D Secure |
| `4000 0000 0000 9995` | رصيد غير كافٍ |

- تاريخ الانتهاء: أي تاريخ مستقبلي
- CVC: أي 3 أرقام
- الرمز البريدي: أي 5 أرقام

### اختبار Apple Pay:

1. Apple Pay في Test Mode يعمل على أجهزة حقيقية فقط
2. أضف بطاقة اختبارية في Wallet على جهاز التطوير
3. استخدم Sandbox Apple ID

---

## الخطوة 8: التحقق

تأكد من التالي:
- PaymentSheet يظهر بالخيارات (بطاقة + Apple Pay)
- الدفع بـ `4242...` ينجح → booking.status = confirmed
- الدفع بـ `4000...0002` يفشل → booking.paymentStatus = failed
- Webhook يصل → تحقق في Stripe Dashboard → Webhooks → Recent events
- الإشعارات تصل بعد نجاح/فشل الدفع

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| PaymentSheet لا يظهر | تأكد من clientSecret صحيح من Cloud Function |
| Webhook لا يصل | تأكد من URL صحيح + whsec_ صحيح |
| Apple Pay لا يظهر | تأكد من Merchant ID + capability في Xcode |
| خطأ "currency not supported" | فعّل SAR في Stripe Dashboard |
| خطأ 401 في Cloud Function | تأكد من STRIPE_SECRET_KEY صحيح |
