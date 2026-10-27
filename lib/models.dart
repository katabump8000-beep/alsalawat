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
    this.wmSize = 38,
    this.wmOpacity = .08,
    this.wmColor = 0xff9e9e9e,
    this.titleColor = 0xff1f2430,
    this.titleBg = 0,
  })  : id = id ?? _uuid.v4(),
        pages = (pages == null || pages.isEmpty) ? [''] : pages;

  final String id;
  String title;
  List<String> pages;
  String coverNote;
  String watermark;
  String footerNote;
  String videoUrl;
  double wmSize;
  double wmOpacity;
  int wmColor;
  int titleColor;
  int titleBg; // 0 = بدون خلفية

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pages': pages,
        'coverNote': coverNote,
        'watermark': watermark,
        'footerNote': footerNote,
        'videoUrl': videoUrl,
        'wmSize': wmSize,
        'wmOpacity': wmOpacity,
        'wmColor': wmColor,
        'titleColor': titleColor,
        'titleBg': titleBg,
      };

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? 'درس بلا عنوان',
        pages: (j['pages'] as List?)?.map((e) => e.toString()).toList(),
        coverNote: (j['coverNote'] as String?) ?? '',
        watermark: (j['watermark'] as String?) ?? '',
        footerNote: (j['footerNote'] as String?) ?? '',
        videoUrl: (j['videoUrl'] as String?) ?? '',
        wmSize: (j['wmSize'] as num?)?.toDouble() ?? 38,
        wmOpacity: (j['wmOpacity'] as num?)?.toDouble() ?? .08,
        wmColor: (j['wmColor'] as num?)?.toInt() ?? 0xff9e9e9e,
        titleColor: (j['titleColor'] as num?)?.toInt() ?? 0xff1f2430,
        titleBg: (j['titleBg'] as num?)?.toInt() ?? 0,
      );
}
