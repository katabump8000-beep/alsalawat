import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';
import 'sheet_render.dart';

/// يصدّر الدرس إلى PDF: كل صفحة في المحرر = صفحة A4 مرسومة بنفس مظهرها
/// (السطور، العلامة المائية، العنوان الملوّن) كصورة عالية الدقة.
Future<void> exportLessonPdf(Lesson lesson) async {
  final doc = pw.Document(title: lesson.title);
  for (var i = 0; i < lesson.pages.length; i++) {
    final png = await renderSheetPng(lesson, i);
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

  final bytes = await doc.save();
  final name = lesson.title.trim().isEmpty ? 'lesson' : lesson.title.trim();
  try {
    await Printing.layoutPdf(name: name, onLayout: (format) async => bytes);
  } catch (_) {
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }
}
