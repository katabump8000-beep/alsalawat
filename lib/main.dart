import 'dart:convert';
import 'dart:math' as m;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const devPass = 'hamzanjar8000.H';
const pal = [0xFF000000, 0xFFFFFFFF, 0x00FFFFFF, 0xFFFF1744, 0xFFFF5722, 0xFFFF9100, 0xFFFFEA00, 0xFFC6FF00, 0xFF76FF03, 0xFF00E676, 0xFF1DE9B6, 0xFF00E5FF, 0xFF00B0FF, 0xFF2979FF, 0xFF651FFF, 0xFFD500F9, 0xFFF50057, 0xFFFF4081, 0xFFFFD740, 0xFFB2FF59, 0xFF64FFDA, 0xFF18FFFF, 0xFF304FFE, 0xFF6200EA, 0xFFFFE0B2, 0xFFC8E6C9, 0xFFBBDEFB, 0xFFF8BBD0, 0xFFE1BEE7, 0xFFFFF9C4];
const icons = {'tree': Icons.account_tree, 'card': Icons.crop_square, 'table': Icons.grid_on, 'pyr': Icons.change_history, 'shape': Icons.category};

class Th {
  final String n; final int bg, acc; final bool dark, glow;
  const Th(this.n, this.bg, this.acc, {this.dark = false, this.glow = false});
}
const themes = [
  Th('كلاسيكي', 0xFFF4F7F2, 0xFF2E7D32), Th('أزرق', 0xFFEAF2FB, 0xFF1565C0),
  Th('بنفسجي', 0xFFF3ECF9, 0xFF6A1B9A), Th('دافئ', 0xFFFFF4E5, 0xFFE65100),
  Th('ليلي متوهج', 0xFF0B1020, 0xFF00E5FF, dark: true, glow: true)];
final themeN = ValueNotifier<int>(0);
Th get th => themes[themeN.value];
List<Map> projects = [];
late SharedPreferences prefs;
void save() => prefs.setString('p', jsonEncode(projects));
final _ck = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
final _st = AudioPlayer();
void tap() { HapticFeedback.selectionClick(); _ck.play(AssetSource('click.mp3')).catchError((_) {}); }
void saat() { HapticFeedback.mediumImpact(); _st.play(AssetSource('saat.mp3')).catchError((_) {}); }
double dn(x) => (x as num).toDouble();
Map nc([double sz = 22, int bg = 0xFFFFFFFF]) => {'t': '', 'fg': 0xFF000000, 'bg': bg, 'sz': sz};
double fw(Map x) => m.max(90.0, (x['t'] as String).length * dn(x['sz']) * .55 + 30);
double fh(Map x) => dn(x['sz']) * 1.9 + 10;
double rowH(List r) => r.fold<double>(40, (a, x) => m.max(a, fh(x)));
const txtP = {'n': 'نص حر', 'w': 220.0, 'h': 60.0, 's': -2, 'r': 0.0};
List flist(Map p) => p['type'] == 'shape' ? p['d']['s'] as List : (p['f'] ??= []) as List;
const pgW = 600.0, pgH = 849.0;
int pages(Map p) => (p['pg'] ?? 1) as int;
final selN = ValueNotifier<Map?>(null);
double _acc = 0;

const shapes = [
  {'n': 'مستطيل كبير', 'w': 280.0, 'h': 140.0, 's': 0, 'r': 10.0},
  {'n': 'مستطيل صغير', 'w': 160.0, 'h': 80.0, 's': 0, 'r': 10.0},
  {'n': 'مربع', 'w': 120.0, 'h': 120.0, 's': 0, 'r': 6.0},
  {'n': 'مربع كبير', 'w': 200.0, 'h': 200.0, 's': 0, 'r': 6.0},
  {'n': 'مستطيل طويل', 'w': 100.0, 'h': 220.0, 's': 0, 'r': 10.0},
  {'n': 'شريط عريض', 'w': 300.0, 'h': 60.0, 's': 0, 'r': 6.0},
  {'n': 'مستدير الحواف', 'w': 180.0, 'h': 100.0, 's': 0, 'r': 28.0},
  {'n': 'كبسولة', 'w': 200.0, 'h': 70.0, 's': 0, 'r': 999.0},
  {'n': 'دائرة', 'w': 140.0, 'h': 140.0, 's': -1, 'r': 0.0},
  {'n': 'دائرة كبيرة', 'w': 220.0, 'h': 220.0, 's': -1, 'r': 0.0},
  {'n': 'بيضاوي', 'w': 220.0, 'h': 120.0, 's': -1, 'r': 0.0},
  {'n': 'مثلث', 'w': 170.0, 'h': 150.0, 's': 3, 'r': 0.0},
  {'n': 'معيّن', 'w': 160.0, 'h': 160.0, 's': 4, 'r': 0.0},
  {'n': 'خماسي', 'w': 160.0, 'h': 160.0, 's': 5, 'r': 0.0},
  {'n': 'سداسي', 'w': 170.0, 'h': 150.0, 's': 6, 'r': 0.0}];
