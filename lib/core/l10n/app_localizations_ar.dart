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
  String get subfolders => 'المجلدات الفرعية';

  @override
  String get tags => 'الوسوم';

  @override
  String get searchNotes => 'بحث في الملاحظات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get displayName => 'الاسم';

  @override
  String get displayNameHint => 'اسمك';

  @override
  String get displayNameEmpty => 'أضف اسمك';

  @override
  String get editDisplayNameTitle => 'اسمك';

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
  String versionBuildLabel(String version, String build) {
    return 'الإصدار $version (البناء $build)';
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
  String noteTagCount(int count) {
    return '$count وسوم';
  }

  @override
  String get noteFolder => 'المجلد';

  @override
  String get noteTags => 'الوسوم';

  @override
  String get noFolder => 'بدون مجلد';

  @override
  String get moveToFolder => 'نقل إلى مجلد';

  @override
  String notesSelectedCount(int count) {
    return '$count محددة';
  }

  @override
  String get selectAllNotes => 'تحديد الكل';

  @override
  String get enterSelectionMode => 'الدخول إلى وضع التحديد';

  @override
  String get unsavedChanges => 'تغييرات غير محفوظة';

  @override
  String notesMovedMessage(int count) {
    return 'تم نقل $count ملاحظات';
  }

  @override
  String get notesMoveFailed => 'تعذر نقل الملاحظات. حاول مرة أخرى.';

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

  @override
  String get sketchPen => 'قلم';

  @override
  String get sketchHighlighter => 'قلم تظليل';

  @override
  String get sketchEraser => 'ممحاة';

  @override
  String get sketchLasso => 'تحديد حر';

  @override
  String get inkDrawingLabel => 'رسم';

  @override
  String get inkDeleteSelected => 'حذف المحدد';

  @override
  String get inkLassoHint => 'ارسم حول الخطوط للتحديد، ثم اسحب للنقل.';

  @override
  String inkLassoSelected(int count) {
    return '$count محدد — اسحب للنقل';
  }

  @override
  String get addPdf => 'إضافة PDF';

  @override
  String get pdfDocumentLabel => 'مستند PDF';

  @override
  String get pdfTapToAnnotate => 'انقر مرتين أو عدّل للتعليق';

  @override
  String get pdfMissing => 'ملف PDF غير متاح';

  @override
  String get pdfImportFailed => 'تعذر إضافة ملف PDF. حاول مرة أخرى.';

  @override
  String get pdfAnnotateSaveFailed => 'تعذر حفظ التعليقات. حاول مرة أخرى.';

  @override
  String pdfPageLabel(int page) {
    return 'صفحة $page';
  }

  @override
  String get insertTable => 'إدراج جدول';

  @override
  String get insertTableTitle => 'إدراج جدول';

  @override
  String get insertTableMessage => 'اختر عدد الصفوف والأعمدة للبداية.';

  @override
  String get tableRows => 'الصفوف';

  @override
  String get tableColumns => 'الأعمدة';

  @override
  String get tableLabel => 'جدول';

  @override
  String get tableTitleHint => 'عنوان الجدول';

  @override
  String get tableTitleOptional => 'اختياري';

  @override
  String get tableActions => 'إجراءات الجدول';

  @override
  String get tableAddRow => 'إضافة صف';

  @override
  String get tableRemoveRow => 'حذف صف';

  @override
  String get tableAddColumn => 'إضافة عمود';

  @override
  String get tableRemoveColumn => 'حذف عمود';

  @override
  String get deleteTable => 'حذف الجدول';

  @override
  String get deleteTableTitle => 'حذف الجدول؟';

  @override
  String get deleteTableMessage =>
      'سيُزال الجدول من الملاحظة. لا يمكن التراجع عن ذلك.';

  @override
  String get notesViewList => 'عرض قائمة';

  @override
  String get notesViewGrid => 'عرض شبكة';

  @override
  String get blockMoveUp => 'تحريك لأعلى';

  @override
  String get blockMoveDown => 'تحريك لأسفل';

  @override
  String get resizeImage => 'تغيير حجم الصورة';

  @override
  String get replaceImage => 'استبدال الصورة';

  @override
  String get editBlock => 'تعديل';

  @override
  String get resizeImageTitle => 'حجم الصورة';

  @override
  String get resizeImageMessage => 'اضبط حجم عرض الصورة. يُحتفظ بالملف الأصلي.';

  @override
  String get deleteBlockTitle => 'حذف هذا العنصر؟';

  @override
  String get deleteBlockMessage => 'يزيل هذا العنصر المحدد فقط من الملاحظة.';

  @override
  String get addAudio => 'إضافة صوت';

  @override
  String get recordAudioTitle => 'تسجيل صوت';

  @override
  String get recordAudioMessage =>
      'اضغط تسجيل، ثم أدرج المقطع في هذه الملاحظة.';

  @override
  String get audioStartRecording => 'تسجيل';

  @override
  String get audioStop => 'إيقاف';

  @override
  String get insertAudio => 'إدراج';

  @override
  String get audioLabel => 'صوت';

  @override
  String get audioPlay => 'تشغيل';

  @override
  String get audioPause => 'إيقاف مؤقت';

  @override
  String get audioMissing => 'الصوت غير متاح';

  @override
  String get audioPlayFailed => 'تعذر تشغيل هذا الصوت.';

  @override
  String get audioRecordFailed => 'تعذر تسجيل الصوت. حاول مرة أخرى.';

  @override
  String get audioPermissionDenied =>
      'تم رفض الوصول إلى الميكروفون. يمكنك تفعيله من إعدادات النظام.';

  @override
  String get shareNote => 'مشاركة';

  @override
  String get shareAsText => 'مشاركة كنص';

  @override
  String get shareAsImage => 'مشاركة كصورة';

  @override
  String get shareAsPdf => 'مشاركة كملف PDF';

  @override
  String get shareEmptyNote => 'ملاحظة فارغة';

  @override
  String get shareFailed => 'تعذر مشاركة هذه الملاحظة. حاول مرة أخرى.';

  @override
  String get ocrImage => 'نسخ النص من الصورة';

  @override
  String get ocrTitle => 'نص من الصورة';

  @override
  String get ocrInsert => 'إدراج في الملاحظة';

  @override
  String get ocrCopy => 'نسخ';

  @override
  String get ocrProgress => 'جارٍ قراءة النص…';

  @override
  String get ocrUnsupported =>
      'التعرّف على النص على الجهاز متاح على Android و iOS.';

  @override
  String get ocrNoText => 'لم يُعثر على نص في هذه الصورة.';

  @override
  String get ocrFailed => 'تعذر قراءة النص من هذه الصورة.';

  @override
  String get ocrCopied => 'تم النسخ إلى الحافظة.';

  @override
  String get assistNote => 'مساعدة محلية';

  @override
  String get assistTidy => 'تنظيف المسافات';

  @override
  String get assistTidySubtitle =>
      'إزالة المسافات والأسطر الفارغة الزائدة (التحديد).';

  @override
  String get assistBullets => 'تحويل إلى قائمة نقطية';

  @override
  String get assistBulletsSubtitle => 'جعل كل سطر نقطة قائمة (التحديد).';

  @override
  String get assistFirstLine => 'فصل السطر الأول';

  @override
  String get assistFirstLineSubtitle =>
      'إضافة سطر فارغ بعد السطر الأول (التحديد).';

  @override
  String get assistSelectText => 'حدّد نصاً في الملاحظة أولاً.';

  @override
  String get assistApplied => 'طُبّق محلياً — لم يُرسل شيء إلى السحابة.';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get privacyOcrTitle => 'تعرّف نص على الجهاز';

  @override
  String get privacyOcrSubtitle =>
      'قراءة النص من الصور تعمل على هذا الهاتف. لا يُرفع شيء.';

  @override
  String get privacyAssistTitle => 'مساعدة محلية';

  @override
  String get privacyAssistSubtitle =>
      'أدوات التنظيف والقوائم تعمل على الجهاز دون ذكاء اصطناعي سحابي.';

  @override
  String get privacyExportTitle => 'المشاركة والتصدير';

  @override
  String get privacyExportSubtitle =>
      'ملفات PDF والمشاركات تبقى على جهازك حتى تختار تطبيقاً لإرسالها.';

  @override
  String get notePageBackground => 'خلفية صفحة الملاحظة';

  @override
  String get notePageBackgroundPlain => 'عادية';

  @override
  String get notePageBackgroundLined => 'مسطّرة';

  @override
  String get notePageBackgroundGrid => 'شبكة';

  @override
  String get backupTransfer => 'النسخ الاحتياطي والنقل';

  @override
  String get backupExportEncrypted => 'تصدير نسخة مشفّرة';

  @override
  String get backupExportEncryptedSubtitle =>
      'أنشئ ملف .noteonbak محمياً بكلمة مرور لنقله إلى هاتف آخر.';

  @override
  String get backupImportEncrypted => 'استيراد نسخة مشفّرة';

  @override
  String get backupImportEncryptedSubtitle =>
      'استعد الملاحظات من ملف .noteonbak.';

  @override
  String get backupExportTitle => 'تصدير النسخة الاحتياطية';

  @override
  String get backupExportMessage =>
      'اختر عبارة مرور لتشفير هذه النسخة. تبقى الملاحظات المقفلة مقفلة وتحتفظ بكلمات مرورها.';

  @override
  String get backupPassphraseNoRecoveryWarning =>
      'لا توجد طريقة لاستعادة عبارة المرور. إذا نسيتها، فلن يمكن فتح هذه النسخة.';

  @override
  String get backupPassphraseLabel => 'عبارة مرور النسخة الاحتياطية';

  @override
  String get backupExportAction => 'تصدير';

  @override
  String get backupExportProgress => 'جارٍ إنشاء النسخة المشفّرة…';

  @override
  String get backupExportReady => 'النسخة جاهزة للمشاركة.';

  @override
  String get backupExportFailed =>
      'تعذر إنشاء النسخة الاحتياطية. حاول مرة أخرى.';

  @override
  String get backupShareSubject => 'نسخة Noteon احتياطية';

  @override
  String get backupImportTitle => 'استيراد النسخة الاحتياطية';

  @override
  String get backupImportPassphraseMessage =>
      'أدخل عبارة المرور المستخدمة عند إنشاء هذه النسخة.';

  @override
  String get backupImportAction => 'استيراد';

  @override
  String get backupImportProgress => 'جارٍ استيراد النسخة…';

  @override
  String get backupImportFailed =>
      'تعذر استيراد النسخة الاحتياطية. حاول مرة أخرى.';

  @override
  String get backupIncorrectPassphrase => 'عبارة مرور النسخة غير صحيحة.';

  @override
  String get backupCorruptFile =>
      'ملف النسخة مفقود أو تالف أو ليس نسخة Noteon.';

  @override
  String backupImportSuccess(int count) {
    return 'تم استيراد $count ملاحظة.';
  }

  @override
  String get backupImportModeTitle => 'كيف تريد استيراد الملاحظات؟';

  @override
  String get backupImportModeMessage =>
      'الدمج يحتفظ بملاحظاتك الحالية. الاستبدال يحذف كل شيء على هذا الجهاز أولاً.';

  @override
  String get backupImportModeMerge => 'دمج';

  @override
  String get backupImportModeMergeSubtitle =>
      'أضف ملاحظات النسخة بجانب الملاحظات الحالية.';

  @override
  String get backupImportModeReplace => 'استبدال المكتبة';

  @override
  String get backupImportModeReplaceSubtitle =>
      'احذف كل الملاحظات والمجلدات والوسوم المحلية، ثم استعد النسخة.';

  @override
  String get backupReplaceConfirmWord => 'REPLACE';

  @override
  String backupReplaceConfirmPrompt(String word) {
    return 'اكتب $word لتأكيد استبدال كل شيء على هذا الجهاز.';
  }

  @override
  String get backupReplaceConfirmLabel => 'التأكيد';

  @override
  String get backupReplaceConfirmMismatch => 'نص التأكيد غير مطابق.';

  @override
  String get nearbySendTitle => 'إرسال إلى جهاز قريب';

  @override
  String get nearbySendSubtitle =>
      'اعرض رمز QR ليتلقى هاتف آخر على نفس شبكة Wi‑Fi هذه النسخة.';

  @override
  String get nearbyReceiveTitle => 'استلام من جهاز قريب';

  @override
  String get nearbyReceiveSubtitle =>
      'امسح رمز QR للمرسل، أكد الرمز، ثم استورد.';

  @override
  String get nearbySendMessage =>
      'أبقِ هذه الشاشة مفتوحة. يجب أن يكون الهاتفان على نفس شبكة Wi‑Fi.';

  @override
  String get nearbyPreparing => 'جارٍ تجهيز النسخة المشفّرة…';

  @override
  String get nearbyWaitingReceiver =>
      'بانتظار أن يمسح الهاتف الآخر الرمز ويُنزّل النسخة…';

  @override
  String get nearbyTransferring => 'الجهاز المستلم يُنزّل النسخة…';

  @override
  String get nearbySendComplete => 'اكتمل النقل على هذا الهاتف.';

  @override
  String get nearbyMarkComplete => 'تم';

  @override
  String get nearbyDone => 'إغلاق';

  @override
  String get nearbySendFailed =>
      'تعذر بدء النقل القريب. تحقق من Wi‑Fi وحاول مرة أخرى.';

  @override
  String get nearbyNoWifiAddress =>
      'تعذر العثور على عنوان Wi‑Fi محلي. وصّل الهاتفين بنفس الشبكة وحاول مرة أخرى.';

  @override
  String get nearbyReceiveScanMessage =>
      'وجّه الكاميرا إلى رمز QR على هاتف المرسل.';

  @override
  String get nearbyConfirmMessage =>
      'تأكد أن هذا الرمز يطابق الرمز على هاتف المرسل قبل التنزيل.';

  @override
  String get nearbyVerifyCodeLabel => 'رمز التحقق';

  @override
  String get nearbyVerifyHint => 'قارن هذا الرمز على الهاتفين.';

  @override
  String get nearbyCodesMatch => 'الرمزان متطابقان — تنزيل';

  @override
  String get nearbyRescan => 'مسح مرة أخرى';

  @override
  String get nearbyDownloading => 'جارٍ تنزيل النسخة المشفّرة…';

  @override
  String get nearbyReceiveFailed =>
      'تعذر تنزيل النسخة. ابقَ على نفس شبكة Wi‑Fi وحاول مرة أخرى.';

  @override
  String get nearbyMethodQr => 'رمز QR';

  @override
  String get nearbyMethodNfc => 'NFC';

  @override
  String get nearbyReceiveNfcMessage =>
      'قرّب هذا الهاتف من بطاقة NFC التي كتبها المرسل. يمكنك استخدام QR أيضاً.';

  @override
  String get nearbyNfcWriteAction => 'كتابة الاقتران على بطاقة NFC';

  @override
  String get nearbyNfcWriteHint => 'ضع بطاقة NFC على ظهر هذا الهاتف…';

  @override
  String get nearbyNfcWriteSuccess => 'تم كتابة الاقتران على بطاقة NFC.';

  @override
  String get nearbyNfcWriteFailed =>
      'تعذر الكتابة على بطاقة NFC. حاول مرة أخرى أو استخدم رمز QR.';

  @override
  String get nearbyNfcCancel => 'إلغاء NFC';

  @override
  String get nearbyNfcListening => 'جاهز — قرّب البطاقة من بطاقة NFC للمرسل…';

  @override
  String get nearbyNfcReadFailed =>
      'تعذر قراءة بطاقة اقتران Noteon. حاول مرة أخرى أو استخدم QR.';

  @override
  String get nearbyNfcRetry => 'إعادة محاولة NFC';

  @override
  String get appLockSection => 'الأمان';

  @override
  String get appLockTitle => 'قفل التطبيق';

  @override
  String get appLockSubtitle => 'اطلب البصمة أو رمز PIN عند فتح Noteon';

  @override
  String get appLockUnlockWith => 'إلغاء القفل باستخدام';

  @override
  String get appLockMethodBiometrics => 'البصمة';

  @override
  String get appLockMethodPin => 'رمز PIN';

  @override
  String get appLockChangePin => 'تغيير رمز PIN';

  @override
  String get appLockReasonEnable => 'أكّد لتشغيل قفل التطبيق';

  @override
  String get appLockReasonUnlock => 'افتح Noteon';

  @override
  String get appLockReasonConfirm => 'أكّد هويتك لتغيير قفل التطبيق';

  @override
  String get appLockReasonReset => 'أكّد بقفل الشاشة لإعادة تعيين رمز PIN';

  @override
  String get appLockCreatePin => 'أنشئ رمز PIN';

  @override
  String get appLockConfirmPin => 'أدخل رمز PIN مرة أخرى';

  @override
  String get appLockPinMismatch => 'الرمزان غير متطابقين. حاول مرة أخرى.';

  @override
  String get appLockEnterPin => 'أدخل رمز PIN';

  @override
  String get appLockWrongPin => 'رمز PIN غير صحيح';

  @override
  String appLockTryAgainIn(int seconds) {
    return 'محاولات كثيرة. حاول مرة أخرى بعد $seconds ث.';
  }

  @override
  String get appLockUseBiometrics => 'استخدم البصمة';

  @override
  String get appLockForgotPin => 'نسيت رمز PIN؟';

  @override
  String get appLockNoScreenLockTitle => 'تعذّرت إعادة تعيين الرمز';

  @override
  String get appLockNoScreenLockBody =>
      'لا يحتوي هذا الجهاز على قفل شاشة، لذا لا يستطيع Noteon التأكد من هويتك.\n\n• فعّل قفل الشاشة من إعدادات الجهاز ثم اضغط «نسيت رمز PIN؟» مرة أخرى. لن يضيع شيء.\n• أو امسح بيانات Noteon من إعدادات الجهاز. يزيل ذلك الرمز لكنه يحذف أيضًا كل الملاحظات على هذا الجهاز، إلا إذا استعدت نسخة احتياطية مشفّرة.';

  @override
  String get appLockSetNewPinTitle => 'عيّن رمز PIN جديدًا';

  @override
  String get appLockSetNewPinBody =>
      'تم إيقاف قفل التطبيق. عيّن رمز PIN جديدًا لتشغيله مرة أخرى.';

  @override
  String get appLockLater => 'لاحقًا';

  @override
  String get appLockSetPin => 'تعيين الرمز';

  @override
  String get appLockNoBiometricsForPin => 'البصمة غير مفعّلة على هذا الجهاز.';

  @override
  String get appLockLockedTitle => 'Noteon مقفل';

  @override
  String appLockPinProgress(int entered, int total) {
    return 'تم إدخال $entered من $total أرقام';
  }

  @override
  String get appLockBackspace => 'حذف آخر رقم';

  @override
  String get appLockOk => 'حسنًا';
}
