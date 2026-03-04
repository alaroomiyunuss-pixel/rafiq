# رفيق — إعداد الإشعارات (Push Notifications)

> PATH: docs/
> FILENAME: 08_SETUP_PUSH.md

---

## المتطلبات

- حساب Apple Developer ($99/سنة): https://developer.apple.com
- Xcode مثبت على Mac
- مشروع Firebase جاهز (انظر 07_SETUP_FIREBASE.md)

---

## الخطوة 1: إنشاء APNs Key في Apple Developer

1. افتح https://developer.apple.com/account
2. اذهب إلى **Certificates, Identifiers & Profiles**
3. من القائمة اختر **Keys**
4. اضغط **+** لإنشاء مفتاح جديد
5. الاسم: `Rafiq Push Key`
6. فعّل **Apple Push Notifications service (APNs)**
7. اضغط **Continue** ثم **Register**
8. **حمّل الملف** (.p8) — لن تتمكن من تحميله مرة أخرى!
9. سجّل **Key ID** (يظهر في الصفحة)
10. سجّل **Team ID** من أعلى الصفحة أو من Membership

---

## الخطوة 2: رفع المفتاح في Firebase

1. افتح Firebase Console → مشروع rafiq-app
2. اذهب إلى **Project Settings** (أيقونة الترس)
3. تبويب **Cloud Messaging**
4. في قسم **Apple app configuration**، اضغط **Upload** بجانب APNs Authentication Key
5. ارفع ملف `.p8` الذي حمّلته
6. أدخل **Key ID** و **Team ID**
7. اضغط **Upload**

---

## الخطوة 3: إعداد App ID

1. في Apple Developer، اذهب إلى **Identifiers**
2. ابحث عن `com.rafiq.app` أو أنشئ واحد جديد
3. تأكد أن **Push Notifications** مفعّل (علامة خضراء)
4. إذا لم يكن مفعّلاً: اضغط عليه → فعّل Push Notifications → Save

---

## الخطوة 4: إعداد Xcode

1. افتح المشروع في Xcode
2. اختر target **Rafiq**
3. تبويب **Signing & Capabilities**
4. اضغط **+ Capability**
5. أضف **Push Notifications**
6. أضف **Background Modes** وفعّل **Remote notifications**
7. تأكد أن ملف `Rafiq.entitlements` يحتوي على:

```xml
<key>aps-environment</key>
<string>development</string>
```

عند رفع التطبيق للـ App Store، غيّرها إلى `production`.

---

## الخطوة 5: اختبار الإشعارات

### من Firebase Console:

1. اذهب إلى **Engage → Messaging**
2. اضغط **Create your first campaign**
3. اختر **Firebase Notification messages**
4. اكتب عنوان ونص الإشعار
5. اضغط **Send test message**
6. أدخل FCM Token للجهاز (يظهر في console log عند تشغيل التطبيق)
7. اضغط **Test**

### من Terminal (باستخدام curl):

```bash
# استبدل FCM_TOKEN و SERVER_KEY بقيمك
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN",
    "notification": {
      "title": "رفيق",
      "body": "تجربة إشعار"
    }
  }'
```

---

## الخطوة 6: التحقق

تأكد من التالي:
- التطبيق يطلب إذن الإشعارات عند أول تشغيل
- FCM Token يظهر في console log
- FCM Token يُحفظ في Firestore (users/{uid}/fcmToken)
- الإشعارات تصل والتطبيق في الخلفية (background)
- الإشعارات تظهر كـ banner والتطبيق في المقدمة (foreground)
- الضغط على الإشعار يفتح الصفحة الصحيحة (deep link)

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---------|------|
| لا يظهر طلب الإذن | تأكد من استدعاء `requestPermission()` |
| لا يصل الإشعار | تأكد من رفع ملف .p8 في Firebase |
| Token فارغ | تأكد من Background Modes + Push Notifications capability |
| يعمل على Simulator فقط | الإشعارات تعمل على الأجهزة الحقيقية فقط |
| إشعار يصل بدون صوت | تأكد من `sound: "default"` في payload |