Map si(Map s, double x, double y) => {'w': s['w'], 'h': s['h'], 's': s['s'], 'r': s['r'], 'x': x, 'y': y, 'c': s['s'] == -2 ? nc(26, 0x00FFFFFF) : nc()};
Rect rect(Map o) => Rect.fromLTWH(dn(o['x']), dn(o['y']), dn(o['w']), dn(o['h']));
bool hit(Map it, List all) => all.any((o) => !identical(o, it) && rect(it).overlaps(rect(o)));

Future go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));
void toast(BuildContext c, String s) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));
Widget chips(List<String> l, int sel, void Function(int) f) => Wrap(spacing: 6, children: [for (int i = 0; i < l.length; i++) ChoiceChip(label: Text(l[i]), selected: sel == i, onSelected: (_) => f(i))]);
Widget colors(Map x, String key, VoidCallback f) => Wrap(spacing: 6, runSpacing: 6, children: [for (final v in pal) GestureDetector(onTap: () { x[key] = v; f(); }, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Color(v), shape: BoxShape.circle, border: Border.all(color: Colors.grey, width: x[key] == v ? 4 : 1))))]);

Future<String?> ask(BuildContext c, String t, {bool pw = false}) {
  final k = TextEditingController();
  return showDialog<String>(context: c, builder: (d) => AlertDialog(title: Text(t), content: TextField(controller: k, obscureText: pw, autofocus: true),
    actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, k.text.trim()), child: const Text('تم'))]));
}
Future<bool> sure(BuildContext c) async => (await showDialog<bool>(context: c, builder: (d) => AlertDialog(title: const Text('تأكيد الحذف؟'),
  actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لا')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف'))]))) ?? false;

Future editCell(BuildContext c, Map x, VoidCallback up) {
  final k = TextEditingController(text: x['t']);
  return showDialog(context: c, builder: (d) => StatefulBuilder(builder: (d, ss) => AlertDialog(
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: k, maxLines: null, autofocus: true, style: TextStyle(fontSize: dn(x['sz']), color: Color(x['fg'])), onChanged: (v) { x['t'] = v; up(); }),
      Slider(value: dn(x['sz']), min: 12, max: 60, onChanged: (v) { x['sz'] = v; ss(() {}); up(); }),
      const Text('لون النص'), colors(x, 'fg', () { ss(() {}); up(); }),
      const SizedBox(height: 8), const Text('خلفية النص'), colors(x, 'bg', () { ss(() {}); up(); }),
      const SizedBox(height: 8), const Text('تأثيرات'), chips(['بدون', 'توهج', 'عوم', 'نبض', 'اهتزاز', 'لمعان'], (x['fx'] ?? 0) as int, (i) { x['fx'] = i; ss(() {}); up(); })])),
    actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('تم'))])));
}

class Poly extends CustomPainter {
  final int n; final Color f, s;
  Poly(this.n, this.f, this.s);
  @override
  void paint(Canvas c, Size z) {
    final p = Path();
    for (int i = 0; i < n; i++) {
      final a = -m.pi / 2 + 2 * m.pi * i / n;
      final x = z.width / 2 + z.width / 2 * m.cos(a) * .98, y = z.height / 2 + z.height / 2 * m.sin(a) * .98;
      if (i == 0) { p.moveTo(x, y); } else { p.lineTo(x, y); }
    }
    p.close();
    c.drawPath(p, Paint()..color = f);
    c.drawPath(p, Paint()..color = s..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(_) => true;
}

class Fx extends StatefulWidget {
  final int k; final Widget child;
  const Fx(this.k, this.child, {super.key});
  @override
  State<Fx> createState() => _F();
}
class _F extends State<Fx> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  void go() { if (widget.k == 0) { a.stop(); } else if (!a.isAnimating) { a.repeat(reverse: true); } }
  @override
  void initState() { super.initState(); go(); }
  @override
  void didUpdateWidget(Fx o) { super.didUpdateWidget(o); go(); }
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) {
    if (widget.k == 0) return widget.child;
    return AnimatedBuilder(animation: a, child: widget.child, builder: (_, w) {
      final v = a.value;
      switch (widget.k) {
        case 1: return DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Color(th.acc).withOpacity(.4 + .6 * v), blurRadius: 8 + 22 * v, spreadRadius: 2 * v)]), child: w);
        case 2: return Transform.translate(offset: Offset(0, -10 * v), child: w);
        case 3: return Transform.scale(scale: 1 + .1 * v, child: w);
        case 4: return Transform.rotate(angle: .08 * (v * 2 - 1), child: w);
        default: return ShaderMask(blendMode: BlendMode.srcATop, shaderCallback: (r) => LinearGradient(colors: const [Colors.white, Color(0xFFFFF59D), Colors.white], stops: [(v - .25).clamp(0.0, 1.0), v, (v + .25).clamp(0.0, 1.0)]).createShader(r), child: w);
      }
    });
  }
}

