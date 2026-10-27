# بكلوريا أدبي — Flutter

تطبيق دروس وملخصات باللغة العربية مع وضع «اختبر نفسي» وتصدير PDF.

## هيكل المشروع

```
lib/
  main.dart                  نقطة البداية والثيم
  constants.dart             الاسم، الروابط، كلمات الدخول
  models.dart                نموذج الدرس
  utils.dart                 فتح الروابط والرسائل
  services/storage.dart      حفظ الدروس والإعدادات (SharedPreferences)
  services/pdf_export.dart   تصدير PDF
  screens/                   الدخول، القائمة، المحرر، القارئ
```

## التشغيل محلياً

```bash
flutter create --platforms=android --org com.bakloria --project-name dafatri .
flutter pub get
flutter run
```

## بناء APK تلقائياً (GitHub Actions)

1. ارفع **محتويات** هذا المجلد إلى جذر المستودع (يجب أن يظهر `pubspec.yaml` و`.github` مباشرة في الصفحة الرئيسية للمستودع).
2. افتح **Actions** ← **Build Flutter APK** ← **Run workflow**.
3. بعد النجاح حمّل الملف من **Artifacts** باسم `bakloria-adabi-apk`.

ملف الـ workflow يبحث عن `pubspec.yaml` تلقائياً، فيعمل حتى لو كان المشروع داخل مجلد فرعي.

## حدود مهمة

- الدروس والإعدادات محفوظة محلياً على الجهاز ولا تتزامن بين الأجهزة.
- «حظر وضع القارئ» محلي على هذا الجهاز فقط.
- كلمات المرور موجودة في الكود (`lib/constants.dart`) وليست حماية قوية؛ لا تعتمد عليها لبيانات حساسة.
- إذا كان المستودع عاماً فسيرى الجميع كلمات المرور؛ اجعله خاصاً (Private).
