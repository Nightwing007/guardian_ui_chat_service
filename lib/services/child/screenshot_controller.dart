import 'package:flutter/services.dart';

class ScreenshotController {
  static const MethodChannel _channel = MethodChannel('guardian/ai_loop');

  static Future<Uint8List?> capture() async {
    try {
      return await _channel.invokeMethod<Uint8List>('captureScreen');
    } on PlatformException {
      return null;
    }
  }
}
