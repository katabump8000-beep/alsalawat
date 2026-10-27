import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';

/// يرمّز التنسيق: [بداية، نهاية، لونالنص، لونالتظليل] للمقاطع غير الافتراضية فقط.
List<int> encodeRuns(List<int> fg, List<int> bg) {
  final out = <int>[];
  var i = 0;
  while (i < fg.length) {
    var j = i + 1;
    while (j < fg.length && fg[j] == fg[i] && bg[j] == bg[i]) {
      j++;
    }
    if (fg[i] != 0 || bg[i] != 0) out.addAll([i, j, fg[i], bg[i]]);
    i = j;
  }
  return out;
}

({List<int> fg, List<int> bg}) decodeRuns(int len, List<int> runs) {
  final fg = List<int>.filled(len, 0, growable: true);
  final bg = List<int>.filled(len, 0, growable: true);
  for (var k = 0; k + 3 < runs.length; k += 4) {
    final s = math.min(math.max(runs[k], 0), len);
    final e = math.min(math.max(runs[k + 1], 0), len);
    for (var i = s; i < e; i++) {
      fg[i] = runs[k + 2];
      bg[i] = runs[k + 3];
    }
  }
  return (fg: fg, bg: bg);
}

/// مقاطع نص مُلوَّنة لكل حرف. [strip] يحذف علامتي ⟦ ⟧.
List<TextSpan> richSpans(
  String text,
  List<int> fg,
  List<int> bg, {
  int start = 0,
  int? end,
  bool strip = false,
}) {
  final e = math.min(end ?? text.length, text.length);
  final out = <TextSpan>[];
  final buf = StringBuffer();
  var cf = 0, cb = 0;
  void flush() {
    if (buf.isEmpty) return;
    out.add(TextSpan(
      text: buf.toString(),
      style: (cf == 0 && cb == 0)
          ? null
          : TextStyle(
              color: cf == 0 ? null : Color(cf),
              backgroundColor: cb == 0 ? null : Color(cb),
            ),
    ));
    buf.clear();
  }

  for (var i = start; i < e; i++) {
    final ch = text[i];
    if (strip && (ch == answerOpen || ch == answerClose)) continue;
    final f = i < fg.length ? fg[i] : 0;
    final b = i < bg.length ? bg[i] : 0;
    if (f != cf || b != cb) {
      flush();
      cf = f;
      cb = b;
    }
    buf.write(ch);
  }
  flush();
  return out;
}

/// حقل نص يحفظ لون كل حرف على حدة: ما كُتب بلون يبقى بلونه مهما غيّرت اللون بعده.
class RichController extends TextEditingController {
  RichController({String text = '', List<int>? runs}) : super(text: text) {
    final d = decodeRuns(text.length, runs ?? const []);
    fg = d.fg;
    bg = d.bg;
  }

  late List<int> fg;
  late List<int> bg;

  /// تنسيق الحروف التي ستُكتب لاحقاً (0 = الافتراضي).
  int curFg = 0, curBg = 0;
  bool explicit = false;

  @override
  set value(TextEditingValue v) {
    final old = text;
    if (old != v.text) {
      _splice(old, v.text);
    } else if (v.selection != value.selection) {
      explicit = false;
      if (v.selection.isValid && v.selection.isCollapsed) {
        final o = v.selection.baseOffset;
        if (o > 0 && o <= fg.length) {
          curFg = fg[o - 1];
          curBg = bg[o - 1];
        } else {
          curFg = 0;
          curBg = 0;
        }
      }
    }
    super.value = v;
  }

  void _splice(String old, String neu) {
    if (fg.length != old.length) {
      fg = List<int>.generate(old.length, (i) => i < fg.length ? fg[i] : 0);
      bg = List<int>.generate(old.length, (i) => i < bg.length ? bg[i] : 0);
    }
    var p = 0;
    final m = math.min(old.length, neu.length);
    while (p < m && old.codeUnitAt(p) == neu.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < m - p &&
        old.codeUnitAt(old.length - 1 - s) == neu.codeUnitAt(neu.length - 1 - s)) {
      s++;
    }
    final oldEnd = old.length - s;
    final ins = neu.length - s - p;
    fg.replaceRange(p, oldEnd, List<int>.filled(ins, curFg));
    bg.replaceRange(p, oldEnd, List<int>.filled(ins, curBg));
  }

  void applyFg(int start, int end, int color) {
    for (var i = math.max(0, start); i < math.min(end, fg.length); i++) {
      fg[i] = color;
    }
    notifyListeners();
  }

  void applyBg(int start, int end, int color) {
    for (var i = math.max(0, start); i < math.min(end, bg.length); i++) {
      bg[i] = color;
    }
    notifyListeners();
  }

  /// يضبط النص والتنسيق معاً دون تحليل الفروق (للنقل بين الصفحات).
  void setContent(String t, List<int> f, List<int> b, TextSelection sel) {
    fg = f;
    bg = b;
    super.value = TextEditingValue(text: t, selection: sel);
  }

  /// يحيط المحدد بعلامتين دون فقدان تلوينه.
  void wrap(int s, int e, String open, String close) {
    final t = text;
    setContent(
      '${t.substring(0, s)}$open${t.substring(s, e)}$close${t.substring(e)}',
      [...fg.sublist(0, s), 0, ...fg.sublist(s, e), 0, ...fg.sublist(e)],
      [...bg.sublist(0, s), 0, ...bg.sublist(s, e), 0, ...bg.sublist(e)],
      TextSelection.collapsed(offset: e + 2),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(style: style, children: richSpans(text, fg, bg));
  }
}
