import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import 'rich_controller.dart';

/// هندسة الصفحة (مشتركة بين المحرر والتصدير ليتطابقا تماماً).
const double kA4Width = 595;
const double kA4Ratio = 1.4142;
const double kMargin = 42;
const double kTitleBlock = 46;
const double kFooterBlock = 28;
const String kFont = 'NotoSansArabic';

TextStyle sheetTextStyle(double fontPt, double scale, Color ink, double lf) => TextStyle(
      fontFamily: kFont,
      color: ink,
      fontSize: fontPt * scale,
      height: lf,
    );

StrutStyle sheetStrut(double fontPt, double scale, double lf) => StrutStyle(
      fontFamily: kFont,
      fontSize: fontPt * scale,
      height: lf,
      forceStrutHeight: false,
    );

/// بُعد خط الأساس الحقيقي للسطر الأول عن أعلى منطقة النص (يُقاس ولا يُقدَّر).
double firstBaseline(double fontPt, double scale, double lf) {
  final tp = TextPainter(
    text: TextSpan(text: 'ا', style: sheetTextStyle(fontPt, scale, Colors.black, lf)),
    textDirection: TextDirection.rtl,
    strutStyle: sheetStrut(fontPt, scale, lf),
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

Future<ui.Image?> _loadImage(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _finish(ui.PictureRecorder rec, double w, double h) async {
  final image = await rec.endRecording().toImage(w.round(), h.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void _centerText(Canvas c, String text, TextStyle style, Rect r, {int? maxLines}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(minWidth: r.width, maxWidth: r.width);
  c.save();
  c.clipRect(r);
  tp.paint(c, Offset(r.left, r.top + (r.height - tp.height) / 2));
  c.restore();
  tp.dispose();
}

Future<void> _drawObject(Canvas c, PageObject o, double s) async {
  final r = Rect.fromLTWH(o.x * s, o.y * s, o.w * s, o.h * s);
  if (o.type == 'image') {
    final img = await _loadImage(o.path);
    if (img == null) return;
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      r,
      Paint()..filterQuality = FilterQuality.high,
    );
    img.dispose();
  } else if (o.type == 'table') {
    final cw = r.width / o.cols, ch = r.height / o.rows;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8 * s
      ..color = Colors.black38;
    for (var row = 0; row < o.rows; row++) {
      for (var col = 0; col < o.cols; col++) {
        // العمود الأول عند اليمين (اتجاه عربي)
        final cell = Rect.fromLTWH(r.right - (col + 1) * cw, r.top + row * ch, cw, ch);
        c.drawRect(cell, Paint()..color = Color(row == 0 ? o.header : o.fill));
        c.drawRect(cell, line);
        _centerText(
          c,
          o.cell(row, col),
          TextStyle(fontFamily: kFont, fontSize: 12 * s, color: Color(o.textColor)),
          cell.deflate(3 * s),
          maxLines: 3,
        );
      }
    }
  } else {
    final fill = Paint()..color = Color(o.fill);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s
      ..color = Colors.black26;
    if (o.shape == 'circle') {
      c.drawOval(r, fill);
      c.drawOval(r, border);
    } else {
      final rr = RRect.fromRectAndRadius(r, Radius.circular((o.shape == 'rect' ? 0 : 12) * s));
      c.drawRRect(rr, fill);
      c.drawRRect(rr, border);
    }
    _centerText(
      c,
      o.text,
      TextStyle(fontFamily: kFont, fontSize: 14 * s, height: 1.5, color: Color(o.textColor)),
      r.deflate(8 * s),
    );
  }
}

/// صورة غلاف تملأ صفحة A4 كاملة (قص بنمط cover).
Future<Uint8List?> renderCoverPng(String path, {double scale = 3.2}) async {
  final img = await _loadImage(path);
  if (img == null) return null;
  final w = kA4Width * scale, h = w * kA4Ratio;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
  final src = Size(img.width.toDouble(), img.height.toDouble());
  final fs = applyBoxFit(BoxFit.cover, src, Size(w, h));
  c.drawImageRect(
    img,
    Alignment.center.inscribe(fs.source, Offset.zero & src),
    Alignment.center.inscribe(fs.destination, Rect.fromLTWH(0, 0, w, h)),
    Paint()..filterQuality = FilterQuality.high,
  );
  img.dispose();
  return _finish(rec, w, h);
}

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
  final lf = l.lineFactor;

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
      lineHeight: l.fontPt * lf * scale,
      textTop: pad + titleH,
      baseline: firstBaseline(l.fontPt, scale, lf),
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

  // الصور والبطاقات والجداول (تحت النص ليُكتب فوقها)
  for (final o in l.pageObjects[index]) {
    await _drawObject(c, o, scale);
  }

  // النص (مع لون كل حرف وتظليله)
  final raw = l.pages[index];
  final fmt = decodeRuns(raw.length, l.pageRuns[index]);
  final sizes = decodeSizes(raw.length, l.pageSizes[index]);
  final body = TextPainter(
    text: TextSpan(
      style: sheetTextStyle(l.fontPt, scale, Color(l.inkColor), lf),
      children: richSpans(raw, fmt.fg, fmt.bg, sz: sizes, sizeScale: scale, strip: true),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.right,
    strutStyle: sheetStrut(l.fontPt, scale, lf),
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

  return _finish(rec, w, h);
}
