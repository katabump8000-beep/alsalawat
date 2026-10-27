import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../services/pdf_export.dart';
import '../utils.dart';

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
  late final List<TextEditingController> _pages =
      widget.lesson.pages.map((p) => TextEditingController(text: p)).toList();
  late final List<UndoHistoryController> _undos =
      List.generate(_pages.length, (_) => UndoHistoryController());

  int _current = 0;
  double _lineOpacity = .12;
  double _fontSize = 18;
  Color _inkColor = paperInk;
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in [_title, _watermark, _footer, _video, ..._pages]) {
      c.dispose();
    }
    for (final u in _undos) {
      u.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _disposeLater(List<ChangeNotifier> items) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in items) {
        i.dispose();
      }
    });
  }

  Future<void> _save({bool silent = false}) async {
    final l = widget.lesson;
    final t = _title.text.trim();
    l.title = t.isEmpty ? 'درس بلا عنوان' : t;
    l.watermark = _watermark.text;
    l.footerNote = _footer.text;
    l.videoUrl = _video.text.trim();
    l.pages = _pages.map((p) => p.text).toList();
    await widget.onSave();
    if (!mounted) return;
    setState(() => _dirty = false);
    if (!silent) showMessage(context, 'تم حفظ الدرس');
  }

  Future<void> _exportPdf() async {
    await _save(silent: true);
    try {
      await exportLessonPdf(widget.lesson);
    } catch (e) {
      if (mounted) showMessage(context, 'تعذر إنشاء ملف PDF');
    }
  }

  void _addAnswerMarker() {
    final c = _pages[_current];
    final s = c.selection;
    if (!s.isValid || s.isCollapsed) {
      showMessage(context, 'حدد كلمة أو عبارة أولاً');
      return;
    }
    final selected = c.text.substring(s.start, s.end);
    c.value = TextEditingValue(
      text: c.text.replaceRange(s.start, s.end, '$answerOpen$selected$answerClose'),
      selection: TextSelection.collapsed(offset: s.start + selected.length + 2),
    );
    _markDirty();
  }

  void _addPage() {
    setState(() {
      _pages.add(TextEditingController());
      _undos.add(UndoHistoryController());
      _current = _pages.length - 1;
      _dirty = true;
    });
  }

  Future<void> _deletePage() async {
    if (_pages.length <= 1) return;
    if (_pages[_current].text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حذف الصفحة'),
          content: Text('هل تريد حذف الصفحة ${_current + 1}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      final removedPage = _pages.removeAt(_current);
      final removedUndo = _undos.removeAt(_current);
      _disposeLater([removedPage, removedUndo]);
      if (_current >= _pages.length) _current = _pages.length - 1;
      _dirty = true;
    });
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
                onChanged: (_) => _markDirty(),
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
              const SizedBox(height: 12),
              TextField(
                controller: _watermark,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(
                  labelText: 'العلامة المائية (تظهر في PDF)',
                  hintText: 'مثال: ملخصاتي',
                ),
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

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final undo = _undos[_current];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
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
                if (v == 'pdf') _exportPdf();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'info', child: Text('بيانات الدرس (فيديو، علامة مائية...)')),
                PopupMenuItem(value: 'pdf', child: Text('تصدير PDF')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _title,
                onChanged: (_) => _markDirty(),
                decoration: const InputDecoration(
                  labelText: 'اسم الدرس',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _current,
                      items: List.generate(
                        _pages.length,
                        (i) => DropdownMenuItem(value: i, child: Text('الصفحة ${i + 1} من ${_pages.length}')),
                      ),
                      onChanged: (v) => setState(() => _current = v ?? 0),
                    ),
                  ),
                  IconButton(onPressed: _addPage, icon: const Icon(Icons.add_box), tooltip: 'صفحة جديدة'),
                  IconButton(
                    onPressed: _pages.length <= 1 ? null : _deletePage,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'حذف الصفحة',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: paperColor,
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    if (_lineOpacity > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: LinesPainter(
                              opacity: _lineOpacity,
                              lineHeight: _fontSize * 1.65,
                              topInset: 20,
                            ),
                          ),
                        ),
                      ),
                    TextField(
                      key: ValueKey(_current),
                      controller: _pages[_current],
                      undoController: undo,
                      onChanged: (_) => _markDirty(),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: _inkColor, fontSize: _fontSize, height: 1.65),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(20),
                        border: InputBorder.none,
                        hintText: 'اكتب ملخصك هنا...\nحدد نصاً ثم اضغط أيقونة المصباح لإخفائه كإجابة في الاختبار',
                        hintStyle: TextStyle(color: Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!keyboardOpen) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('حجم النص'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 12,
                  max: 36,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              SizedBox(width: 28, child: Text(_fontSize.round().toString())),
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
    );
  }
}

class LinesPainter extends CustomPainter {
  LinesPainter({required this.opacity, required this.lineHeight, this.topInset = 20});

  final double opacity;
  final double lineHeight;
  final double topInset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: opacity)
      ..strokeWidth = .8;
    for (double y = topInset + lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant LinesPainter old) =>
      old.opacity != opacity || old.lineHeight != lineHeight || old.topInset != topInset;
}
