import 'package:uuid/uuid.dart';

import 'constants.dart';

const _uuid = Uuid();

/// يطابق ⟦الإجابة⟧ داخل نص الصفحة.
final RegExp answerPattern = RegExp('$answerOpen(.*?)$answerClose', dotAll: true);

String stripAnswerMarkers(String s) =>
    s.replaceAll(answerOpen, '').replaceAll(answerClose, '');

class Lesson {
  Lesson({
    String? id,
    this.title = 'درس جديد',
    List<String>? pages,
    this.coverNote = '',
    this.watermark = '',
    this.footerNote = '',
    this.videoUrl = '',
  })  : id = id ?? _uuid.v4(),
        pages = (pages == null || pages.isEmpty) ? [''] : pages;

  final String id;
  String title;
  List<String> pages;
  String coverNote;
  String watermark;
  String footerNote;
  String videoUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pages': pages,
        'coverNote': coverNote,
        'watermark': watermark,
        'footerNote': footerNote,
        'videoUrl': videoUrl,
      };

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? 'درس بلا عنوان',
        pages: (j['pages'] as List?)?.map((e) => e.toString()).toList(),
        coverNote: (j['coverNote'] as String?) ?? '',
        watermark: (j['watermark'] as String?) ?? '',
        footerNote: (j['footerNote'] as String?) ?? '',
        videoUrl: (j['videoUrl'] as String?) ?? '',
      );
}