class Frame extends CustomPainter {
  final Color c; final double t;
  Frame(this.c, this.t);
  @override
  void paint(Canvas g, Size z) {
    final rr = RRect.fromRectAndRadius((Offset.zero & z).deflate(4), const Radius.circular(22));
    g.drawRRect(rr, Paint()..color = c.withOpacity(.45 + .45 * t)..style = PaintingStyle.stroke..strokeWidth = 26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    g.drawRRect(rr, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 5);
  }
  @override
  bool shouldRepaint(Frame o) => true;
}

Widget box(Map x, Quiz? q, VoidCallback? ed, {double? w, double? h, int s = 0, double r = 10, bool top = false}) {
  final st = TextStyle(fontSize: dn(x['sz']), color: Color(x['fg']), height: 1.3);
  final side = BorderSide(color: Color(th.acc), width: 2);
  final txt = q == null ? Text(x['t'] == '' ? '…' : x['t'], style: st, textAlign: top ? TextAlign.start : TextAlign.center) : q.field(x, st, !top);
  final inner = Align(alignment: top ? AlignmentDirectional.topStart : Alignment.center, child: Padding(padding: const EdgeInsets.all(8), child: txt));
  final Widget core = s == -2 ? DecoratedBox(decoration: BoxDecoration(color: Color(x['bg']), borderRadius: BorderRadius.circular(8)), child: inner) : s > 2
      ? CustomPaint(painter: Poly(s, Color(x['bg']), side.color), child: inner)
      : DecoratedBox(decoration: ShapeDecoration(color: Color(x['bg']), shape: s == -1 ? OvalBorder(side: side) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side),
          shadows: th.glow ? [BoxShadow(color: Color(th.acc), blurRadius: 14)] : null), child: inner);
  return GestureDetector(onTap: ed, child: Fx((x['fx'] ?? 0) as int, SizedBox(width: w ?? 120, height: h ?? 56, child: core)));
}

Widget item(Map it, Quiz? q, bool edit, VoidCallback up, BuildContext c, [VoidCallback? del]) {
  final s = it['s'] as int;
  final b = box(it['c'], q, edit ? () => editCell(c, it['c'], up) : null, w: dn(it['w']), h: dn(it['h']), s: s, r: dn(it['r']), top: s == 0 || s == -2);
  if (!edit) return b;
  return ValueListenableBuilder<Map?>(valueListenable: selN, builder: (_, sel, __) {
    final on = identical(sel, it);
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(onLongPress: () { HapticFeedback.heavyImpact(); selN.value = it; }, child: b),
      if (on) Positioned(right: -14, bottom: -14, child: GestureDetector(onPanUpdate: (e) { it['w'] = m.max(50.0, dn(it['w']) + e.delta.dx); it['h'] = m.max(40.0, dn(it['h']) + e.delta.dy); up(); },
        child: const CircleAvatar(radius: 16, child: Icon(Icons.open_in_full, size: 16)))),
      if (on && del != null) Positioned(left: -14, top: -14, child: GestureDetector(onTap: del, child: const CircleAvatar(radius: 16, backgroundColor: Colors.red, child: Icon(Icons.close, size: 16, color: Colors.white))))]);
  });
}

class Ruled extends CustomPainter {
  final Color bg; final bool lines, sep; final int n;
  Ruled(this.bg, this.lines, this.sep, this.n);
  @override
  void paint(Canvas g, Size z) {
    g.drawRect(Offset.zero & z, Paint()..color = bg);
    if (lines) {
      final pn = Paint()..color = (bg.computeLuminance() < .4 ? Colors.white : Colors.black).withOpacity(.07)..strokeWidth = 1;
      for (double y = 40; y < z.height; y += 34) { g.drawLine(Offset(0, y), Offset(z.width, y), pn); }
    }
    if (sep) {
      final ps = Paint()..color = Colors.grey.withOpacity(.6)..strokeWidth = 2;
      for (int k = 1; k < n; k++) { g.drawLine(Offset(0, k * pgH), Offset(z.width, k * pgH), ps); }
    }
  }
  @override
  bool shouldRepaint(Ruled o) => true;
}

