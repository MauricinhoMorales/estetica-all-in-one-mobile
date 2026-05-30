import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static Future<String> saveImage(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, name));
    await dest.writeAsBytes(await file.readAsBytes());
    return dest.path;
  }

  static Future<void> deleteImage(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
