// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Noteon';

  @override
  String get appTagline => 'ملاحظات بسيطة وآمنة، تُحفظ على جهازك';

  @override
  String get notes => 'الملاحظات';

  @override
  String get allNotes => 'كل الملاحظات';

  @override
  String get folders => 'المجلدات';

  @override
  String get tags => 'الوسوم';

  @override
  String get searchNotes => 'بحث في الملاحظات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'النظام';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get about => 'حول التطبيق';

  @override
  String get aboutDescription =>
      'Noteon تطبيق ملاحظات بسيط وآمن يحفظ بياناتك محلياً على جهازك.';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get emptyNotesTitle => 'لا توجد ملاحظات بعد';

  @override
  String get emptyNotesSubtitle => 'أنشئ ملاحظتك الأولى للبدء.';

  @override
  String get newNote => 'ملاحظة جديدة';

  @override
  String get untitledNote => 'بدون عنوان';

  @override
  String get emptyNotePreview => 'لا يوجد نص إضافي';

  @override
  String get lockedNotePreview => 'ملاحظة محمية';

  @override
  String get lockedNoteEditorMessage =>
      'هذه الملاحظة محمية. أدخل كلمة المرور لفتحها.';

  @override
  String get lockNote => 'قفل الملاحظة';

  @override
  String get lockNoteTitle => 'قفل هذه الملاحظة';

  @override
  String get lockNoteMessage =>
      'احمِ محتوى هذه الملاحظة بكلمة مرور. تُشفَّر الصور والرسومات أيضاً.';

  @override
  String get unlockNote => 'فتح القفل';

  @override
  String get unlockNoteTitle => 'فتح الملاحظة';

  @override
  String get removePassword => 'إزالة كلمة المرور';

  @override
  String get removePasswordTitle => 'إزالة كلمة المرور';

  @override
  String get removePasswordMessage =>
      'أدخل كلمة المرور لحفظ هذه الملاحظة بدون تشفير على هذا الجهاز.';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get passwordTooShort => 'استخدم ٤ أحرف على الأقل.';

  @override
  String get passwordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get incorrectPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get lockFailed => 'تعذّر قفل الملاحظة. حاول مرة أخرى.';

  @override
  String get unlockFailed => 'تعذّر فتح الملاحظة. حاول مرة أخرى.';

  @override
  String get corruptLockedNote =>
      'بيانات هذه الملاحظة المحمية مفقودة أو تالفة ولا يمكن فتحها.';

  @override
  String get passwordNoRecoveryWarning =>
      'لا توجد طريقة لاستعادة كلمة المرور. إذا نسيتها، فلن يمكن فتح المحتوى المحمي لهذه الملاحظة.';

  @override
  String get togglePasswordVisibility => 'إظهار أو إخفاء كلمة المرور';

  @override
  String get editNote => 'ملاحظة';

  @override
  String get noteTitleHint => 'العنوان';

  @override
  String get noteBodyHint => 'ابدأ الكتابة…';

  @override
  String get deleteNoteTitle => 'حذف الملاحظة؟';

  @override
  String get deleteNoteMessage => 'ستُحذف هذه الملاحظة نهائياً من هذا الجهاز.';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get notesLoadError => 'تعذر تحميل الملاحظات. حاول مرة أخرى.';

  @override
  String get foldersLoadError => 'تعذر تحميل المجلدات. حاول مرة أخرى.';

  @override
  String get tagsLoadError => 'تعذر تحميل الوسوم. حاول مرة أخرى.';

  @override
  String get noteSaveFailed => 'تعذر حفظ الملاحظة. حاول مرة أخرى.';

  @override
  String get noteMissing => 'تعذر العثور على هذه الملاحظة.';

  @override
  String get noteLoadFailed => 'تعذر فتح هذه الملاحظة. حاول مرة أخرى.';

  @override
  String get databaseOpenErrorTitle => 'تعذر فتح التخزين المحلي';

  @override
  String get databaseOpenErrorMessage =>
      'تعذر على Noteon تهيئة قاعدة البيانات المحلية على هذا الجهاز. حاول مرة أخرى. إذا استمرت المشكلة، أعد تشغيل الجهاز. إعادة تثبيت التطبيق ستحذف الملاحظات المحلية.';

  @override
  String databaseOpenErrorCode(String code) {
    return 'رمز الخطأ: $code';
  }

  @override
  String get databaseOpenErrorDebugLabel => 'تفاصيل التشخيص (تطوير/ملف تعريف)';

  @override
  String get closeApp => 'إغلاق التطبيق';

  @override
  String get unfiledNotes => 'غير مصنّفة';

  @override
  String get clearFilters => 'مسح عوامل التصفية';

  @override
  String searchFilterLabel(String query) {
    return 'بحث: $query';
  }

  @override
  String get noMatchingNotes => 'لا توجد نتائج';

  @override
  String get noMatchingNotesSubtitle =>
      'جرّب بحثاً مختلفاً أو امسح عوامل التصفية النشطة.';

  @override
  String get dateGroupToday => 'اليوم';

  @override
  String get dateGroupYesterday => 'أمس';

  @override
  String get dateGroupThisWeek => 'هذا الأسبوع';

  @override
  String get dateGroupOlder => 'أقدم';

  @override
  String get organize => 'تنظيم';

  @override
  String get newFolder => 'مجلد جديد';

  @override
  String get newSubfolder => 'قسم فرعي جديد';

  @override
  String get renameFolder => 'إعادة تسمية المجلد';

  @override
  String get deleteFolderTitle => 'حذف المجلد؟';

  @override
  String get deleteFolderMessage =>
      'ستصبح الملاحظات داخل هذا المجلد غير مصنّفة. ستُحذف الأقسام الفرعية أيضاً.';

  @override
  String get folderNameHint => 'اسم المجلد';

  @override
  String get folderActionFailed => 'تعذر تحديث المجلد. حاول مرة أخرى.';

  @override
  String get save => 'حفظ';

  @override
  String get newTag => 'وسم جديد';

  @override
  String get renameTag => 'إعادة تسمية الوسم';

  @override
  String get deleteTagTitle => 'حذف الوسم؟';

  @override
  String get deleteTagMessage => 'سيُزال هذا الوسم من كل الملاحظات.';

  @override
  String get tagNameHint => 'اسم الوسم';

  @override
  String get tagActionFailed => 'تعذر تحديث الوسم. حاول مرة أخرى.';

  @override
  String get tagAlreadyExists => 'يوجد وسم بهذا الاسم مسبقاً.';

  @override
  String get addTag => 'إضافة وسم';

  @override
  String get noteFolder => 'المجلد';

  @override
  String get noteTags => 'الوسوم';

  @override
  String get noFolder => 'بدون مجلد';

  @override
  String get manageFolders => 'إدارة المجلدات';

  @override
  String get manageTags => 'إدارة الوسوم';

  @override
  String filterByTag(String name) {
    return 'وسم: $name';
  }

  @override
  String filterByFolder(String name) {
    return 'مجلد: $name';
  }

  @override
  String get create => 'إنشاء';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get emptyFolders => 'لا توجد مجلدات بعد';

  @override
  String get emptyFoldersSubtitle => 'أنشئ مجلداً لتنظيم ملاحظاتك.';

  @override
  String get emptyTags => 'لا توجد وسوم بعد';

  @override
  String get emptyTagsSubtitle =>
      'أنشئ وسوماً لتصنيف الملاحظات والعثور عليها بسرعة.';

  @override
  String get addImage => 'إضافة صورة';

  @override
  String get addImageFromGallery => 'اختيار من المعرض';

  @override
  String get addImageFromCamera => 'التقاط صورة';

  @override
  String get imageMissing => 'الصورة غير متاحة';

  @override
  String get imageImportFailed => 'تعذر إضافة الصورة. حاول مرة أخرى.';

  @override
  String get imagePermissionDenied =>
      'تم رفض الوصول إلى الصور. يمكنك تفعيله من إعدادات النظام.';

  @override
  String get addSketch => 'إضافة رسم';

  @override
  String get newSketch => 'رسم';

  @override
  String get sketchEmpty => 'ارسم شيئاً قبل الحفظ.';

  @override
  String get sketchSaveFailed => 'تعذر حفظ الرسم. حاول مرة أخرى.';

  @override
  String get undo => 'تراجع';

  @override
  String get redo => 'إعادة';

  @override
  String get clearCanvas => 'مسح';
}