Future<ui.Image> snap(BuildContext c, Map p) async {
  final key = GlobalKey();
  final e = OverlayEntry(builder: (_) => Positioned(left: -9999, top: 0, child: Directionality(textDirection: TextDirection.rtl,
    child: RepaintBoundary(key: key, child: Material(color: Color(p['bg']), child: PV(p, null, false, () {}, pr: true))))));
  Overlay.of(c).insert(e);
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
  final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 2);
  e.remove();
  return img;
}

Future<void> exportPdf(BuildContext c, List<Map> ps) async {
  toast(c, 'جاري تجهيز ملف PDF…');
  final doc = pw.Document();
  for (final p in ps) {
    final img = await snap(c, p);
    final r = img.width / pgW;
    for (int k = 0; k < pages(p); k++) {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(img, Rect.fromLTWH(0, k * pgH * r, img.width.toDouble(), pgH * r), Rect.fromLTWH(0, 0, img.width.toDouble(), pgH * r), Paint());
      final cr = await rec.endRecording().toImage(img.width, (pgH * r).round());
      final bd = await cr.toByteData(format: ui.ImageByteFormat.png);
      final bytes = bd!.buffer.asUint8List();
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill)));
    }
  }
  await Printing.sharePdf(bytes: await doc.save(), filename: 'ALSESI.pdf');
}

class Quiz {
  final bad = ValueNotifier<int>(0);
  final ctl = <Map, TextEditingController>{};
  bool ghost = false, done = false, cheat = false;
  VoidCallback? onDone;
  Widget field(Map x, TextStyle st, [bool ctr = true]) {
    final k = ctl.putIfAbsent(x, () => TextEditingController());
    return Stack(alignment: ctr ? Alignment.center : AlignmentDirectional.topStart, children: [
      if (ghost) Opacity(opacity: .3, child: Text(x['t'], style: st)),
      TextField(controller: k, style: st, maxLines: null, textAlign: ctr ? TextAlign.center : TextAlign.start, decoration: const InputDecoration.collapsed(hintText: ''), onChanged: (_) { tap(); check(); })]);
  }
  void check() {
    bad.value = ctl.entries.where((e) => !(e.key['t'] as String).startsWith(e.value.text)).length;
    if (!done && !cheat && bad.value == 0 && ctl.isNotEmpty && ctl.entries.every((e) => e.key['t'] == e.value.text)) { done = true; onDone?.call(); }
  }
  int help() {
    var n = 0;
    ctl.forEach((x, k) {
      final t = x['t'] as String;
      if (!t.startsWith(k.text)) {
        n++;
        var i = 0;
        while (i < k.text.length && i < t.length && t[i] == k.text[i]) { i++; }
        k.text = t.substring(0, i);
      }
    });
    check();
    return n;
  }
  int solve() {
    var n = 0;
    cheat = true;
    ctl.forEach((x, k) { if (k.text != x['t']) { n++; k.text = x['t']; } });
    check();
    return n;
  }
}

class QuizPage extends StatefulWidget {
  final Map p;
  const QuizPage(this.p, {super.key});
  @override
  State<QuizPage> createState() => _Q();
}
class _Q extends State<QuizPage> with SingleTickerProviderStateMixin {
  final q = Quiz();
  final tc = TransformationController();
  bool inited = false;
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void initState() {
    super.initState();
    q.onDone = () { saat(); showDialog(context: context, builder: (d) => AlertDialog(title: const Text('أحسنت! 🎉'), content: const Text('أجبت كل الخانات صح'), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('حسنًا'))])); };
  }
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) {
    final fit = MediaQuery.of(c).size.width / pgW;
    if (!inited) { inited = true; tc.value = Matrix4.identity()..scale(fit); }
    return Scaffold(backgroundColor: Color(widget.p['bg']),
      body: ValueListenableBuilder<int>(valueListenable: q.bad, builder: (_, b, __) => AnimatedBuilder(animation: a,
        builder: (_, ch) => CustomPaint(foregroundPainter: Frame(b > 0 ? const Color(0xFFFF1744) : const Color(0xFF00E676), a.value), child: ch),
        child: SafeArea(child: Column(children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.close), color: Colors.black, onPressed: () => Navigator.pop(c)),
            TextButton(onPressed: () { saat(); toast(c, 'تم حذف ${q.help()} خطأ'); }, child: const Text('مساعدة')),
            IconButton(icon: const Text('💡', style: TextStyle(fontSize: 22)), onPressed: () { saat(); toast(c, 'تم تصحيح ${q.solve()} خانة'); }),
            IconButton(icon: const Text('🔎', style: TextStyle(fontSize: 22)), onPressed: () { tap(); setState(() => q.ghost = !q.ghost); })]),
          Expanded(child: InteractiveViewer(transformationController: tc, constrained: false, minScale: fit, maxScale: fit * 4, boundaryMargin: EdgeInsets.zero, child: PV(widget.p, q, false, () {})))])))));
  }
}

