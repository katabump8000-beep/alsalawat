import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';

/// هندسة الصفحة (مشتركة بين المحرر والتصدير ليتطابقا تماماً).
const double kA4Width = 595;
const double kA4Ratio = 1.4142;
const double kMargin = 42;
const double kTitleBlock = 46;
const double kFooterBlock = 28;
const double kLineFactor = 1.8;
const String kFont = 'NotoSansArabic';

TextStyle sheetTextStyle(double fontPt, double scale, Color ink) => TextStyle(
      fontFamily: kFont,
      color: ink,
      fontSize: fontPt * scale,
      height: kLineFactor,
    );

StrutStyle sheetStrut(double fontPt, double scale) => StrutStyle(
      fontFamily: kFont,
      fontSize: fontPt * scale,
      height: kLineFactor,
      forceStrutHeight: true,
    );

/// بُعد خط الأساس الحقيقي للسطر الأول عن أعلى منطقة النص (يُقاس ولا يُقدَّر).
double firstBaseline(double fontPt, double scale) {
  final tp = TextPainter(
    text: TextSpan(text: 'ا', style: sheetTextStyle(fontPt, scale, Colors.black)),
    textDirection: TextDirection.rtl,
    strutStyle: sheetStrut(fontPt, scale),
  )..layout();
  final b = tp.computeLineMetrics().first.baseline;
  tp.dispose();
  return b;
}

void paintLines(
  Canvas canvas,
  Size size, {
  required double opacity,
  required double lineHeight,
  required double textTop,
  required double baseline,
  required double gap,
  required double bottomInset,
  required double stroke,
}) {
  final paint = Paint()
    ..color = Colors.blueGrey.withValues(alpha: opacity)
    ..strokeWidth = stroke;
  final limit = size.height - bottomInset + 0.5;
  for (double y = textTop + baseline + gap; y <= limit; y += lineHeight) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

class LinesPainter extends CustomPainter {
  LinesPainter({
    required this.opacity,
    required this.lineHeight,
    required this.textTop,
    required this.baseline,
    required this.gap,
    required this.bottomInset,
  });

  final double opacity, lineHeight, textTop, baseline, gap, bottomInset;

  @override
  void paint(Canvas canvas, Size size) => paintLines(
        canvas,
        size,
        opacity: opacity,
        lineHeight: lineHeight,
        textTop: textTop,
        baseline: baseline,
        gap: gap,
        bottomInset: bottomInset,
        stroke: .8,
      );

  @override
  bool shouldRepaint(covariant LinesPainter o) =>
      o.opacity != opacity ||
      o.lineHeight != lineHeight ||
      o.textTop != textTop ||
      o.baseline != baseline ||
      o.gap != gap ||
      o.bottomInset != bottomInset;
}

TextPainter _tp(String text, TextStyle style, {int? maxLines}) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    );

/// يرسم صفحة [index] من الدرس بنفس مظهر المحرر ويرجعها PNG عالي الدقة.
Future<Uint8List> renderSheetPng(Lesson l, int index, {double scale = 4.2}) async {
  final w = kA4Width * scale;
  final h = w * kA4Ratio;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

  final pad = kMargin * scale;
  final titleH = index == 0 ? kTitleBlock * scale : 0.0;
  final footerH = kFooterBlock * scale;
  final textW = w - 2 * pad;

  // العلامة المائية
  final wm = l.watermark.trim();
  if (wm.isNotEmpty) {
    final tp = _tp(
      wm,
      TextStyle(
        fontFamily: kFont,
        fontSize: l.wmSize * scale,
        fontWeight: FontWeight.bold,
        color: Color(l.wmColor).withValues(alpha: l.wmOpacity),
      ),
    )..layout();
    c.save();
    c.translate(w / 2, h / 2);
    c.rotate(-0.5);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
    tp.dispose();
  }

  // السطور
  if (l.lineOpacity > 0) {
    paintLines(
      c,
      Size(w, h),
      opacity: l.lineOpacity,
      lineHeight: l.fontPt * kLineFactor * scale,
      textTop: pad + titleH,
      baseline: firstBaseline(l.fontPt, scale),
      gap: l.fontPt * .18 * scale,
      bottomInset: pad + footerH,
      stroke: .8 * scale,
    );
  }

  // العنوان
  if (index == 0) {
    final box = Rect.fromLTWH(pad, pad, textW, titleH);
    if ((l.titleBg >> 24) != 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(6 * scale)),
        Paint()..color = Color(l.titleBg),
      );
    }
    final tp = _tp(
      l.title,
      TextStyle(fontFamily: kFont, fontSize: 20 * scale, color: Color(l.titleColor)),
      maxLines: 1,
    )..layout(maxWidth: textW);
    tp.paint(c, Offset(pad + (textW - tp.width) / 2, pad + (titleH - tp.height) / 2));
    tp.dispose();
  }

  // النص
  final body = TextPainter(
    text: TextSpan(
      text: stripAnswerMarkers(l.pages[index]),
      style: sheetTextStyle(l.fontPt, scale, Color(l.inkColor)),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.right,
    strutStyle: sheetStrut(l.fontPt, scale),
  )..layout(minWidth: textW, maxWidth: textW);
  c.save();
  c.clipRect(Rect.fromLTWH(0, pad + titleH, w, h - 2 * pad - titleH - footerH));
  body.paint(c, Offset(pad, pad + titleH));
  c.restore();
  body.dispose();

  // التذييل ورقم الصفحة
  final pageNo = _tp('${index + 1}', TextStyle(fontFamily: kFont, fontSize: 10 * scale, color: Colors.black54))
    ..layout();
  final numY = h - pad * .35 - pageNo.height;
  pageNo.paint(c, Offset((w - pageNo.width) / 2, numY));
  final note = l.footerNote.trim();
  if (note.isNotEmpty) {
    final nt = _tp(note, TextStyle(fontFamily: kFont, fontSize: 8 * scale, color: Colors.black45), maxLines: 1)
      ..layout(maxWidth: textW);
    nt.paint(c, Offset((w - nt.width) / 2, numY - nt.height));
    nt.dispose();
  }
  pageNo.dispose();

  final image = await rec.endRecording().toImage(w.round(), h.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
