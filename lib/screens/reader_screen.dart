import 'package:flutter/material.dart';

import '../models.dart';
import '../services/pdf_export.dart';
import '../utils.dart';

/// توحيد النص قبل المقارنة: الهمزات، الياء، التشكيل، المسافات.
String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _quiz = false;
  bool _checked = false;
  bool _revealed = false;
  double _size = 19;
  int _page = 0;
  int _run = 0;
  List<TextEditingController> _inputs = [];

  String get _rawPage => widget.lesson.pages[_page];

  List<RegExpMatch> get _matches => answerPattern.allMatches(_rawPage).toList();

  @override
  void dispose() {
    for (final c in _inputs) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetQuiz() {
    final old = _inputs;
    _inputs = _matches.map((_) => TextEditingController()).toList();
    _checked = false;
    _revealed = false;
    _run++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  void _goTo(int page) {
    setState(() {
      _page = page;
      _resetQuiz();
    });
  }

  void _toggleQuiz() {
    setState(() {
      _quiz = !_quiz;
      _resetQuiz();
    });
  }

  Future<void> _openVideo() async {
    final ok = await openExternalUrl(widget.lesson.videoUrl);
    if (!ok && mounted) showMessage(context, 'رابط الفيديو غير صالح أو تعذر فتحه');
  }

  Future<void> _exportPdf() async {
    try {
      await exportLessonPdf(widget.lesson);
    } catch (e) {
      if (mounted) showMessage(context, 'تعذر إنشاء PDF: $e');
    }
  }

  void _changeSize(double delta) {
    setState(() => _size = (_size + delta).clamp(12.0, 36.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        actions: [
          if (lesson.videoUrl.trim().isNotEmpty)
            IconButton(
              tooltip: 'مشاهدة الفيديو',
              onPressed: _openVideo,
              icon: const Icon(Icons.play_circle_outline),
            ),
          IconButton(
            tooltip: 'تصغير الخط',
            onPressed: () => _changeSize(-1),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            onPressed: () => _changeSize(1),
            icon: const Icon(Icons.text_increase),
          ),
          IconButton(
            tooltip: 'تصدير PDF',
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: paperColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quiz ? _buildQuiz() : _buildPlain(),
                    if (lesson.footerNote.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Text(
                          lesson.footerNote,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _buildNav(),
        ],
      ),
    );
  }

  Widget _buildPlain() {
    return Text(
      stripAnswerMarkers(_rawPage),
      style: TextStyle(color: paperInk, fontSize: _size, height: 1.8),
    );
  }

  Widget _buildQuiz() {
    final raw = _rawPage;
    final matches = _matches;
    if (matches.isEmpty || _inputs.length != matches.length) {
      return Text(
        'لا توجد إجابات مخفية في هذه الصفحة.',
        style: TextStyle(color: paperInk, fontSize: _size),
      );
    }

    final spans = <InlineSpan>[];
    var last = 0;
    var correctCount = 0;
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final expected = m.group(1) ?? '';
      if (_normalize(_inputs[i].text) == _normalize(expected)) correctCount++;
      spans.add(TextSpan(text: stripAnswerMarkers(raw.substring(last, m.start))));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildBlank(i, expected),
        ),
      );
      last = m.end;
    }
    spans.add(TextSpan(text: stripAnswerMarkers(raw.substring(last))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(color: paperInk, fontSize: _size, height: 2),
            children: spans,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _revealed ? null : () => setState(() => _checked = true),
              icon: const Icon(Icons.check),
              label: const Text('تحقق من الحل'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _revealed = !_revealed),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(_revealed ? 'إخفاء الحلول' : 'إظهار الحلول'),
            ),
            TextButton.icon(
              onPressed: () => setState(_resetQuiz),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة'),
            ),
          ],
        ),
        if (_checked && !_revealed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'إجاباتك الصحيحة: $correctCount من ${matches.length}',
              style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildBlank(int i, String expected) {
    if (_revealed) {
      return Text(
        expected,
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: _size,
          decoration: TextDecoration.underline,
        ),
      );
    }

    final correct = _normalize(_inputs[i].text) == _normalize(expected);
    final color = !_checked
        ? Colors.deepPurple
        : (correct ? Colors.green.shade700 : Colors.red.shade700);
    final width = (expected.length * _size * .65).clamp(80.0, 240.0).toDouble();

    return SizedBox(
      width: width,
      child: TextField(
        key: ValueKey('quiz-$_page-$_run-$i'),
        controller: _inputs[i],
        onChanged: (_) {
          if (_checked) setState(() => _checked = false);
        },
        style: TextStyle(color: _checked ? color : paperInk, fontSize: _size),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'اكتب الحل',
          hintStyle: const TextStyle(color: Colors.black45),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 3)),
        ),
      ),
    );
  }

  Widget _buildNav() {
    final total = widget.lesson.pages.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'الصفحة السابقة',
              onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            Expanded(child: Center(child: Text('صفحة ${_page + 1} من $total'))),
            IconButton(
              tooltip: 'الصفحة التالية',
              onPressed: _page < total - 1 ? () => _goTo(_page + 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _toggleQuiz,
              icon: Icon(_quiz ? Icons.close : Icons.psychology),
              label: Text(_quiz ? 'إنهاء' : 'اختبر نفسي'),
            ),
          ],
        ),
      ),
    );
  }
}