double colW(Map d, List rows, int i) {
  final cw = (d['cw'] ??= <dynamic>[]) as List;
  while (cw.length <= i) { cw.add(null); }
  if (cw[i] != null) return dn(cw[i]);
  double w = 130;
  for (final r in rows) { if (i < r.length) w = m.max(w, fw(r[i])); }
  return w;
}

class PV extends StatelessWidget {
  final Map p; final Quiz? q; final bool edit, pr; final VoidCallback up;
  const PV(this.p, this.q, this.edit, this.up, {this.pr = false, super.key});
  VoidCallback? ed(BuildContext c, Map x) => edit ? () => editCell(c, x, up) : null;
  Widget tree(BuildContext c, Map n, List? sib) {
    final k = n['k'] as List, x = n['c'] as Map;
    final line = Container(width: 2, height: 30, color: Color(th.acc));
    final Widget conn = edit ? Container(width: 2, height: 36, color: Color(th.acc)) : SizedBox(height: 36, child: Icon(Icons.arrow_downward, size: 30, color: Color(th.acc)));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      box(x, q, ed(c, x), w: fw(x), h: fh(x)),
      if (edit) Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.add_circle), onPressed: () { k.add({'c': nc(), 'k': []}); up(); }),
        if (sib != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { sib.remove(n); up(); })]),
      if (k.isNotEmpty) line,
      if (k.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        for (final e in k) Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: Color(th.acc), width: 2))),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [conn, tree(c, e, k)])))])]);
  }
  Widget body(BuildContext c) {
    final d = p['d'] as Map;
    const pad = EdgeInsets.all(24);
    switch (p['type']) {
      case 'tree':
        return Padding(padding: pad, child: tree(c, d, null));
      case 'card':
        return Padding(padding: pad, child: item(d['i'], q, edit, up, c));
      case 'table':
        final rows = d['rows'] as List;
        return Padding(padding: pad, child: ValueListenableBuilder<Map?>(valueListenable: selN, builder: (_, sel, __) {
          final on = edit && identical(sel, d);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            for (int ri = 0; ri < rows.length; ri++) Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < rows[ri].length; i++) Stack(clipBehavior: Clip.none, children: [
                GestureDetector(onLongPress: edit ? () { HapticFeedback.heavyImpact(); selN.value = d; } : null,
                  child: box(rows[ri][i], q, ed(c, rows[ri][i]), w: colW(d, rows, i), h: rowH(rows[ri]), r: 0)),
                if (on && ri == 0) Positioned(right: -14, top: 0, bottom: 0, child: GestureDetector(
                  onPanUpdate: (e) { (d['cw'] as List)[i] = m.max(60.0, colW(d, rows, i) + e.delta.dx); up(); },
                  child: const Center(child: CircleAvatar(radius: 14, child: Icon(Icons.swap_horiz, size: 16)))))]),
              if (edit) IconButton(icon: const Icon(Icons.add_circle), onPressed: () { rows[ri].add(nc()); up(); }),
              if (edit && rows.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { rows.removeAt(ri); up(); })]),
            if (edit) IconButton(icon: const Icon(Icons.add_circle), onPressed: () { rows.add([for (final _ in rows.last) nc()]); up(); })]);
        }));
      case 'pyr':
        final cells = d['cells'] as List;
        return Padding(padding: pad, child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < cells.length; i++) Padding(padding: const EdgeInsets.all(2), child: box(cells[i], q, ed(c, cells[i]), w: m.max(90.0 + i * 28, fw(cells[i])), h: fh(cells[i])))]));
      default:
        return const SizedBox.shrink();
    }
  }
  @override
  Widget build(BuildContext c) {
    final fl = flist(p);
    final n = pages(p);
    return SizedBox(width: pgW, height: pgH * n, child: Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque,
        onTapUp: edit ? (e) {
          selN.value = null;
          final it = si(txtP, m.min(e.localPosition.dx, pgW - 230), e.localPosition.dy);
          fl.add(it);
          up();
          editCell(c, it['c'], up).then((_) { if ((it['c']['t'] as String).isEmpty) { fl.remove(it); up(); } });
        } : null,
        child: CustomPaint(painter: Ruled(Color(p['bg']), p['ln'] != false, !pr, n)))),
      Positioned(top: 0, left: 0, right: 0, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter, child: body(c))),
      for (final it in fl) Positioned(left: dn(it['x']), top: dn(it['y']), child: Drag(it, fl, edit, up, item(it, q, edit, up, c, () { fl.remove(it); up(); }))),
      if (edit) Positioned(left: 0, right: 0, bottom: 0, height: 36, child: GestureDetector(
        onVerticalDragUpdate: (e) {
          _acc += e.delta.dy;
          if (_acc > 60) { p['pg'] = n + 1; _acc = 0; up(); } else if (_acc < -60 && n > 1) { p['pg'] = n - 1; _acc = 0; up(); }
        },
        child: Container(color: Color(th.acc).withOpacity(.18), child: Center(child: Text('⌄  اسحب هنا لتكبير الصفحة  ⌄', style: TextStyle(fontSize: 14, color: Color(th.acc)))))))]));
  }
}

