import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';

const String _font = 'NotoSansArabic';

/// يرسم عنصراً (صورة/بطاقة/جدول) بمقياس [s]. يُستخدم في المحرر والقارئ.
Widget buildObjectWidget(PageObject o, double s) {
  switch (o.type) {
    case 'image':
      return File(o.path).existsSync()
          ? Image.file(File(o.path), fit: BoxFit.fill, filterQuality: FilterQuality.medium)
          : const ColoredBox(color: Colors.black12, child: Center(child: Icon(Icons.broken_image)));
    case 'table':
      return _table(o, s);
    default:
      return _card(o, s);
  }
}

Widget _card(PageObject o, double s) {
  final circle = o.shape == 'circle';
  return Container(
    alignment: Alignment.center,
    padding: EdgeInsets.all(8 * s),
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: Color(o.fill),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular((o.shape == 'rect' ? 0 : 12) * s),
      border: Border.all(color: Colors.black26, width: 1.2 * s),
    ),
    child: Text(
      o.text,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: TextStyle(fontFamily: _font, fontSize: 14 * s, height: 1.5, color: Color(o.textColor)),
    ),
  );
}

Widget _table(PageObject o, double s) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Column(
      children: [
        for (var r = 0; r < o.rows; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < o.cols; c++)
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(3 * s),
                      decoration: BoxDecoration(
                        color: r == 0 ? Color(o.header) : Color(o.fill),
                        border: Border.all(color: Colors.black38, width: .8 * s),
                      ),
                      child: Text(
                        o.cell(r, c),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 12 * s,
                          color: Color(o.textColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
