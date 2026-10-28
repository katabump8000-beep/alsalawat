import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../services/media.dart';
import '../services/object_widgets.dart';
import '../services/pdf_export.dart';
import '../services/rich_controller.dart';
import '../services/sheet_render.dart' show LinesPainter, firstBaseline;
import '../services/sound.dart';
import '../services/storage.dart';
import '../services/symbols.dart';
import '../utils.dart';

/// أبعاد صفحة A4 بالنقاط (نفس أبعاد PDF) ليتطابق المحرر مع الملف الناتج.
const double _a4Width = 595;
const double _a4Ratio = 1.4142;
const double _margin = 42;
const double _titleBlock = 46;
const double _footerBlock = 28;
const String _fontFamily = 'NotoSansArabic';


const List<Color> _inkPalette = [
  paperInk,
  Colors.black,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
];

final List<Color> _allColors = [
  for (final m in Colors.primaries) ...[m.shade200, m.shade500, m.shade800],
  Colors.black,
  Colors.white,
  const Color(0xff424242),
  const Color(0xff757575),
  const Color(0xffbdbdbd),
  const Color(0xff795548),
  const Color(0xff3e2723),
  const Color(0xff00695c),
];

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.lesson, required this.onSave});

  final Lesson lesson;
  final Future<void> Function() onSave;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _title = TextEditingController(text: widget.lesson.title);
  late final TextEditingController _watermark = TextEditingController(text: widget.lesson.watermark);
  late final TextEditingController _footer = TextEditingController(text: widget.lesson.footerNote);
  late final TextEditingController _video = TextEditingController(text: widget.lesson.videoUrl);

  final List<RichController> _pages = [];
  final List<List<PageObject>> _objects = [];
  late double _lineFactor = widget.lesson.lineFactor;
  late String _coverFront = widget.lesson.coverFront;
  late String _coverBack = widget.lesson.coverBack;
  bool _fgMode = true;
  List<String> _favSymbols = [];
  final List<FocusNode> _nodes = [];

  int _active = 0;
  double _zoom = 1.0;
  late double _fontPt = widget.lesson.fontPt;
  double _lineOpacity = 0; // السطور محذوفة افتراضياً (يمكن إظهارها من المنزلق)
  bool _fitted = false;
  double _viewH = 600;
  bool _sizeBar = false;
  double? _pendSize;
  List<int> _recentColors = [];
  List<String> _recentSymbols = [];
  late Color _inkColor = Color(widget.lesson.inkColor);
  late double _wmSize = widget.lesson.wmSize;
  late double _wmOpacity = widget.lesson.wmOpacity;
  late Color _wmColor = Color(widget.lesson.wmColor);
  late Color _titleColor = Color(widget.lesson.titleColor);
  late Color _titleBg = Color(widget.lesson.titleBg);
  bool _dirty = false;
  bool _reflowing = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.lesson.pages.length; i++) {
      _addPageObjects(
        widget.lesson.pages[i],
        widget.lesson.pageRuns[i],
        List<PageObject>.of(widget.lesson.pageObjects[i]),
        widget.lesson.pageSizes[i],
      );
    }
    AppStorage.loadStrings('recentColors').then((v) {
      if (mounted) setState(() => _recentColors = v.map(int.tryParse).whereType<int>().toList());
    });
    AppStorage.loadStrings('recentSymbols').then((v) {
      if (mounted) setState(() => _recentSymbols = v);
    });
    AppStorage.loadFavSymbols().then((v) {
      if (mounted) setState(() => _favSymbols = v.toList());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reflowAll()) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _watermark, _footer, _video, ..._pages]) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- pages

  void _addPageObjects(String text, [List<int>? runs, List<PageObject>? objs, List<int>? sizes]) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) return;
      final idx = _nodes.indexOf(node);
      if (idx >= 0 && idx != _active && mounted) setState(() => _active = idx);
    });
    _pages.add(RichController(text: text, runs: runs, sizes: sizes));
    _objects.add(objs ?? <PageObject>[]);
    _nodes.add(node);
  }

  void _disposeLater(List<ChangeNotifier> items) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in items) {
        i.dispose();
      }
    });
  }

  void _addPage() {
    Sound.tap();
    setState(() {
      _addPageObjects('');
      _active = _pages.length - 1;
      _dirty = true;
    });
  }

  Future<void> _deletePage(int index) async {
    if (_pages.length <= 1) return;
    if (_pages[index].text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حذف الصفحة'),
          content: Text('هل تريد حذف الصفحة ${index + 1}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      final c = _pages.removeAt(index);
      final n = _nodes.removeAt(index);
      _objects.removeAt(index);
      _disposeLater([c, n]);
      if (_active >= _pages.length) _active = _pages.length - 1;
      _dirty = true;
    });
  }

  // ------------------------------------------------------------- geometry

  double _sheetWidth() => (MediaQuery.sizeOf(context).width - 24) * _zoom;

  TextStyle _textStyle(double scale) => TextStyle(
        fontFamily: _fontFamily,
        color: _inkColor,
        fontSize: _fontPt * scale,
        height: _lineFactor,
      );

  /// يفرض ارتفاعاً ثابتاً لكل سطر فتبقى الأسطر على الخطوط مهما اختلف الحرف.
  StrutStyle _strut(double scale) => StrutStyle(
        fontFamily: _fontFamily,
        fontSize: _fontPt * scale,
        height: _lineFactor,
        forceStrutHeight: false,
      );

  /// الارتفاع المتاح للنص في الصفحة [index] بمقياس [scale].
  double _availableHeight(int index, double scale) {
    final sheetH = _a4Width * scale * _a4Ratio;
    final reserved = 2 * _margin + _footerBlock + (index == 0 ? _titleBlock : 0);
    return sheetH - reserved * scale;
  }

  /// يرجع موضع القص إن كان النص أطول من الصفحة، وإلا null.
  int? _overflowOffset(RichController c, double maxWidth, double maxHeight, TextStyle style) {
    final text = c.text;
    if (text.isEmpty) return null;
    final tp = TextPainter(
      text: TextSpan(style: style, children: richSpans(text, c.fg, c.bg, sz: c.sz)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      strutStyle: _strut(1.0),
    )..layout(maxWidth: maxWidth);
    try {
      if (tp.height <= maxHeight + 0.5) return null;
      final metrics = tp.computeLineMetrics();
      var y = 0.0;
      var fit = 0;
      for (final m in metrics) {
        if (y + m.height > maxHeight + 0.5) break;
        y += m.height;
        fit++;
      }
      if (fit == 0) fit = 1;
      if (fit >= metrics.length) return null;
      final probe = Offset(0, y - metrics[fit - 1].height / 2);
      final pos = tp.getPositionForOffset(probe);
      final end = tp.getLineBoundary(pos).end;
      if (end <= 0 || end >= text.length) return null;
      return end;
    } finally {
      tp.dispose();
    }
  }

  /// ينقل الفائض من الصفحة [start] (وما بعدها) إلى الصفحات التالية.
  bool _reflow(int start) {
    if (_reflowing) return false;
    _reflowing = true;
    var changed = false;
    try {
      // التقسيم يتم دائماً بمقياس ثابت، فلا يتأثر بالتكبير أو التصغير إطلاقاً.
      const scale = 1.0;
      final textW = _a4Width - 2 * _margin;
      final style = _textStyle(scale);
      var idx = start;
      var guard = 0;
      while (idx < _pages.length && guard++ < 200) {
        final ctrl = _pages[idx];
        final text = ctrl.text;
        final cut = _overflowOffset(ctrl, textW, _availableHeight(idx, scale), style);
        if (cut == null) {
          idx++;
          continue;
        }
        changed = true;
        final sel = ctrl.selection;
        final cursor = sel.isValid ? sel.baseOffset : -1;

        var tail = text.substring(cut);
        var tfg = ctrl.fg.sublist(cut);
        var tbg = ctrl.bg.sublist(cut);
        var tsz = ctrl.sz.sublist(cut);
        var removed = 0;
        if (tail.startsWith('\n')) {
          tail = tail.substring(1);
          tfg = tfg.sublist(1);
          tbg = tbg.sublist(1);
          tsz = tsz.sublist(1);
          removed = 1;
        }
        if (idx + 1 >= _pages.length) {
          _addPageObjects('');
        }
        final next = _pages[idx + 1];
        final merged = next.text.isEmpty ? tail : '$tail\n${next.text}';
        final mfg = next.text.isEmpty ? tfg : [...tfg, 0, ...next.fg];
        final mbg = next.text.isEmpty ? tbg : [...tbg, 0, ...next.bg];
        final msz = next.text.isEmpty ? tsz : [...tsz, 0, ...next.sz];
        final headFg = ctrl.fg.sublist(0, cut);
        final headBg = ctrl.bg.sublist(0, cut);
        final headSz = ctrl.sz.sublist(0, cut);

        final cursorMoves = cursor > cut;
        ctrl.setContent(
          text.substring(0, cut),
          headFg,
          headBg,
          TextSelection.collapsed(offset: cursor < 0 ? cut : math.min(cursor, cut)),
          z: headSz,
          record: false,
        );
        final nextCursor = cursorMoves
            ? math.max(0, math.min(cursor - cut - removed, merged.length))
            : 0;
        next.setContent(merged, mfg, mbg, TextSelection.collapsed(offset: nextCursor), z: msz, record: false);
        if (cursorMoves) {
          final target = idx + 1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && target < _nodes.length) {
              _nodes[target].requestFocus();
            }
          });
        }
        idx++;
      }
    } finally {
      _reflowing = false;
    }
    return changed;
  }

  bool _reflowAll() => _reflow(0);

  void _onPageChanged(int index) {
    _reflow(index);
    setState(() => _dirty = true);
  }

  // -------------------------------------------------------------- actions

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save({bool silent = false}) async {
    final l = widget.lesson;
    final t = _title.text.trim();
    l.title = t.isEmpty ? 'درس بلا عنوان' : t;
    l.watermark = _watermark.text;
    l.footerNote = _footer.text;
    l.videoUrl = _video.text.trim();
    l.fontPt = _fontPt;
    l.lineOpacity = _lineOpacity;
    l.inkColor = _inkColor.toARGB32();
    l.wmSize = _wmSize;
    l.wmOpacity = _wmOpacity;
    l.wmColor = _wmColor.toARGB32();
    l.titleColor = _titleColor.toARGB32();
    l.titleBg = _titleBg.toARGB32();
    l.pages = _pages.map((p) => p.text).toList();
    l.pageRuns = _pages.map((p) => encodeRuns(p.fg, p.bg)).toList();
    l.pageSizes = _pages.map((p) => encodeSizes(p.sz)).toList();
    l.pageObjects = _objects.map((e) => List<PageObject>.of(e)).toList();
    l.lineFactor = _lineFactor;
    l.coverFront = _coverFront;
    l.coverBack = _coverBack;
    await widget.onSave();
    if (!mounted) return;
    setState(() => _dirty = false);
    if (!silent) {
      Sound.success();
      showMessage(context, 'تم حفظ الدرس');
    }
  }

  Future<void> _exportPdf() async {
    await _save(silent: true);
    try {
      await exportLessonPdf(widget.lesson);
    } catch (e) {
      if (mounted) showMessage(context, 'تعذر إنشاء PDF: $e');
    }
  }

  void _addAnswerMarker() {
    final c = _pages[_active];
    final s = c.selection;
    if (!s.isValid || s.isCollapsed) {
      showMessage(context, 'حدد كلمة أو عبارة أولاً');
      return;
    }
    Sound.tap();
    c.wrap(s.start, s.end, answerOpen, answerClose);
    _onPageChanged(_active);
  }

  Future<void> _confirmExit() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغييرات غير محفوظة'),
        content: const Text('هل تريد حفظ التعديلات قبل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('خروج بدون حفظ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('حفظ وخروج')),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save(silent: true);
      if (mounted) Navigator.pop(context);
    } else if (action == 'discard') {
      Navigator.pop(context);
    }
  }

  Future<Color?> _pickColor() async {
    final c = await _pickColorSheet();
    if (c != null && c.a != 0) _pushRecentColor(c.toARGB32());
    return c;
  }

  Future<Color?> _pickColorSheet() => showModalBottomSheet<Color>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final r in _recentColors)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, Color(r)),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(r),
                      child: const Icon(Icons.history, size: 14, color: Colors.white70),
                    ),
                  ),
                for (final c in _inkPalette)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, c),
                    child: CircleAvatar(radius: 18, backgroundColor: c),
                  ),
                InkWell(
                  onTap: () => Navigator.pop(ctx, const Color(0x00000000)),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.block, size: 18),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final c = await _pickFromAll(ctx);
                    if (c != null && ctx.mounted) Navigator.pop(ctx, c);
                  },
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// أكثر من 60 لوناً.
  Future<Color?> _pickFromAll(BuildContext ctx) => showDialog<Color>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: const Text('كل الألوان'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _allColors)
                    InkWell(
                      onTap: () => Navigator.pop(d, c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _watermarkSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          void u(VoidCallback f) {
            setState(() {
              f();
              _dirty = true;
            });
            ss(() {});
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _watermark,
                    onChanged: (_) => u(() {}),
                    decoration: const InputDecoration(labelText: 'نص العلامة المائية'),
                  ),
                  Row(children: [
                    const SizedBox(width: 70, child: Text('الحجم')),
                    Expanded(
                      child: Slider(value: _wmSize, min: 12, max: 160, onChanged: (v) => u(() => _wmSize = v)),
                    ),
                  ]),
                  Row(children: [
                    const SizedBox(width: 70, child: Text('الظهور')),
                    Expanded(
                      child: Slider(value: _wmOpacity, min: 0, max: 1, onChanged: (v) => u(() => _wmOpacity = v)),
                    ),
                  ]),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final c = await _pickColor();
                        if (c != null) u(() => _wmColor = c);
                      },
                      icon: CircleAvatar(radius: 9, backgroundColor: _wmColor),
                      label: const Text('لون العلامة'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editLessonInfo() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيانات الدرس'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _footer,
                onChanged: (_) => setState(() => _dirty = true),
                decoration: const InputDecoration(labelText: 'نص ناعم أسفل الصفحات'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _video,
                onChanged: (_) => _markDirty(),
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'رابط فيديو (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ formatting

  /// يلوّن المحدد فقط، أو يضبط لون ما سيُكتب لاحقاً دون المساس بما كُتب.
  void _applyColor(Color c) {
    final ctrl = _pages[_active];
    final v = c.a == 0 ? 0 : c.toARGB32();
    _pushRecentColor(v);
    final sel = ctrl.selection;
    if (sel.isValid && !sel.isCollapsed) {
      if (_fgMode) {
        ctrl.applyFg(sel.start, sel.end, v);
      } else {
        ctrl.applyBg(sel.start, sel.end, v);
      }
    } else if (_fgMode) {
      ctrl.curFg = v;
      ctrl.explicit = true;
    } else {
      ctrl.curBg = v;
      ctrl.explicit = true;
    }
    setState(() => _dirty = true);
  }

  void _pushRecentColor(int v) {
    if (v == 0) return;
    _recentColors.remove(v);
    _recentColors.insert(0, v);
    if (_recentColors.length > 10) _recentColors.removeLast();
    AppStorage.saveStrings('recentColors', _recentColors.map((e) => e.toString()).toList());
  }

  void _pushRecentSymbol(String t) {
    _recentSymbols.remove(t);
    _recentSymbols.insert(0, t);
    if (_recentSymbols.length > 10) _recentSymbols.removeLast();
    AppStorage.saveStrings('recentSymbols', _recentSymbols);
  }

  void _applySize(int v) {
    final ctrl = _pages[_active];
    final sel = ctrl.selection;
    if (sel.isValid && !sel.isCollapsed) {
      ctrl.applySize(sel.start, sel.end, v);
    } else {
      ctrl.curSz = v;
    }
    setState(() {
      _dirty = true;
      _pendSize = null;
    });
    _onPageChanged(_active);
  }

  void _insertText(String t) {
    _pushRecentSymbol(t);
    final c = _pages[_active];
    final sel = c.selection;
    final a = sel.isValid ? sel.start : c.text.length;
    final b = sel.isValid ? sel.end : c.text.length;
    c.value = TextEditingValue(
      text: c.text.replaceRange(a, b, t),
      selection: TextSelection.collapsed(offset: a + t.length),
    );
    Sound.tap();
    _onPageChanged(_active);
    _nodes[_active].requestFocus();
  }

  Future<void> _toggleFav(String sym) async {
    setState(() {
      if (!_favSymbols.remove(sym)) _favSymbols.add(sym);
    });
    await AppStorage.saveFavSymbols(_favSymbols);
  }

  Future<void> _symbolsSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اضغط للإدراج • اضغط مطولاً لإضافة الرمز إلى الشريط أو إزالته'),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final sym in kSymbols)
                          GestureDetector(
                            onTap: () => _insertText(sym),
                            onLongPress: () async {
                              await _toggleFav(sym);
                              ss(() {});
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _favSymbols.contains(sym)
                                    ? Colors.deepPurple.withValues(alpha: .45)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: _favSymbols.contains(sym)
                                    ? Border.all(color: Colors.deepPurpleAccent)
                                    : null,
                              ),
                              child: Text(sym, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- objects

  double get _pageH => _a4Width * _a4Ratio;

  void _addObject(PageObject o) => setState(() {
        _objects[_active].add(o);
        _dirty = true;
      });

  void _addTable() {
    Sound.tap();
    final o = PageObject(
      type: 'table',
      x: _margin,
      y: 200,
      w: _a4Width - 2 * _margin,
      h: 3 * 38,
      rows: 3,
      cols: 3,
      cells: List<String>.generate(9, (_) => ''),
    );
    _addObject(o);
    _editObject(_active, o);
  }

  Future<void> _addCard() async {
    final shape = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.crop_square),
              title: const Text('مستطيل'),
              onTap: () => Navigator.pop(ctx, 'rect'),
            ),
            ListTile(
              leading: const Icon(Icons.square_outlined),
              title: const Text('مربع'),
              onTap: () => Navigator.pop(ctx, 'square'),
            ),
            ListTile(
              leading: const Icon(Icons.rounded_corner),
              title: const Text('مستطيل بحواف دائرية'),
              onTap: () => Navigator.pop(ctx, 'rounded'),
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: const Text('دائرة'),
              onTap: () => Navigator.pop(ctx, 'circle'),
            ),
          ],
        ),
      ),
    );
    if (shape == null) return;
    Sound.tap();
    final equal = shape == 'square' || shape == 'circle';
    final o = PageObject(
      type: 'card',
      shape: shape == 'square' ? 'rect' : shape,
      x: 120,
      y: 220,
      w: equal ? 160 : 260,
      h: equal ? 160 : 110,
      fill: 0xfffff3b0,
    );
    _addObject(o);
    _editObject(_active, o);
  }

  Future<void> _addImage() async {
    try {
      final r = await pickImageToApp();
      if (r == null || !mounted) return;
      const w = 300.0;
      final h = (w * r.ratio).clamp(40.0, _pageH - 120).toDouble();
      Sound.tap();
      _addObject(PageObject(type: 'image', path: r.path, x: (_a4Width - w) / 2, y: 150, w: w, h: h));
    } catch (_) {
      if (mounted) showMessage(context, 'تعذر اختيار الصورة');
    }
  }

  /// جسم العنصر: يُرسم تحت النص ولا يلتقط اللمس، فيمكنك الكتابة فوقه مباشرة.
  Widget _objectVisual(PageObject o) {
    return Positioned(
      left: o.x,
      top: o.y,
      width: o.w,
      height: o.h,
      child: IgnorePointer(child: buildObjectWidget(o, 1)),
    );
  }

  Widget _round(double size, IconData icon, {Color color = Colors.deepPurpleAccent}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: size * .56, color: Colors.white),
    );
  }

  /// مقابض العنصر فقط (تحريك، تغيير حجم، تعديل، نسخ، تثبيت). [zs] = مقياس العرض.
  List<Widget> _objectHandles(int page, PageObject o, double zs) {
    final hs = (30 / zs).clamp(22.0, 70.0).toDouble();
    if (o.locked) {
      return [
        Positioned(
          left: o.x,
          top: o.y,
          child: GestureDetector(
            onTap: () => setState(() {
              o.locked = false;
              _dirty = true;
            }),
            child: Opacity(opacity: .55, child: _round(hs * .8, Icons.lock, color: Colors.black54)),
          ),
        ),
      ];
    }
    final barLeft = math.max(0.0, o.x + o.w - 3 * (hs + 4));
    final barTop = o.y >= hs + 2 ? o.y - hs - 2 : o.y + 2;
    return [
      Positioned(
        left: o.x,
        top: o.y,
        width: o.w,
        height: o.h,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: .6), width: 1 / zs),
            ),
          ),
        ),
      ),
      // تحريك
      Positioned(
        left: o.x,
        top: o.y,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() {
            o.x = (o.x + d.delta.dx).clamp(0.0, math.max(0.0, _a4Width - o.w)).toDouble();
            o.y = (o.y + d.delta.dy).clamp(0.0, math.max(0.0, _pageH - o.h)).toDouble();
            _dirty = true;
          }),
          child: _round(hs, Icons.open_with),
        ),
      ),
      // تغيير الحجم
      Positioned(
        left: o.x + o.w - hs,
        top: o.y + o.h - hs,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() {
            o.w = (o.w + d.delta.dx).clamp(40.0, math.max(40.0, _a4Width - o.x)).toDouble();
            o.h = (o.h + d.delta.dy).clamp(30.0, math.max(30.0, _pageH - o.y)).toDouble();
            _dirty = true;
          }),
          child: _round(hs, Icons.open_in_full),
        ),
      ),
      // تعديل / نسخ / تثبيت
      Positioned(
        left: barLeft,
        top: barTop,
        child: Row(
          children: [
            GestureDetector(onTap: () => _editObject(page, o), child: _round(hs, Icons.edit)),
            SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() {
                final c = o.copy();
                c.x = math.min(c.x, math.max(0.0, _a4Width - c.w));
                c.y = math.min(c.y, math.max(0.0, _pageH - c.h));
                _objects[page].add(c);
                _dirty = true;
              }),
              child: _round(hs, Icons.copy, color: Colors.teal),
            ),
            SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() {
                o.locked = true;
                _dirty = true;
              }),
              child: _round(hs, Icons.lock_open, color: Colors.orange),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _colorBtn(String label, int value, void Function(int) set, StateSetter ss) {
    return OutlinedButton.icon(
      onPressed: () async {
        final c = await _pickColor();
        if (c != null) {
          setState(() => set(c.toARGB32()));
          ss(() {});
        }
      },
      icon: CircleAvatar(radius: 9, backgroundColor: Color(value)),
      label: Text(label),
    );
  }

  Future<void> _editObject(int page, PageObject o) async {
    if (o.type == 'table') {
      await _editTable(page, o);
    } else if (o.type == 'image') {
      await _editImage(page, o);
    } else {
      await _editCard(page, o);
    }
    if (mounted) setState(() => _dirty = true);
  }

  Future<void> _editCard(int page, PageObject o) async {
    final text = TextEditingController(text: o.text);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('البطاقة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (v) => setState(() => o.text = v),
                  decoration: const InputDecoration(labelText: 'نص البطاقة'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const {'rect': 'مستطيل', 'rounded': 'دائري الحواف', 'circle': 'دائرة'}.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: o.shape == e.key,
                        onSelected: (_) {
                          setState(() => o.shape = e.key);
                          ss(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _colorBtn('خلفية البطاقة', o.fill, (v) => o.fill = v, ss),
                    _colorBtn('لون النص', o.textColor, (v) => o.textColor = v, ss),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _objects[page].remove(o);
                Navigator.pop(ctx);
              },
              child: const Text('حذف'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 600), text.dispose);
  }

  Future<void> _editTable(int page, PageObject o) async {
    final all = <TextEditingController>[];
    List<TextEditingController> mk() {
      final l = [
        for (var i = 0; i < o.rows * o.cols; i++)
          TextEditingController(text: i < o.cells.length ? o.cells[i] : ''),
      ];
      all.addAll(l);
      return l;
    }

    var ctrls = mk();
    void commit() => o.cells = ctrls.map((c) => c.text).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          void change(int dr, int dc) {
            commit();
            o.resize((o.rows + dr).clamp(1, 12).toInt(), (o.cols + dc).clamp(1, 8).toInt());
            if (dr != 0) o.h = o.rows * 38.0;
            ctrls = mk();
            setState(() {});
            ss(() {});
          }

          Widget stepper(String label, int value, int dr, int dc) => Row(
                children: [
                  SizedBox(width: 60, child: Text(label)),
                  IconButton(onPressed: () => change(-dr, -dc), icon: const Icon(Icons.remove_circle_outline)),
                  Text('$value'),
                  IconButton(onPressed: () => change(dr, dc), icon: const Icon(Icons.add_circle_outline)),
                ],
              );

          return AlertDialog(
            title: const Text('الجدول'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    stepper('الصفوف', o.rows, 1, 0),
                    stepper('الأعمدة', o.cols, 0, 1),
                    Wrap(
                      spacing: 8,
                      children: [
                        _colorBtn('الصف الأول', o.header, (v) => o.header = v, ss),
                        _colorBtn('الخلايا', o.fill, (v) => o.fill = v, ss),
                        _colorBtn('النص', o.textColor, (v) => o.textColor = v, ss),
                      ],
                    ),
                    const Divider(),
                    for (var r = 0; r < o.rows; r++)
                      Row(
                        children: [
                          for (var c = 0; c < o.cols; c++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: TextField(
                                  controller: ctrls[r * o.cols + c],
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (_) {
                                    commit();
                                    setState(() {});
                                  },
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(6),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _objects[page].remove(o);
                  Navigator.pop(ctx);
                },
                child: const Text('حذف الجدول'),
              ),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
            ],
          );
        },
      ),
    );
    commit();
    Future.delayed(const Duration(milliseconds: 600), () {
      for (final c in all) {
        c.dispose();
      }
    });
  }

  Future<void> _editImage(int page, PageObject o) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الصورة'),
        content: const Text('اسحب الصورة لتحريكها، واسحب الدائرة في زاويتها لتغيير حجمها.'),
        actions: [
          TextButton(
            onPressed: () {
              _objects[page].remove(o);
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final r = await pickImageToApp();
                if (r != null) setState(() => o.path = r.path);
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('تبديل الصورة'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
        ],
      ),
    );
  }

  Future<void> _coversSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          Widget coverRow(String label, String path, void Function(String) set) {
            final has = path.isNotEmpty && File(path).existsSync();
            return ListTile(
              leading: has
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(File(path), width: 40, height: 56, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.image_outlined, size: 36),
              title: Text(label),
              subtitle: Text(has ? 'تم اختيار صورة' : 'لا توجد صورة'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'رفع صورة',
                    icon: const Icon(Icons.upload),
                    onPressed: () async {
                      try {
                        final r = await pickImageToApp();
                        if (r != null) {
                          setState(() {
                            set(r.path);
                            _dirty = true;
                          });
                          ss(() {});
                        }
                      } catch (_) {
                        if (mounted) showMessage(context, 'تعذر اختيار الصورة');
                      }
                    },
                  ),
                  if (path.isNotEmpty)
                    IconButton(
                      tooltip: 'إزالة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          set('');
                          _dirty = true;
                        });
                        ss(() {});
                      },
                    ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('الغلافان يظهران في ملف PDF: الأول قبل الصفحات والثاني بعدها، بمقاس A4 كامل.'),
                ),
                coverRow('غلاف الملف (البداية)', _coverFront, (v) => _coverFront = v),
                coverRow('الغلاف الخلفي (النهاية)', _coverBack, (v) => _coverBack = v),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool? selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: selected == null
          ? ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap)
          : ChoiceChip(
              avatar: Icon(icon, size: 18),
              label: Text(label),
              selected: selected,
              onSelected: (_) => onTap(),
            ),
    );
  }

  Widget _sizePanel() {
    final ctrl = _pages[_active];
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final sel = ctrl.selection;
        final has = sel.isValid && !sel.isCollapsed && sel.end <= ctrl.text.length;
        final raw = has ? ctrl.text.substring(sel.start, sel.end).replaceAll('\n', ' ') : '';
        final shown = raw.isEmpty
            ? 'حدّد نصاً لترى كيف سيبدو بالحجم الجديد'
            : (raw.length > 70 ? '${raw.substring(0, 70)}…' : raw);
        final base = has
            ? (ctrl.sz[sel.start] == 0 ? _fontPt : ctrl.sz[sel.start].toDouble())
            : (ctrl.curSz == 0 ? _fontPt : ctrl.curSz.toDouble());
        final v = (_pendSize ?? base).clamp(6.0, 60.0).toDouble();
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xff232536), borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 84),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: paperColor, borderRadius: BorderRadius.circular(6)),
                clipBehavior: Clip.hardEdge,
                child: Text(
                  shown,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: raw.isEmpty ? 12 : v,
                    color: raw.isEmpty ? Colors.black45 : _inkColor,
                    height: _lineFactor,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _pendSize = math.max(6, v - 1)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Slider(
                      value: v,
                      min: 6,
                      max: 60,
                      divisions: 54,
                      label: v.round().toString(),
                      onChanged: (x) => setState(() => _pendSize = x.roundToDouble()),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _pendSize = math.min(60, v + 1)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  SizedBox(width: 26, child: Text(v.round().toString())),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _applySize(v.round()),
                      child: Text(has ? 'تطبيق على المحدد' : 'تطبيق على ما سأكتبه'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(onPressed: () => _applySize(0), child: const Text('الحجم الافتراضي')),
                  IconButton(
                    onPressed: () => setState(() {
                      _sizeBar = false;
                      _pendSize = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _formatBar() {
    final ctrl = _pages[_active];
    final seen = <String>{};
    final symbols = [..._favSymbols, ..._recentSymbols].where(seen.add).toList();
    return Container(
      color: const Color(0xff1b1d2b),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sizeBar) _sizePanel(),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _chip(Icons.format_color_text, 'لون النص', selected: _fgMode, onTap: () => setState(() => _fgMode = true)),
                _chip(Icons.border_color, 'تظليل', selected: !_fgMode, onTap: () => setState(() => _fgMode = false)),
                _chip(Icons.format_size, 'حجم', selected: _sizeBar, onTap: () => setState(() {
                      _sizeBar = !_sizeBar;
                      _pendSize = null;
                    })),
                _chip(Icons.table_chart, 'جدول', onTap: _addTable),
                _chip(Icons.image, 'صورة', onTap: _addImage),
                _chip(Icons.crop_square, 'بطاقة', onTap: _addCard),
                _chip(Icons.emoji_symbols, 'رموز', onTap: _symbolsSheet),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListenableBuilder(
              listenable: ctrl,
              builder: (context, _) {
                final cur = _fgMode ? ctrl.curFg : ctrl.curBg;
                Widget dot(Color c, VoidCallback onTap, {Widget? child}) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: InkWell(onTap: onTap, child: CircleAvatar(radius: 14, backgroundColor: c, child: child)),
                    );
                Widget check(Color c) => Icon(
                      Icons.check,
                      size: 16,
                      color: c.computeLuminance() > .5 ? Colors.black : Colors.white,
                    );
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    dot(Colors.deepPurple, () async {
                      final c = await _pickFromAll(context);
                      if (c != null) _applyColor(c);
                    }, child: const Icon(Icons.add, size: 16, color: Colors.white)),
                    dot(Colors.white24, () => _applyColor(const Color(0x00000000)),
                        child: Icon(cur == 0 ? Icons.check : Icons.block, size: 16)),
                    for (final r in _recentColors)
                      dot(Color(r), () => _applyColor(Color(r)), child: cur == r ? check(Color(r)) : null),
                    if (_recentColors.isNotEmpty)
                      const SizedBox(height: 28, child: VerticalDivider(width: 10, color: Colors.white24)),
                    for (final c in _inkPalette)
                      dot(c, () => _applyColor(c), child: cur == c.toARGB32() ? check(c) : null),
                  ],
                );
              },
            ),
          ),
          if (symbols.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final sym in symbols)
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: GestureDetector(
                        onTap: () => _insertText(sym),
                        onLongPress: () => _toggleFav(sym),
                        child: Container(
                          width: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _favSymbols.contains(sym) ? Colors.deepPurple.withValues(alpha: .4) : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(sym, style: const TextStyle(fontSize: 22)),
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

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff2a2c3a),
        appBar: AppBar(
          title: const Text('محرر الدرس'),
          actions: [
            ListenableBuilder(
              listenable: _pages[_active],
              builder: (context, _) => IconButton(
                tooltip: 'تراجع',
                onPressed: _pages[_active].canUndo
                    ? () {
                        _pages[_active].undo();
                        _onPageChanged(_active);
                      }
                    : null,
                icon: const Icon(Icons.undo),
              ),
            ),
            ListenableBuilder(
              listenable: _pages[_active],
              builder: (context, _) => IconButton(
                tooltip: 'إعادة',
                onPressed: _pages[_active].canRedo
                    ? () {
                        _pages[_active].redo();
                        _onPageChanged(_active);
                      }
                    : null,
                icon: const Icon(Icons.redo),
              ),
            ),
            IconButton(
              tooltip: 'هذا حل: أخفِ النص المحدد في الاختبار',
              onPressed: _addAnswerMarker,
              icon: const Icon(Icons.lightbulb_outline),
            ),
            IconButton(tooltip: 'حفظ', onPressed: _save, icon: const Icon(Icons.save)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'info') _editLessonInfo();
                if (v == 'wm') _watermarkSheet();
                if (v == 'covers') _coversSheet();
                if (v == 'pdf') _exportPdf();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'wm', child: Text('العلامة المائية (حجم، ظهور، لون)')),
                PopupMenuItem(value: 'covers', child: Text('صور الغلاف (أمامي / خلفي)')),
                PopupMenuItem(value: 'info', child: Text('بيانات الدرس (فيديو، ملاحظة...)')),
                PopupMenuItem(value: 'pdf', child: Text('تصدير PDF')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      onChanged: (_) => setState(() => _dirty = true),
                      decoration: const InputDecoration(
                        labelText: 'اسم الدرس',
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xff1b1d2b),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'لون العنوان',
                    icon: Icon(Icons.format_color_text, color: _titleColor),
                    onPressed: () async {
                      final c = await _pickColor();
                      if (c != null) setState(() { _titleColor = c; _dirty = true; });
                    },
                  ),
                  IconButton(
                    tooltip: 'خلفية العنوان',
                    icon: Icon(Icons.format_color_fill,
                        color: _titleBg.a == 0 ? Colors.white54 : _titleBg),
                    onPressed: () async {
                      final c = await _pickColor();
                      if (c != null) setState(() { _titleBg = c; _dirty = true; });
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSheets()),
            _formatBar(),
            if (!keyboardOpen) _buildControls(),
          ],
        ),
      ),
    );
  }

  /// تكبير يجعل الصفحة كاملة (عرضاً وارتفاعاً) ظاهرة في الشاشة.
  double _fitZoom(double viewW, double viewH) {
    final byH = ((viewH - 64) / _a4Ratio) / (viewW - 24);
    return byH.clamp(.3, 1.0).toDouble();
  }

  Widget _buildSheets() {
    return LayoutBuilder(
      builder: (context, box) {
        final viewW = box.maxWidth;
        _viewH = box.maxHeight;
        if (!_fitted) {
          _zoom = _fitZoom(viewW, box.maxHeight);
          _fitted = true;
        }
        final sheetW = (viewW - 24) * _zoom;
        final needsH = sheetW + 24 > viewW;
        final body = SizedBox(
          width: math.max(viewW, sheetW + 24),
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            child: Column(
              children: [
                for (var i = 0; i < _pages.length; i++) ...[
                  _buildSheetHeader(i, sheetW),
                  SizedBox(
                    width: sheetW,
                    height: sheetW * _a4Ratio,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: _a4Width,
                        height: _a4Width * _a4Ratio,
                        child: _buildSheet(i, _a4Width, 1.0, sheetW / _a4Width),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                FilledButton.tonalIcon(
                  onPressed: _addPage,
                  icon: const Icon(Icons.add_box),
                  label: const Text('صفحة جديدة'),
                ),
              ],
            ),
          ),
        );
        return SingleChildScrollView(
          child: needsH ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: body) : body,
        );
      },
    );
  }

  Widget _buildSheetHeader(int i, double sheetW) {
    return SizedBox(
      width: sheetW,
      child: Row(
        children: [
          Text(
            'الصفحة ${i + 1} من ${_pages.length}',
            style: TextStyle(
              color: i == _active ? const Color(0xffb7a9ff) : Colors.white60,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (_pages.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'حذف الصفحة',
              onPressed: () => _deletePage(i),
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildSheet(int i, double sheetW, double scale, double zs) {
    final sheetH = sheetW * _a4Ratio;
    final pad = _margin * scale;
    final titleH = i == 0 ? _titleBlock * scale : 0.0;
    final footerH = _footerBlock * scale;
    final watermark = _watermark.text.trim();
    final footerNote = _footer.text.trim();
    final style = _textStyle(scale);

    return Container(
      width: sheetW,
      height: sheetH,
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (watermark.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      watermark,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: _wmSize * scale,
                        fontWeight: FontWeight.bold,
                        color: _wmColor.withValues(alpha: _wmOpacity),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_lineOpacity > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: LinesPainter(
                    opacity: _lineOpacity,
                    lineHeight: _fontPt * _lineFactor * scale,
                    textTop: pad + titleH,
                    baseline: firstBaseline(_fontPt, scale, _lineFactor),
                    gap: _fontPt * .18 * scale,
                    bottomInset: pad + footerH,
                  ),
                ),
              ),
            ),
          if (i == 0)
            Positioned(
              top: pad,
              left: pad,
              right: pad,
              height: titleH,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: _titleBg,
                    borderRadius: BorderRadius.circular(6 * scale),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _title.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 20 * scale,
                      color: _titleColor,
                    ),
                  ),
                ),
              ),
            ),
          // العناصر تحت النص: تكتب فوقها بحرية
          for (final o in _objects[i]) _objectVisual(o),
          // الحقل يغطي الصفحة كلها، فأي لمسة في أي مكان تضع المؤشر
          Positioned.fill(
            child: TextField(
              key: ObjectKey(_pages[i]),
              controller: _pages[i],
              focusNode: _nodes[i],
              onChanged: (_) => _onPageChanged(i),
              onTapOutside: (_) {},
              maxLines: null,
              expands: true,
              cursorColor: Colors.deepPurple,
              textAlignVertical: TextAlignVertical.top,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: style,
              strutStyle: _strut(scale),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(pad, pad + titleH, pad, pad + footerH),
                hintText: i == 0
                    ? 'اكتب ملخصك هنا...\nحدد نصاً ثم اضغط أيقونة المصباح لإخفائه كإجابة في الاختبار'
                    : null,
                hintStyle: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: _fontPt * scale * .85,
                  color: Colors.black38,
                ),
              ),
            ),
          ),
          for (final o in _objects[i]) ..._objectHandles(i, o, zs),
          Positioned(
            left: pad,
            right: pad,
            bottom: pad * .35,
            height: footerH,
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (footerNote.isNotEmpty)
                    Text(
                      footerNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 8 * scale,
                        color: Colors.black45,
                      ),
                    ),
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 10 * scale,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xff171824),
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('تكبير الصفحة'),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'تصغير',
                  onPressed: () => setState(() => _zoom = math.max(.3, _zoom - .1)),
                  icon: const Icon(Icons.zoom_out),
                ),
                Expanded(
                  child: Slider(
                    value: _zoom.clamp(.3, 3.0).toDouble(),
                    min: .3,
                    max: 3,
                    onChanged: (v) => setState(() => _zoom = v),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'تكبير',
                  onPressed: () => setState(() => _zoom = math.min(3, _zoom + .1)),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'إظهار الصفحة كاملة',
                  onPressed: () => setState(() => _zoom = _fitZoom(MediaQuery.sizeOf(context).width, _viewH)),
                  icon: const Icon(Icons.fit_screen),
                ),
              ],
            ),
            Row(
              children: [
                const Text('تباعد السطور'),
                Expanded(
                  child: Slider(
                    value: _lineFactor,
                    min: 1.3,
                    max: 2.6,
                    onChanged: (v) => setState(() => _lineFactor = v),
                    onChangeEnd: (_) {
                      if (_reflowAll()) setState(() => _dirty = true);
                    },
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
            Row(
              children: [
                const Text('إظهار السطور'),
                Expanded(
                  child: Slider(
                    value: _lineOpacity,
                    min: 0,
                    max: .35,
                    onChanged: (v) => setState(() => _lineOpacity = v),
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
