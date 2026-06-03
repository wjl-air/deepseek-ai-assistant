import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static Future<String?> compressAndEncode(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) {
        return null;
      }

      final image = img.decodeImage(bytes);
      if (image == null) return null;

      img.Image resized = image;
      if (image.width > 2048 || image.height > 2048) {
        resized = img.copyResize(
          image,
          width: image.width > 2048 ? 2048 : image.width,
          height: image.height > 2048 ? 2048 : image.height,
        );
      }

      final jpegBytes = img.encodeJpg(resized, quality: 85);
      return base64Encode(jpegBytes);
    } catch (e) {
      return null;
    }
  }
}
