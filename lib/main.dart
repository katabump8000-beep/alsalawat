import 'dart:convert';
import 'dart:math' as m;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const devPass = 'hamzanjar8000.H';
const pal = [0xFF000000, 0xFFFFFFFF, 0xFFD32F2F, 0xFFF57C00, 0xFFFBC02D, 0xFF2E7D32, 0xFF1565C0, 0xFF6A1B9A, 0xFFFFE0B2, 0xFFC8E6C9];
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
void tap() => SystemSound.play(SystemSoundType.click);
double dn(x) => (x as num).toDouble();
Map nc([double sz = 18, int bg = 0xFFFFFFFF]) => {'t': '', 'fg': 0xFF000000, 'bg': bg, 'sz': sz};
double fw(Map x) => m.max(90.0, (x['t'] as String).length * dn(x['sz']) * .6 + 36);
double fh(Map x) => dn(x['sz']) * 2 + 14;

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
Map si(Map s, double x, double y) => {'w': s['w'], 'h': s['h'], 's': s['s'], 'r': s['r'], 'x': x, 'y': y, 'c': nc()};
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

void editCell(BuildContext c, Map x, VoidCallback up) {
  final k = TextEditingController(text: x['t']);
  showDialog(context: c, builder: (d) => StatefulBuilder(builder: (d, ss) => AlertDialog(
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: k, maxLines: null, autofocus: true, style: TextStyle(fontSize: dn(x['sz']), color: Color(x['fg'])), onChanged: (v) { x['t'] = v; up(); }),
      Slider(value: dn(x['sz']), min: 12, max: 60, onChanged: (v) { x['sz'] = v; ss(() {}); up(); }),
      const Text('لون النص'), colors(x, 'fg', () { ss(() {}); up(); }),
      const SizedBox(height: 8), const Text('خلفية النص'), colors(x, 'bg', () { ss(() {}); up(); })])),
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

Widget box(Map x, Quiz? q, VoidCallback? ed, {double? w, double? h, int s = 0, double r = 10}) {
  final st = TextStyle(fontSize: dn(x['sz']), color: Color(x['fg']), height: 1.3);
  final side = BorderSide(color: Color(th.acc), width: 2);
  final txt = q == null ? Text(x['t'] == '' ? '…' : x['t'], style: st, textAlign: TextAlign.center) : q.field(x, st);
  final inner = Center(child: Padding(padding: const EdgeInsets.all(8), child: txt));
  final Widget core = s > 2
      ? CustomPaint(painter: Poly(s, Color(x['bg']), side.color), child: inner)
      : DecoratedBox(decoration: ShapeDecoration(color: Color(x['bg']), shape: s == -1 ? OvalBorder(side: side) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side),
          shadows: th.glow ? [BoxShadow(color: Color(th.acc), blurRadius: 14)] : null), child: inner);
  return GestureDetector(onTap: ed, child: SizedBox(width: w ?? 120, height: h ?? 56, child: core));
}

Widget item(Map it, Quiz? q, bool edit, VoidCallback up, BuildContext c, [VoidCallback? del]) {
  final b = box(it['c'], q, edit ? () => editCell(c, it['c'], up) : null, w: dn(it['w']), h: dn(it['h']), s: it['s'], r: dn(it['r']));
  if (!edit) return b;
  return Stack(clipBehavior: Clip.none, children: [b,
    Positioned(right: -10, bottom: -10, child: GestureDetector(onPanUpdate: (e) { it['w'] = m.max(50.0, dn(it['w']) + e.delta.dx); it['h'] = m.max(40.0, dn(it['h']) + e.delta.dy); up(); },
      child: const CircleAvatar(radius: 12, child: Icon(Icons.open_in_full, size: 14)))),
    if (del != null) Positioned(left: -10, top: -10, child: GestureDetector(onTap: del, child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white))))]);
}

