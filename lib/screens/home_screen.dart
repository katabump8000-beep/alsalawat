import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../models.dart';
import '../services/pdf_export.dart';
import '../services/storage.dart';
import '../utils.dart';
import 'editor_screen.dart';
import 'login_screen.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.isDeveloper});

  final bool isDeveloper;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Lesson> _lessons = [];
  bool _loaded = false;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await AppStorage.loadSettings();
    final lessons = await AppStorage.loadLessons();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _lessons = lessons;
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    await AppStorage.saveLessons(_lessons);
    if (mounted) setState(() {});
  }

  Future<void> _openEditor(Lesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(lesson: lesson, onSave: _persist)),
    );
    await _persist();
  }

  /// يستورد درساً من PDF صدّره التطبيق (أو ملف JSON) ويفتحه للتعديل.
  Future<void> _importLesson() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'json'],
      );
      final path = r?.files.single.path;
      if (path == null) return;
      final lesson = lessonFromBytes(await File(path).readAsBytes());
      if (lesson == null) {
        if (mounted) {
          showMessage(context, 'لا توجد بيانات تعديل داخل هذا الملف. يعمل الاستيراد مع ملفات صدّرها التطبيق بعد هذا التحديث.');
        }
        return;
      }
      final json = lesson.toJson()..['id'] = const Uuid().v4();
      final copy = Lesson.fromJson(json);
      _lessons.insert(0, copy);
      await _persist();
      if (!mounted) return;
      await _openEditor(copy);
    } catch (_) {
      if (mounted) showMessage(context, 'تعذر فتح الملف');
    }
  }

  Future<void> _createLesson() async {
    final lesson = Lesson();
    _lessons.insert(0, lesson);
    await _persist();
    if (!mounted) return;
    await _openEditor(lesson);
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدرس'),
        content: Text('هل تريد حذف «${lesson.title}» نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    _lessons.removeWhere((x) => x.id == lesson.id);
    await _persist();
  }

  Future<void> _openContact() async {
    final ok = await openExternalUrl(contactUrl);
    if (!ok && mounted) showMessage(context, 'تعذر فتح رابط التواصل');
  }

  Future<void> _openSettings() async {
    var bg = _settings.listBackground;
    var size = _settings.listTextSize;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إعدادات واجهة الدروس'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('خلفية قائمة الدروس'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in kListBackgrounds.entries)
                    ChoiceChip(
                      label: Text(e.key),
                      selected: bg == e.value,
                      onSelected: (_) => setDialog(() => bg = e.value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('حجم العناوين'),
                  Expanded(
                    child: Slider(
                      value: size,
                      min: 13,
                      max: 25,
                      divisions: 12,
                      onChanged: (v) => setDialog(() => size = v),
                    ),
                  ),
                  Text(size.round().toString()),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final next = _settings.copyWith(listBackground: bg, listTextSize: size);
    await AppStorage.saveSettings(next);
    if (mounted) setState(() => _settings = next);
  }

  Future<void> _toggleReaderBlock() async {
    final next = _settings.copyWith(readerBlocked: !_settings.readerBlocked);
    await AppStorage.saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
    showMessage(context, next.readerBlocked ? 'تم حظر وضع القارئ على هذا الجهاز' : 'تم إلغاء الحظر');
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(_settings.listBackground);
    final isLight = bg.computeLuminance() > .45;
    final ink = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.isDeveloper ? '$appName · وضع المطوّر' : 'الدروس والملخصات'),
        actions: [
          if (widget.isDeveloper)
            IconButton(tooltip: 'استيراد ملف للتعديل', onPressed: _importLesson, icon: const Icon(Icons.file_open)),
          IconButton(tooltip: 'الإعدادات', onPressed: _openSettings, icon: const Icon(Icons.settings)),
          IconButton(tooltip: 'للتواصل', onPressed: _openContact, icon: const Icon(Icons.person_outline)),
          if (widget.isDeveloper)
            IconButton(
              tooltip: _settings.readerBlocked ? 'إلغاء حظر وضع القارئ' : 'حظر وضع القارئ',
              onPressed: _toggleReaderBlock,
              icon: Icon(_settings.readerBlocked ? Icons.lock_open : Icons.block),
            ),
          IconButton(tooltip: 'خروج', onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: widget.isDeveloper
          ? FloatingActionButton.extended(
              onPressed: _createLesson,
              icon: const Icon(Icons.add),
              label: const Text('إضافة درس'),
            )
          : null,
      body: _buildBody(isLight, ink),
    );
  }

  Widget _buildBody(bool isLight, Color ink) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    if (!widget.isDeveloper && _settings.readerBlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 58, color: ink),
              const SizedBox(height: 12),
              Text(
                'تم إيقاف الوصول إلى الدروس حالياً',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ink),
              ),
            ],
          ),
        ),
      );
    }

    if (_lessons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.isDeveloper ? 'لا توجد دروس بعد. اضغط «إضافة درس» للبدء.' : 'لا توجد دروس بعد',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isDeveloper ? 90 : 16),
      itemCount: _lessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final lesson = _lessons[i];
        return Card(
          color: isLight ? Colors.white : const Color(0xff1b1d2b),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.menu_book)),
            title: Text(
              lesson.title.isEmpty ? 'درس بلا عنوان' : lesson.title,
              style: TextStyle(fontSize: _settings.listTextSize, color: ink),
            ),
            subtitle: Text(
              '${lesson.pages.length} صفحة${lesson.videoUrl.isNotEmpty ? ' · فيديو مرفق' : ''}',
              style: TextStyle(color: ink.withValues(alpha: .65)),
            ),
            trailing: widget.isDeveloper
                ? PopupMenuButton<String>(
                    iconColor: ink,
                    onSelected: (v) {
                      if (v == 'edit') _openEditor(lesson);
                      if (v == 'delete') _deleteLesson(lesson);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  )
                : Icon(Icons.chevron_left, color: ink),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReaderScreen(lesson: lesson)),
            ),
          ),
        );
      },
    );
  }
}
