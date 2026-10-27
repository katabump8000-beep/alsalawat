import 'package:audioplayers/audioplayers.dart';

/// أصوات التطبيق. غيّر الملفين هنا إن أردت تبديلهما.
class Sound {
  static const String _tapFile = 'saat.mp3'; // قصير (0.2 ث): نقرات الأزرار
  static const String _successFile = 'click.mp3'; // أطول (0.8 ث): إجابة صحيحة/حفظ

  static bool enabled = true;
  static bool _ready = false;
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> _play(String file) async {
    if (!enabled) return;
    try {
      if (!_ready) {
        AudioCache.instance.prefix = ''; // الملفان في جذر المشروع
        _ready = true;
      }
      await _player.stop();
      await _player.play(AssetSource(file));
    } catch (_) {
      // الصوت ميزة إضافية؛ لا نوقف التطبيق إن فشل.
    }
  }

  static void tap() => _play(_tapFile);
  static void success() => _play(_successFile);
}
