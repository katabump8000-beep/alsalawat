import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../services/pdf_export.dart';
import '../services/sheet_render.dart' show LinesPainter, firstBaseline;
import '../services/sound.dart';
import '../utils.dart';

/// أبعاد صفحة A4 بالنقاط (نفس أبعاد PDF) ليتطابق المحرر مع الملف الناتج.
const double _a4Width = 595;
const double _a4Ratio = 1.4142;
const double _margin = 42;
const double _titleBlock = 46;
const double _footerBlock = 28;
const double _lineFactor = 1.8;
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

  final List<TextEditingController> _pages = [];
  final List<UndoHistoryController> _undos = [];
  final List<FocusNode> _nodes = [];

  int _active = 0;
  double _zoom = 1.0;
  late double _fontPt = widget.lesson.fontPt;
  late double _lineOpacity = widget.lesson.lineOpacity;
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
    for (final text in widget.lesson.pages) {
      _addPageObjects(text);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reflowAll()) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _watermark, _footer, _video, ..._pages]) {
      c.dispose();
    }
    for (final u in _undos) {
      u.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- pages

  void _addPageObjects(String text) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) return;
      final idx = _nodes.indexOf(node);
      if (idx >= 0 && idx != _active && mounted) setState(() => _active = idx);
    });
    _pages.add(TextEditingController(text: text));
    _undos.add(UndoHistoryController());
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
      final u = _undos.removeAt(index);
      final n = _nodes.removeAt(index);
      _disposeLater([c, u, n]);
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
        forceStrutHeight: true,
      );

  /// الارتفاع المتاح للنص في الصفحة [index] بمقياس [scale].
  double _availableHeight(int index, double scale) {
    final sheetH = _a4Width * scale * _a4Ratio;
    final reserved = 2 * _margin + _footerBlock + (index == 0 ? _titleBlock : 0);
    return sheetH - reserved * scale;
  }

  /// يرجع موضع القص إن كان النص أطول من الصفحة، وإلا null.
  int? _overflowOffset(String text, double maxWidth, double maxHeight, TextStyle style) {
    if (text.isEmpty) return null;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      strutStyle: StrutStyle(
        fontFamily: _fontFamily,
        fontSize: style.fontSize,
        height: _lineFactor,
        forceStrutHeight: true,
      ),
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
      final sheetW = _sheetWidth();
      final scale = sheetW / _a4Width;
      final textW = sheetW - 2 * _margin * scale;
      final style = _textStyle(scale);
      var idx = start;
      var guard = 0;
      while (idx < _pages.length && guard++ < 200) {
        final ctrl = _pages[idx];
        final text = ctrl.text;
        final cut = _overflowOffset(text, textW, _availableHeight(idx, scale), style);
        if (cut == null) {
          idx++;
          continue;
        }
        changed = true;
        final sel = ctrl.selection;
        final cursor = sel.isValid ? sel.baseOffset : -1;

        var tail = text.substring(cut);
        var removed = 0;
        if (tail.startsWith('\n')) {
          tail = tail.substring(1);
          removed = 1;
        }
        if (idx + 1 >= _pages.length) {
          _addPageObjects('');
        }
        final next = _pages[idx + 1];
        final merged = next.text.isEmpty ? tail : '$tail\n${next.text}';

        final cursorMoves = cursor > cut;
        ctrl.value = TextEditingValue(
          text: text.substring(0, cut),
          selection: TextSelection.collapsed(
            offset: cursor < 0 ? cut : math.min(cursor, cut),
          ),
        );
        final nextCursor = cursorMoves
            ? math.max(0, math.min(cursor - cut - removed, merged.length))
            : 0;
        next.value = TextEditingValue(
          text: merged,
          selection: cursorMoves
              ? TextSelection.collapsed(offset: nextCursor)
              : const TextSelection.collapsed(offset: 0),
        );
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
    final selected = c.text.substring(s.start, s.end);
    c.value = TextEditingValue(
      text: c.text.replaceRange(s.start, s.end, '$answerOpen$selected$answerClose'),
      selection: TextSelection.collapsed(offset: s.start + selected.length + 2),
    );
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

  Future<Color?> _pickColor() => showModalBottomSheet<Color>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
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
            ],
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

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final undo = _undos[_active];

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
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: undo,
              builder: (context, value, _) => IconButton(
                tooltip: 'تراجع',
                onPressed: value.canUndo ? undo.undo : null,
                icon: const Icon(Icons.undo),
              ),
            ),
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: undo,
              builder: (context, value, _) => IconButton(
                tooltip: 'إعادة',
                onPressed: value.canRedo ? undo.redo : null,
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
                if (v == 'pdf') _exportPdf();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'wm', child: Text('العلامة المائية (حجم، ظهور، لون)')),
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
            if (!keyboardOpen) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildSheets() {
    final viewW = MediaQuery.sizeOf(context).width;
    final sheetW = _sheetWidth();
    final scale = sheetW / _a4Width;
    final contentW = math.max(viewW, sheetW + 24);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: contentW,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            child: Column(
              children: [
                for (var i = 0; i < _pages.length; i++) ...[
                  _buildSheetHeader(i, sheetW),
                  _buildSheet(i, sheetW, scale),
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
        ),
      ),
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

  Widget _buildSheet(int i, double sheetW, double scale) {
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
                    baseline: firstBaseline(_fontPt, scale),
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
          Positioned(
            top: pad + titleH,
            left: pad,
            right: pad,
            bottom: pad + footerH,
            child: TextField(
              key: ObjectKey(_pages[i]),
              controller: _pages[i],
              focusNode: _nodes[i],
              undoController: _undos[i],
              onChanged: (_) => _onPageChanged(i),
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
          Positioned(
            left: pad,
            right: pad,
            bottom: pad * .35,
            height: footerH,
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
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xff171824),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
                  onPressed: () => setState(() => _zoom = math.max(.6, _zoom - .2)),
                  icon: const Icon(Icons.zoom_out),
                ),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: .6,
                    max: 3,
                    onChanged: (v) => setState(() => _zoom = v),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'تكبير',
                  onPressed: () => setState(() => _zoom = math.min(3, _zoom + .2)),
                  icon: const Icon(Icons.zoom_in),
                ),
              ],
            ),
            Row(
              children: [
                const Text('حجم الخط'),
                Expanded(
                  child: Slider(
                    value: _fontPt,
                    min: 9,
                    max: 24,
                    onChanged: (v) => setState(() => _fontPt = v),
                    onChangeEnd: (_) {
                      if (_reflowAll()) setState(() => _dirty = true);
                    },
                  ),
                ),
                SizedBox(width: 28, child: Text(_fontPt.round().toString())),
              ],
            ),
            Row(
              children: [
                const Text('وضوح السطور'),
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
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in _inkPalette)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: InkWell(
                        onTap: () => setState(() => _inkColor = c),
                        child: CircleAvatar(
                          backgroundColor: c,
                          radius: 15,
                          child: _inkColor == c
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: c.computeLuminance() > .5 ? Colors.black : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