class Drag extends StatefulWidget {
  final Map it; final List all; final bool on; final VoidCallback up; final Widget child;
  const Drag(this.it, this.all, this.on, this.up, this.child, {super.key});
  @override
  State<Drag> createState() => _D();
}
class _D extends State<Drag> {
  double sx = 0, sy = 0;
  @override
  Widget build(BuildContext c) {
    final it = widget.it;
    if (!widget.on) return widget.child;
    return GestureDetector(
      onPanStart: (_) { sx = dn(it['x']); sy = dn(it['y']); },
      onPanUpdate: (e) { it['x'] = dn(it['x']) + e.delta.dx; it['y'] = dn(it['y']) + e.delta.dy; widget.up(); },
      onPanEnd: (_) { if (hit(it, widget.all)) { it['x'] = sx; it['y'] = sy; } widget.up(); },
      child: widget.child);
  }
}

class ProjPage extends StatefulWidget {
  final Map p; final bool dev;
  const ProjPage(this.p, this.dev, {super.key});
  @override
  State<ProjPage> createState() => _P();
}
class _P extends State<ProjPage> {
  final tc = TransformationController();
  double fit = 1;
  bool inited = false;
  void up() { save(); setState(() {}); }
  void zoom(double f) {
    final cur = tc.value.getMaxScaleOnAxis();
    final n = (cur * f).clamp(fit, fit * 4).toDouble();
    tc.value = tc.value.clone()..scale(n / cur);
  }
  void nav(int dlt) {
    final i = projects.indexOf(widget.p) + dlt;
    if (i < 0 || i >= projects.length) return;
    saat();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProjPage(projects[i], widget.dev)));
  }
  void addShape() => showModalBottomSheet(context: context, builder: (d) => ListView(children: [
    for (final s in [txtP, ...shapes]) ListTile(leading: Icon(s['s'] == -2 ? Icons.text_fields : Icons.category), title: Text(s['n'] as String), onTap: () {
      Navigator.pop(d);
      final it = si(s, 200, 200);
      final l = flist(widget.p);
      for (int i = 0; i < 300 && hit(it, l); i++) {
        it['x'] = dn(it['x']) + 40;
        if (dn(it['x']) > 360) { it['x'] = 0.0; it['y'] = dn(it['y']) + 40; }
      }
      l.add(it);
      up();
    })]));
  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    fit = MediaQuery.of(c).size.width / pgW;
    if (!inited) { inited = true; tc.value = Matrix4.identity()..scale(fit); }
    return Scaffold(backgroundColor: Color(p['bg']),
      appBar: AppBar(title: Text(p['name']), actions: [
        IconButton(icon: const Icon(Icons.zoom_in), onPressed: () => zoom(1.25)),
        IconButton(icon: const Icon(Icons.zoom_out), onPressed: () => zoom(.8)),
        PopupMenuButton<int>(
          onSelected: (v) {
            if (v == 0) { exportPdf(c, [p]); }
            else if (v == 1) { showDialog(context: c, builder: (d) => StatefulBuilder(builder: (d, ss) => AlertDialog(title: const Text('خلفية الصفحة'), content: colors(p, 'bg', () { ss(() {}); up(); })))); }
            else { p['ln'] = p['ln'] == false; up(); }
          },
          itemBuilder: (_) => [const PopupMenuItem(value: 0, child: Text('تنزيل PDF')), if (widget.dev) const PopupMenuItem(value: 1, child: Text('خلفية الصفحة')), if (widget.dev) const PopupMenuItem(value: 2, child: Text('خطوط الدفتر'))]),
        if (widget.dev) TextButton(onPressed: () { saat(); save(); Navigator.pop(c); }, child: const Text('حفظ الدرس'))]),
      floatingActionButton: widget.dev ? FloatingActionButton(onPressed: addShape, child: const Text('◆', style: TextStyle(fontSize: 26))) : null,
      bottomNavigationBar: SafeArea(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton(onPressed: () => nav(-1), child: const Text('🔜', style: TextStyle(fontSize: 28))),
        Text('${projects.indexOf(p) + 1} / ${projects.length}'),
        TextButton(onPressed: () => nav(1), child: const Text('🔚', style: TextStyle(fontSize: 28)))])),
      body: Stack(children: [
        InteractiveViewer(transformationController: tc, constrained: false, minScale: fit, maxScale: fit * 4, boundaryMargin: EdgeInsets.zero, child: PV(p, null, widget.dev, up)),
        if (!widget.dev) Positioned(bottom: 12, left: 20, right: 20, child: SizedBox(height: 60, child: FilledButton(onPressed: () { saat(); go(c, QuizPage(p)); }, child: const Text('اختبار', style: TextStyle(fontSize: 24)))))]));
  }
}

