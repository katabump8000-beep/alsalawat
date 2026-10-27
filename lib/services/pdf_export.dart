import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';
import 'sheet_render.dart';

/// يصدّر الدرس إلى PDF: غلاف أمامي (اختياري) + صفحات الدرس + غلاف خلفي (اختياري).
Future<void> exportLessonPdf(Lesson lesson) async {
  final doc = pw.Document(title: lesson.title);

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