class Quiz {
  final bad = ValueNotifier<int>(0);
  final ctl = <Map, TextEditingController>{};
  bool ghost = false;
  Widget field(Map x, TextStyle st) {
    final k = ctl.putIfAbsent(x, () => TextEditingController());
    return Stack(alignment: Alignment.center, children: [
      if (ghost) Opacity(opacity: .3, child: Text(x['t'], style: st)),
      TextField(controller: k, style: st, textAlign: TextAlign.center, decoration: const InputDecoration.collapsed(hintText: ''), onChanged: (_) { tap(); check(); })]);
  }
  void check() => bad.value = ctl.entries.where((e) => !(e.key['t'] as String).startsWith(e.value.text)).length;
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
class _Q extends State<QuizPage> {
  final q = Quiz();
  @override
  Widget build(BuildContext c) => Scaffold(backgroundColor: Color(widget.p['bg']),
    body: ValueListenableBuilder<int>(valueListenable: q.bad, builder: (_, b, __) => AnimatedContainer(duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(border: Border.all(color: b > 0 ? Colors.red : Colors.green, width: 8)),
      child: SafeArea(child: Column(children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.close), color: Colors.black, onPressed: () => Navigator.pop(c)),
          TextButton(onPressed: () => toast(c, 'تم حذف ${q.help()} خطأ'), child: const Text('مساعدة')),
          IconButton(icon: const Text('💡', style: TextStyle(fontSize: 22)), onPressed: () => toast(c, 'تم تصحيح ${q.solve()} خانة')),
          IconButton(icon: const Text('🔎', style: TextStyle(fontSize: 22)), onPressed: () => setState(() => q.ghost = !q.ghost))]),
        Expanded(child: InteractiveViewer(constrained: false, minScale: .2, maxScale: 4, boundaryMargin: const EdgeInsets.all(600), child: PV(widget.p, q, false, () {})))])))));
}

