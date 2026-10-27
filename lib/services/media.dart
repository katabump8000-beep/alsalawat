import 'dart:io';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// يختار صورة من المعرض ويحفظ نسخة داخل التطبيق. يرجع المسار ونسبة الارتفاع/العرض.
Future<({String path, double ratio})?> pickImageToApp() async {
  final x = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2200,
    imageQuality: 90,
  );
  if (x == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/imgs');
  if (!folder.existsSync()) folder.createSync(recursive: true);
  final dest = '${folder.path}/${const Uuid().v4()}.jpg';
  await File(x.path).copy(dest);
  final bytes = await File(dest).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final ratio = frame.image.height / frame.image.width;
  frame.image.dispose();
  return (path: dest, ratio: ratio);
}
