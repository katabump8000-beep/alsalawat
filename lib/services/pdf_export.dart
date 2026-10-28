import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';
import 'sheet_render.dart';

/// يصدّر الدرس إلى PDF: غلاف أمامي (اختياري) + صفحات الدرس + غلاف خلفي (اختياري).
Future<void> exportLessonPdf(Lesson lesson) async {
  // نضمّن بيانات الدرس داخل الملف ليُعاد فتحه وتعديله من التطبيق.
  final payload = base64Encode(gzip.encode(utf8.encode(jsonEncode(lesson.toJson()))));
  final doc = pw.Document(
    title: lesson.title,
    creator: 'alsalawat',
    keywords: 'ALSALAWAT1:$payload:END',
  );

  void addImagePage(Uint8List png) {
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
        ),
        build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }

  Future<void> addCover(String path) async {
    if (path.isEmpty || !File(path).existsSync()) return;
    final png = await renderCoverPng(path);
    if (png != null) addImagePage(png);
  }

  await addCover(lesson.coverFront);
  for (var i = 0; i < lesson.pages.length; i++) {
    addImagePage(await renderSheetPng(lesson, i));
  }
  await addCover(lesson.coverBack);

  final bytes = await doc.save();
  final name = lesson.title.trim().isEmpty ? 'lesson' : lesson.title.trim();
  try {
    await Printing.layoutPdf(name: name, onLayout: (format) async => bytes);
  } catch (_) {
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }
}

/// يستخرج درساً من PDF صدّره التطبيق، أو من ملف JSON. يرجع null إن لم يجد بيانات.
Lesson? lessonFromBytes(Uint8List bytes) {
  try {
    final head = bytes.take(1).isEmpty ? 0 : bytes.first;
    if (head == 0x7b) {
      return Lesson.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map));
    }
    final text = latin1.decode(bytes, allowInvalid: true);
    const tag = 'ALSALAWAT1:';
    final a = text.indexOf(tag);
    if (a < 0) return null;
    final b = text.indexOf(':END', a);
    if (b < 0) return null;
    final raw = text.substring(a + tag.length, b).replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
    final map = jsonDecode(utf8.decode(gzip.decode(base64Decode(raw)))) as Map;
    return Lesson.fromJson(Map<String, dynamic>.from(map));
  } catch (_) {
    return null;
  }
}