class PV extends StatelessWidget {
  final Map p; final Quiz? q; final bool edit; final VoidCallback up;
  const PV(this.p, this.q, this.edit, this.up, {super.key});
  VoidCallback? ed(BuildContext c, Map x) => edit ? () => editCell(c, x, up) : null;
  Widget tree(BuildContext c, Map n, List? sib) {
    final k = n['k'] as List, x = n['c'] as Map;
    final line = Container(width: 2, height: 18, color: Color(th.acc));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      box(x, q, ed(c, x), w: fw(x), h: fh(x)),
      if (edit) Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.add_circle), onPressed: () { k.add({'c': nc(), 'k': []}); up(); }),
        if (sib != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { sib.remove(n); up(); })]),
      if (k.isNotEmpty) line,
      if (k.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        for (final e in k) Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: Color(th.acc), width: 2))),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Column(mainAxisSize: MainAxisSize.min, children: [line, tree(c, e, k)])))])]);
  }
  @override
  Widget build(BuildContext c) {
    final d = p['d'] as Map;
    const pad = EdgeInsets.all(80);
    switch (p['type']) {
      case 'tree':
        return Padding(padding: pad, child: tree(c, d, null));
      case 'card':
        return Padding(padding: pad, child: item(d['i'], q, edit, up, c));
      case 'table':
        final rows = d['rows'] as List;
        return Padding(padding: pad, child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final r in rows) Row(mainAxisSize: MainAxisSize.min, children: [
            for (final x in r) Padding(padding: const EdgeInsets.all(2), child: box(x, q, ed(c, x), w: m.max(130.0, fw(x)), h: fh(x))),
            if (edit) IconButton(icon: const Icon(Icons.add_circle), onPressed: () { r.add(nc()); up(); }),
            if (edit && rows.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { rows.remove(r); up(); })]),
          if (edit) IconButton(icon: const Icon(Icons.add_circle), onPressed: () { rows.add([for (final _ in rows.last) nc()]); up(); })]));
      case 'pyr':
        final cells = d['cells'] as List;
        return Padding(padding: pad, child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < cells.length; i++) Padding(padding: const EdgeInsets.all(2), child: box(cells[i], q, ed(c, cells[i]), w: m.max(90.0 + i * 28, fw(cells[i])), h: fh(cells[i])))]));
      default:
        final its = d['s'] as List;
        return SizedBox(width: 1600, height: 1600, child: Stack(children: [
          for (final it in its) Positioned(left: dn(it['x']), top: dn(it['y']), child: Drag(it, its, edit, up, item(it, q, edit, up, c, () { its.remove(it); up(); })))]));
    }
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
  void up() { save(); setState(() {}); }
  void zoom(double f) => tc.value = tc.value.clone()..scale(f);
  void addShape() => showModalBottomSheet(context: context, builder: (d) => ListView(children: [
    for (final s in shapes) ListTile(title: Text(s['n'] as String), onTap: () {
      Navigator.pop(d);
      final it = si(s, 300, 300);
      final l = widget.p['d']['s'] as List;
      for (int i = 0; i < 300 && hit(it, l); i++) {
        it['x'] = dn(it['x']) + 40;
        if (dn(it['x']) > 1400) { it['x'] = 0.0; it['y'] = dn(it['y']) + 40; }
      }
      l.add(it);
      up();
    })]));
  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    return Scaffold(backgroundColor: Color(p['bg']),
      appBar: AppBar(title: Text(p['name']), actions: [
        IconButton(icon: const Icon(Icons.zoom_in), onPressed: () => zoom(1.25)),
        IconButton(icon: const Icon(Icons.zoom_out), onPressed: () => zoom(.8)),
        if (widget.dev) IconButton(icon: const Icon(Icons.palette), onPressed: () => showDialog(context: c, builder: (d) => StatefulBuilder(builder: (d, ss) => AlertDialog(title: const Text('خلفية الصفحة'), content: colors(p, 'bg', () { ss(() {}); up(); }))))),
        if (widget.dev) TextButton(onPressed: () { save(); Navigator.pop(c); }, child: const Text('حفظ الدرس'))]),
      floatingActionButton: widget.dev && p['type'] == 'shape' ? FloatingActionButton(onPressed: addShape, child: const Text('◆', style: TextStyle(fontSize: 26))) : null,
      body: Stack(children: [
        InteractiveViewer(transformationController: tc, constrained: false, minScale: .2, maxScale: 4, boundaryMargin: const EdgeInsets.all(600), child: PV(p, null, widget.dev, up)),
        if (!widget.dev) Positioned(bottom: 20, left: 20, right: 20, child: SizedBox(height: 64, child: FilledButton(onPressed: () => go(c, QuizPage(p)), child: const Text('اختبار', style: TextStyle(fontSize: 24)))))]));
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
  void settings(BuildContext c) => showDialog(context: c, builder: (d) => SimpleDialog(title: const Text('الإعدادات: النماذج'), children: [
    for (int i = 0; i < themes.length; i++) ListTile(title: Text('نموذج ${i + 1}: ${themes[i].n}'), trailing: themeN.value == i ? const Icon(Icons.check) : null,
      onTap: () { themeN.value = i; prefs.setInt('t', i); Navigator.pop(d); })]));
  void create(BuildContext c) => showModalBottomSheet(context: c, builder: (d) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
    for (final t in [['tree', 'شجرة متفرعة'], ['card', 'بطاقة'], ['table', 'جدول'], ['shape', 'تشكيل']])
      ListTile(leading: Icon(icons[t[0]]), title: Text(t[1]), onTap: () async { Navigator.pop(d); await setup(c, t[0]); setState(() {}); })])));
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
      d = {'c': nc([34.0, 24.0, 18.0][opt]), 'k': []};
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
      IconButton(icon: const Icon(Icons.settings), onPressed: () => settings(c))]),
    floatingActionButton: widget.dev ? FloatingActionButton(onPressed: () => create(c), child: const Icon(Icons.add)) : null,
    body: projects.isEmpty
      ? Center(child: Text(widget.dev ? 'اضغط + لإنشاء أول درس' : 'لا توجد دروس بعد'))
      : ListView(padding: const EdgeInsets.all(12), children: [
          for (final p in projects) Card(child: ListTile(
            leading: Icon(icons[p['type']]), title: Text(p['name'], style: const TextStyle(fontSize: 20)),
            trailing: widget.dev ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { if (await sure(c)) { projects.remove(p); save(); setState(() {}); } }) : null,
            onTap: () async { tap(); await go(c, ProjPage(p, widget.dev)); setState(() {}); }))]));
}

class Login extends StatelessWidget {
  const Login({super.key});
  Widget big(String t, VoidCallback f) => SizedBox(width: 300, height: 76, child: FilledButton(style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 24)), onPressed: () { tap(); f(); }, child: Text(t)));
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
