# رفيق — إعداد Google Maps

> PATH: docs/
> FILENAME: 10_SETUP_MAPS.md

---

## المتطلبات

- حساب Google (Gmail)
- بطاقة دفع (Google Cloud يوفر $200 رصيد مجاني)

---

## الخطوة 1: إنشاء مشروع Google Cloud

1. افتح https://console.cloud.google.com
2. اضغط **Select a project** → **New Project**
3. اسم المشروع: `rafiq-maps`
4. اضغط **Create**
5. تأكد أنك اخترت المشروع الجديد من القائمة العلوية

إذا كنت تستخدم نفس مشروع Firebase:
- Firebase ينشئ مشروع Google Cloud تلقائياً باسم `rafiq-app`
- يمكنك استخدامه مباشرة بدلاً من إنشاء مشروع جديد

---

## الخطوة 2: تفعيل Billing

1. اذهب إلى **Billing** في القائمة الجانبية
2. اربط حساب فوترة أو أنشئ واحد جديد
3. أدخل بطاقة الدفع
4. Google Cloud يوفر **$200 رصيد مجاني** للأشهر الأولى
5. Maps SDK يوفر **$200/شهر مجاناً** (حوالي 28,000 طلب خريطة)

---

## الخطوة 3: تفعيل Maps SDK for iOS

1. اذهب إلى **APIs & Services → Library**
2. ابحث عن **Maps SDK for iOS**
3. اضغط عليه ثم اضغط **Enable**
4. ابحث أيضاً عن **Geocoding API** وفعّله (للعناوين)

---

## الخطوة 4: إنشاء API Key

1. اذهب إلى **APIs & Services → Credentials**
2. اضغط **Create Credentials → API key**
3. سيظهر مفتاح جديد — انسخه مؤقتاً

### تقييد المفتاح (مهم للأمان):

1. اضغط على المفتاح الذي أنشأته
2. في **Name**: سمّه `Rafiq iOS Maps Key`
3. في **Application restrictions**:
   - اختر **iOS apps**
   - اضغط **Add** وأدخل Bundle ID: `com.rafiq.app`
4. في **API restrictions**:
   - اختر **Restrict key**
   - اختر: **Maps SDK for iOS** و **Geocoding API**
5. اضغط **Save**

---

## الخطوة 5: إضافة المفتاح للتطبيق

1. افتح `ios-app/Rafiq/Resources/Keys.plist`
2. عدّل القيمة:

```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>AIzaSy_xxxxxxxxxxxxxxxxxxxxxxx</string>
```

---

## الخطوة 6: تهيئة Maps في التطبيق

المفتاح يُحمّل تلقائياً في `RafiqApp.swift` عبر:

```swift
// في AppDelegate أو RafiqApp.init
GoogleMapsSetup.configure()
```

هذا يستدعي `GMSServices.provideAPIKey()` باستخدام المفتاح من Keys.plist.

---

## الخطوة 7: اختبار الخريطة

1. شغّل التطبيق على **جهاز حقيقي** أو **Simulator**
2. اذهب لشاشة إنشاء رحلة واختر نقطة التجمع
3. يجب أن تظهر خريطة Google مع إمكانية تحريك الـ pin
4. عند تثبيت الموقع، يجب أن يظهر العنوان (Reverse Geocoding)

### على Simulator:

- الخريطة تعمل على Simulator
- لتغيير الموقع: **Features → Location → Custom Location**
- أدخل إحداثيات الرياض: `24.7136, 46.6753`

---

## الخطوة 8: مراقبة الاستخدام

1. اذهب إلى **APIs & Services → Dashboard**
2. اضغط على **Maps SDK for iOS**
3. تبويب **Metrics** يُظهر عدد الطلبات
4. تبويب **Quotas** يُظهر الحدود

### الحدود المجانية:

| الخدمة | مجاني شهرياً | بعدها |
|--------|-------------|-------|
| Maps SDK for iOS | 28,000 load | $7/1000 |
| Geocoding API | 40,000 request | $5/1000 |

للتطبيق الصغير، هذه الحدود أكثر من كافية.

---

## الخطوة 9: إعداد Budget Alert (اختياري)

لتجنب مفاجآت الفواتير:

1. اذهب إلى **Billing → Budgets & alerts**
2. اضغط **Create Budget**
3. حدد مبلغ (مثلاً $50)
4. فعّل التنبيهات عند 50%, 90%, 100%
5. أضف إيميلك للتنبيه

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| الخريطة رمادية بدون تفاصيل | المفتاح غير صحيح أو Maps SDK غير مفعّل |
| خطأ "API key not valid" | تأكد من تقييدات المفتاح (Bundle ID) |
| العنوان لا يظهر | تأكد من تفعيل Geocoding API |
| الخريطة بطيئة | طبيعي في أول تحميل — Google يخزّنها مؤقتاً |
| لا تعمل على Simulator M1 | حدّث Xcode وGoogle Maps SDK لآخر إصدار |
| رسالة "This app is not authorized" | تأكد أن Bundle ID في تقييد المفتاح يطابق المشروع |

---

## ملخص الملفات المطلوبة

| الملف | المحتوى |
|-------|---------|
| `Keys.plist` | `GOOGLE_MAPS_API_KEY` |
| `GoogleMapsModule.swift` | `GoogleMapsSetup.configure()` |
| `RafiqApp.swift` | يستدعي `GoogleMapsSetup.configure()` |

لا ترفع `Keys.plist` على Git!
