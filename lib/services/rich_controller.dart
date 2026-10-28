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

/// أحجام الخط المخصصة: [بداية، نهاية، حجم]...
List<int> encodeSizes(List<int> sz) {
  final out = <int>[];
  var i = 0;
  while (i < sz.length) {
    var j = i + 1;
    while (j < sz.length && sz[j] == sz[i]) {
      j++;
    }
    if (sz[i] != 0) out.addAll([i, j, sz[i]]);
    i = j;
  }
  return out;
}

List<int> decodeSizes(int len, List<int> runs) {
  final sz = List<int>.filled(len, 0, growable: true);
  for (var k = 0; k + 2 < runs.length; k += 3) {
    final s = math.min(math.max(runs[k], 0), len);
    final e = math.min(math.max(runs[k + 1], 0), len);
    for (var i = s; i < e; i++) {
      sz[i] = runs[k + 2];
    }
  }
  return sz;
}

/// مقاطع نص مُلوَّنة ومُظلَّلة ومتفاوتة الحجم لكل حرف. [strip] يحذف علامتي ⟦ ⟧.
List<TextSpan> richSpans(
  String text,
  List<int> fg,
  List<int> bg, {
  List<int>? sz,
  double sizeScale = 1,
  int start = 0,
  int? end,
  bool strip = false,
}) {
  final e = math.min(end ?? text.length, text.length);
  final out = <TextSpan>[];
  final buf = StringBuffer();
  var cf = 0, cb = 0, cs = 0;
  void flush() {
    if (buf.isEmpty) return;
    out.add(TextSpan(
      text: buf.toString(),
      style: (cf == 0 && cb == 0 && cs == 0)
          ? null
          : TextStyle(
              color: cf == 0 ? null : Color(cf),
              backgroundColor: cb == 0 ? null : Color(cb),
              fontSize: cs == 0 ? null : cs * sizeScale,
            ),
    ));
    buf.clear();
  }

  for (var i = start; i < e; i++) {
    final ch = text[i];
    if (strip && (ch == answerOpen || ch == answerClose)) continue;
    final f = i < fg.length ? fg[i] : 0;
    final b = i < bg.length ? bg[i] : 0;
    final s = (sz != null && i < sz.length) ? sz[i] : 0;
    if (f != cf || b != cb || s != cs) {
      flush();
      cf = f;
      cb = b;
      cs = s;
    }
    buf.write(ch);
  }
  flush();
  return out;
}

class _Snap {
  _Snap(this.t, this.f, this.b, this.z, this.s);
  final String t;
  final List<int> f, b, z;
  final TextSelection s;
}

/// حقل نص يحفظ لون وتظليل وحجم كل حرف على حدة، مع تراجع/إعادة خاصّين به.
class RichController extends TextEditingController {
  RichController({String text = '', List<int>? runs, List<int>? sizes}) : super(text: text) {
    final d = decodeRuns(text.length, runs ?? const []);
    fg = d.fg;
    bg = d.bg;
    sz = decodeSizes(text.length, sizes ?? const []);
    _record(force: true);
  }

  late List<int> fg;
  late List<int> bg;
  late List<int> sz;

  /// تنسيق الحروف التي ستُكتب لاحقاً (0 = الافتراضي).
  int curFg = 0, curBg = 0, curSz = 0;
  bool explicit = false;

  // ---- التراجع والإعادة ----
  final List<_Snap> _hist = [];
  int _pos = -1;
  bool _applying = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  bool get canUndo => _pos > 0;
  bool get canRedo => _pos >= 0 && _pos < _hist.length - 1;

  _Snap _snap() => _Snap(text, List.of(fg), List.of(bg), List.of(sz), selection);

  void _record({bool force = false}) {
    if (_applying) return;
    final s = _snap();
    if (_pos < _hist.length - 1) {
      _hist.removeRange(_pos + 1, _hist.length);
    }
    final now = DateTime.now();
    if (!force && _pos > 0 && now.difference(_last).inMilliseconds < 800) {
      _hist[_pos] = s; // دمج الكتابة المتتابعة في خطوة واحدة
    } else {
      _hist.add(s);
      _pos++;
      if (_hist.length > 200) {
        _hist.removeAt(0);
        _pos--;
      }
    }
    _last = now;
  }

  void _restore(_Snap s) {
    _applying = true;
    fg = List.of(s.f);
    bg = List.of(s.b);
    sz = List.of(s.z);
    super.value = TextEditingValue(text: s.t, selection: s.s);
    _applying = false;
    explicit = false;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _pos--;
    _restore(_hist[_pos]);
  }

  void redo() {
    if (!canRedo) return;
    _pos++;
    _restore(_hist[_pos]);
  }

  // ---- تغيّر القيمة ----
  @override
  set value(TextEditingValue v) {
    final old = text;
    final textChanged = old != v.text;
    if (textChanged) {
      _splice(old, v.text);
    } else if (v.selection != value.selection) {
      explicit = false;
      if (v.selection.isValid && v.selection.isCollapsed) {
        final o = v.selection.baseOffset;
        if (o > 0 && o <= fg.length) {
          curFg = fg[o - 1];
          curSz = sz[o - 1];
        } else {
          curFg = 0;
          curSz = 0;
        }
        curBg = 0; // التظليل لا يمتد تلقائياً إلى ما تكتبه بعده
      }
    }
    super.value = v;
    if (textChanged) _record();
  }

  void _splice(String old, String neu) {
    if (fg.length != old.length || bg.length != old.length || sz.length != old.length) {
      List<int> fix(List<int> a) =>
          List<int>.generate(old.length, (i) => i < a.length ? a[i] : 0, growable: true);
      fg = fix(fg);
      bg = fix(bg);
      sz = fix(sz);
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
    sz.replaceRange(p, oldEnd, List<int>.filled(ins, curSz));
  }

  void _applyRange(List<int> a, int start, int end, int v) {
    for (var i = math.max(0, start); i < math.min(end, a.length); i++) {
      a[i] = v;
    }
    _record(force: true);
    notifyListeners();
  }

  void applyFg(int start, int end, int color) => _applyRange(fg, start, end, color);
  void applyBg(int start, int end, int color) => _applyRange(bg, start, end, color);
  void applySize(int start, int end, int size) => _applyRange(sz, start, end, size);

  /// يضبط النص والتنسيق معاً دون تحليل الفروق (للنقل بين الصفحات).
  void setContent(
    String t,
    List<int> f,
    List<int> b,
    TextSelection sel, {
    List<int>? z,
    bool record = true,
  }) {
    fg = f;
    bg = b;
    sz = z ?? List<int>.filled(t.length, 0, growable: true);
    super.value = TextEditingValue(text: t, selection: sel);
    if (record) {
      _record(force: true);
    } else if (_pos >= 0) {
      _hist[_pos] = _snap(); // تعديل آلي: لا يُحسب خطوة تراجع جديدة
    }
  }

  /// يحيط المحدد بعلامتين دون فقدان تلوينه.
  void wrap(int s, int e, String open, String close) {
    final t = text;
    List<int> w(List<int> a) => [...a.sublist(0, s), 0, ...a.sublist(s, e), 0, ...a.sublist(e)];
    setContent(
      '${t.substring(0, s)}$open${t.substring(s, e)}$close${t.substring(e)}',
      w(fg),
      w(bg),
      TextSelection.collapsed(offset: e + 2),
      z: w(sz),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(style: style, children: richSpans(text, fg, bg, sz: sz));
  }
}