class Glow extends StatefulWidget {
  final Widget child;
  const Glow({super.key, required this.child});
  @override
  State<Glow> createState() => _G();
}
class _G extends State<Glow> with SingleTickerProviderStateMixin {
  late final a = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: a, child: widget.child, builder: (_, w) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(.3 + .5 * a.value), blurRadius: 6 + 14 * a.value)]), child: w));
}

class Home extends StatefulWidget {
  final bool dev;
  const Home({super.key, required this.dev});
  @override
  State<Home> createState() => _H();
}
class _H extends State<Home> {
  void pick(BuildContext c) => showDialog(context: c, builder: (d) => SimpleDialog(title: const Text('اختر درسًا للاختبار'), children: [
    for (final p in projects) SimpleDialogOption(onPressed: () { Navigator.pop(d); go(c, QuizPage(p)); }, child: Text(p['name'], style: const TextStyle(fontSize: 18)))]));
  void pdfPick(BuildContext c) => showDialog(context: c, builder: (d) => SimpleDialog(title: const Text('تنزيل PDF للطباعة'), children: [
    SimpleDialogOption(onPressed: () { Navigator.pop(d); exportPdf(c, List<Map>.from(projects)); }, child: const Text('كل الدروس (ملخص واحد)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    for (final p in projects) SimpleDialogOption(onPressed: () { Navigator.pop(d); exportPdf(c, [p]); }, child: Text(p['name'], style: const TextStyle(fontSize: 18)))]));
  void settings(BuildContext c) => showDialog(context: c, builder: (d) => SimpleDialog(title: const Text('الإعدادات: النماذج'), children: [
    for (int i = 0; i < themes.length; i++) ListTile(title: Text('نموذج ${i + 1}: ${themes[i].n}'), trailing: themeN.value == i ? const Icon(Icons.check) : null,
      onTap: () { themeN.value = i; prefs.setInt('t', i); Navigator.pop(d); })]));
  void create(BuildContext c) => showModalBottomSheet(context: c, builder: (d) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
    for (final t in [['tree', 'شجرة متفرعة'], ['card', 'بطاقة'], ['table', 'جدول'], ['shape', 'تشكيل']])
      ListTile(leading: Icon(icons[t[0]]), title: Text(t[1]), onTap: () async { Navigator.pop(d); await setup(c, t[0]); setState(() {}); })])));
  void imp(BuildContext c) async {
    final t = await ask(c, 'الصق الدرس هنا');
    if (t == null || t.isEmpty) return;
    try {
      final j = jsonDecode(t) as Map;
      if (j['name'] == null || j['d'] == null) throw 0;
      projects.add(j);
      save();
      setState(() {});
      if (c.mounted) toast(c, 'تمت إضافة الدرس');
    } catch (_) {
      if (c.mounted) toast(c, 'النص غير صالح');
    }
  }
  Future<void> setup(BuildContext c, String type) async {
    final k = TextEditingController();
    int opt = 0;
    double n = 10;
    final ok = await showDialog<bool>(context: c, builder: (d) => StatefulBuilder(builder: (d, ss) => AlertDialog(
      title: const Text('اسم المشروع'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: k, autofocus: true, decoration: const InputDecoration(hintText: 'مثال: فعل الماضي')),
        const SizedBox(height: 12),
        if (type == 'tree') chips(['عنوان ضخم', 'عنوان وسط', 'عنوان بكلمة'], opt, (i) => ss(() => opt = i)),
        if (type == 'card') chips([for (final s in shapes) s['n'] as String], opt, (i) => ss(() => opt = i)),
        if (type == 'table') chips(['2', '3', '4', '5', 'هرم'], opt, (i) => ss(() => opt = i)),
        if (type == 'table' && opt == 4) Slider(value: n, min: 3, max: 40, divisions: 37, label: '${n.round()} خانة', onChanged: (v) => ss(() => n = v))])),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إنشاء'))])));
    if (ok != true || k.text.trim().isEmpty) return;
    Map d;
    var t = type;
    if (type == 'tree') {
      d = {'c': nc([40.0, 30.0, 22.0][opt]), 'k': []};
    } else if (type == 'card') {
      d = {'i': si(shapes[opt], 0, 0)};
    } else if (type == 'table' && opt == 4) {
      t = 'pyr';
      final cnt = n.round();
      d = {'cells': [for (int i = 0; i < cnt; i++) nc(18, Color.lerp(const Color(0xFFD32F2F), const Color(0xFF2E7D32), i / (cnt - 1))!.value)]};
    } else if (type == 'table') {
      d = {'rows': [[for (int i = 0; i < opt + 2; i++) nc()]]};
    } else {
      d = {'s': []};
    }
    projects.add({'name': k.text.trim(), 'type': t, 'bg': 0xFFFFFFFF, 'd': d});
    save();
    if (c.mounted) await go(c, ProjPage(projects.last, true));
  }
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('ALSESI'), actions: [
      Glow(child: TextButton(onPressed: () => pick(c), child: const Text('اختبار', style: TextStyle(fontWeight: FontWeight.bold)))),
      IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => pdfPick(c)),
      IconButton(icon: const Icon(Icons.file_download), onPressed: () => imp(c)),
      IconButton(icon: const Icon(Icons.settings), onPressed: () => settings(c))]),
    floatingActionButton: widget.dev ? FloatingActionButton(onPressed: () => create(c), child: const Icon(Icons.add)) : null,
    body: projects.isEmpty
      ? Center(child: Text(widget.dev ? 'اضغط + لإنشاء أول درس' : 'لا توجد دروس بعد'))
      : ListView(padding: const EdgeInsets.all(12), children: [
          for (final p in projects) Card(child: ListTile(
            leading: Icon(icons[p['type']]), title: Text(p['name'], style: const TextStyle(fontSize: 20)),
            trailing: widget.dev ? PopupMenuButton<int>(
              onSelected: (v) async {
                if (v == 0) { Clipboard.setData(ClipboardData(text: jsonEncode(p))); toast(c, 'تم نسخ الدرس. أرسله لطلابك ليلصقوه بزر الاستيراد'); }
                else if (v == 1) { final cp = jsonDecode(jsonEncode(p)) as Map; cp['name'] = '${p['name']} (نسخة)'; projects.add(cp); save(); setState(() {}); }
                else if (await sure(c)) { projects.remove(p); save(); setState(() {}); }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 0, child: Text('نسخ للمشاركة')), PopupMenuItem(value: 1, child: Text('تكرار')), PopupMenuItem(value: 2, child: Text('حذف'))]) : null,
            onTap: () async { saat(); await go(c, ProjPage(p, widget.dev)); setState(() {}); }))]));
}

class Login extends StatelessWidget {
  const Login({super.key});
  Widget big(String t, VoidCallback f) => SizedBox(width: 300, height: 76, child: FilledButton(style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 24)), onPressed: () { saat(); f(); }, child: Text(t)));
  @override
  Widget build(BuildContext c) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('ALSESI', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Color(th.acc))),
    const SizedBox(height: 40),
    big('الدخول كطالب', () => go(c, const Home(dev: false))),
    const SizedBox(height: 20),
    big('الدخول كمطور', () async {
      final t = await ask(c, 'ضع كلمة سر المطورين', pw: true);
      if (t == devPass) { go(c, const Home(dev: true)); } else if (t != null) { toast(c, 'كلمة السر خاطئة'); }
    })])));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(valueListenable: themeN, builder: (_, __, ___) => MaterialApp(
    title: 'ALSESI', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Color(th.acc), brightness: th.dark ? Brightness.dark : Brightness.light, scaffoldBackgroundColor: Color(th.bg)),
    builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
    home: const Login()));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  projects = (jsonDecode(prefs.getString('p') ?? '[]') as List).map((e) => e as Map).toList();
  themeN.value = prefs.getInt('t') ?? 0;
  runApp(const App());
}
