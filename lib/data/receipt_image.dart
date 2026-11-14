import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

const maxReceiptBytes = 5 * 1024 * 1024;

class InvalidReceipt implements Exception {
  const InvalidReceipt();
}

Future<Uint8List> prepareReceipt(XFile file) async {
  if (await file.length() > 25 * 1024 * 1024) throw const InvalidReceipt();
  return compute(normalizeReceipt, await file.readAsBytes());
}

Uint8List normalizeReceipt(Uint8List bytes) {
  final image.Decoder decoder;
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    decoder = image.JpegDecoder();
  } else if (bytes.length >= 8 &&
      const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((part) => bytes[part.key] == part.value)) {
    decoder = image.PngDecoder();
  } else {
    throw const InvalidReceipt();
  }
  final info = decoder.startDecode(bytes);
  if (info == null || info.width * info.height > 48 * 1000 * 1000) {
    throw const InvalidReceipt();
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const InvalidReceipt();
  final oriented = image.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest <= 2200
      ? oriented
      : image.copyResize(
          oriented,
          width: (oriented.width * 2200 / longest).round().clamp(1, 2200),
          height: (oriented.height * 2200 / longest).round().clamp(1, 2200),
        );
  // A new pixel buffer keeps EXIF (including GPS) out of the stored receipt.
  final clean = image.Image(width: resized.width, height: resized.height);
  image.fill(clean, color: image.ColorRgb8(255, 255, 255));
  image.compositeImage(clean, resized);
  final jpg = image.encodeJpg(clean, quality: 85);
  if (jpg.length > maxReceiptBytes) throw const InvalidReceipt();
  return jpg;
}
