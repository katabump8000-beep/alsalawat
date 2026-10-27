import 'package:uuid/uuid.dart';

import 'constants.dart';

const _uuid = Uuid();

/// يطابق ⟦الإجابة⟧ داخل نص الصفحة.
final RegExp answerPattern = RegExp('$answerOpen(.*?)$answerClose', dotAll: true);

String stripAnswerMarkers(String s) =>
    s.replaceAll(answerOpen, '').replaceAll(answerClose, '');

/// عنصر عائم على الصفحة: صورة أو بطاقة أو جدول. الإحداثيات بنقاط A4 (595×842).
class PageObject {
  PageObject({
    String? id,
    required this.type, // image | card | table
    this.x = 80,
    this.y = 160,
    this.w = 220,
    this.h = 120,
    this.text = '',
    this.fill = 0xffffffff,
    this.textColor = 0xff1f2430,
    this.shape = 'rounded', // rect | rounded | circle
    this.rows = 3,
    this.cols = 3,
    List<String>? cells,
    this.path = '',
    this.header = 0xffc5cae9,
  })  : id = id ?? _uuid.v4(),
        cells = cells ?? [];

  final String id;
  String type;
  double x, y, w, h;
  String text;
  int fill, textColor;
  String shape;
  int rows, cols;
  List<String> cells;
  String path;
  int header;

  String cell(int r, int c) {
    final i = r * cols + c;
    return i >= 0 && i < cells.length ? cells[i] : '';
  }

  void resize(int newRows, int newCols) {
    final out = <String>[];
    for (var r = 0; r < newRows; r++) {
      for (var c = 0; c < newCols; c++) {
        out.add(r < rows && c < cols ? cell(r, c) : '');
      }
    }
    rows = newRows;
    cols = newCols;
    cells = out;
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type, 'x': x, 'y': y, 'w': w, 'h': h, 'text': text,
        'fill': fill, 'textColor': textColor, 'shape': shape, 'rows': rows,
        'cols': cols, 'cells': cells, 'path': path, 'header': header,
      };

  factory PageObject.fromJson(Map<String, dynamic> j) => PageObject(
        id: j['id'] as String?,
        type: (j['type'] as String?) ?? 'card',
        x: (j['x'] as num?)?.toDouble() ?? 80,
        y: (j['y'] as num?)?.toDouble() ?? 160,
        w: (j['w'] as num?)?.toDouble() ?? 220,
        h: (j['h'] as num?)?.toDouble() ?? 120,
        text: (j['text'] as String?) ?? '',
        fill: (j['fill'] as num?)?.toInt() ?? 0xffffffff,
        textColor: (j['textColor'] as num?)?.toInt() ?? 0xff1f2430,
        shape: (j['shape'] as String?) ?? 'rounded',
        rows: (j['rows'] as num?)?.toInt() ?? 3,
        cols: (j['cols'] as num?)?.toInt() ?? 3,
        cells: (j['cells'] as List?)?.map((e) => e.toString()).toList(),
        path: (j['path'] as String?) ?? '',
        header: (j['header'] as num?)?.toInt() ?? 0xffc5cae9,
      );
}

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
    this.fontPt = 13,
    this.inkColor = 0xff1f2430,
    this.lineOpacity = .2,
    this.lineFactor = 1.8,
    this.coverFront = '',
    this.coverBack = '',
    List<List<int>>? runs,
    List<List<PageObject>>? objects,
  })  : id = id ?? _uuid.v4(),
        pages = (pages == null || pages.isEmpty) ? [''] : pages,
        pageRuns = runs ?? [],
        pageObjects = objects ?? [] {
    sync();
  }

  /// يُبقي قوائم التنسيق والعناصر بنفس عدد الصفحات.
  void sync() {
    while (pageRuns.length < pages.length) {
      pageRuns.add(<int>[]);
    }
    if (pageRuns.length > pages.length) pageRuns.removeRange(pages.length, pageRuns.length);
    while (pageObjects.length < pages.length) {
      pageObjects.add(<PageObject>[]);
    }
    if (pageObjects.length > pages.length) pageObjects.removeRange(pages.length, pageObjects.length);
  }

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
  double fontPt;
  int inkColor;
  double lineOpacity;
  double lineFactor;
  String coverFront;
  String coverBack;
  List<List<int>> pageRuns; // تلوين كل حرف: [بداية، نهاية، لون النص، لون التظليل]...
  List<List<PageObject>> pageObjects;

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
        'fontPt': fontPt,
        'inkColor': inkColor,
        'lineOpacity': lineOpacity,
        'lineFactor': lineFactor,
        'coverFront': coverFront,
        'coverBack': coverBack,
        'runs': pageRuns,
        'objects': pageObjects.map((l) => l.map((o) => o.toJson()).toList()).toList(),
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
        fontPt: (j['fontPt'] as num?)?.toDouble() ?? 13,
        inkColor: (j['inkColor'] as num?)?.toInt() ?? 0xff1f2430,
        lineOpacity: (j['lineOpacity'] as num?)?.toDouble() ?? .2,
        lineFactor: (j['lineFactor'] as num?)?.toDouble() ?? 1.8,
        coverFront: (j['coverFront'] as String?) ?? '',
        coverBack: (j['coverBack'] as String?) ?? '',
        runs: (j['runs'] as List?)
            ?.map((e) => (e as List).map((x) => (x as num).toInt()).toList())
            .toList(),
        objects: (j['objects'] as List?)
            ?.map((l) => (l as List)
                .map((o) => PageObject.fromJson(Map<String, dynamic>.from(o as Map)))
                .toList())
            .toList(),
      );
}
