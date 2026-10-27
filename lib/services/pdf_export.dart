import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';

/// يصدّر الدرس إلى PDF بصفحات A4 مطابقة لصفحات المحرر.
/// كل صفحة في المحرر = صفحة جديدة في PDF، والنص الزائد ينتقل تلقائياً.
Future<void> exportLessonPdf(Lesson lesson, {double fontSize = 13}) async {
  final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
  final font = pw.Font.ttf(fontData);
  final theme = pw.ThemeData.withFont(
    base: font,
    bold: font,
    italic: font,
    boldItalic: font,
  );

  final body = <pw.Widget>[
    pw.Text(
      lesson.title,
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 20),
    ),
    pw.SizedBox(height: 24),
  ];

  for (var i = 0; i < lesson.pages.length; i++) {
    if (i > 0) body.add(pw.NewPage());
    body.add(
      pw.Text(
        stripAnswerMarkers(lesson.pages[i]),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(fontSize: fontSize, lineSpacing: fontSize * 0.6),
      ),
    );
  }

  final watermark = lesson.watermark.trim();
  final footerNote = lesson.footerNote.trim();

  final doc = pw.Document(title: lesson.title, theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(42),
        theme: theme,
        buildBackground: (context) => watermark.isEmpty
            ? pw.SizedBox()
            : pw.Center(
                child: pw.Opacity(
                  opacity: .08,
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      watermark,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(fontSize: 38, color: PdfColors.grey),
                    ),
                  ),
                ),
              ),
      ),
      build: (context) => body,
      footer: (context) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (footerNote.isNotEmpty)
            pw.Text(
              footerNote,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          pw.SizedBox(height: 4),
          pw.Text('${context.pageNumber}', style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );

  final bytes = await doc.save();
  final name = lesson.title.trim().isEmpty ? 'lesson' : lesson.title.trim();
  try {
    await Printing.layoutPdf(name: name, onLayout: (format) async => bytes);
  } catch (_) {
    // بديل: مشاركة الملف مباشرة (حفظ/واتساب/ملفات) إن فشلت نافذة الطباعة.
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }
}
