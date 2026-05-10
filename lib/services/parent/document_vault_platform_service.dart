import 'package:flutter/services.dart';

class DocumentVaultPlatformService {
  static const _channel = MethodChannel('guardian/monitoring');

  Future<List<String>> renderPdfPages(String filePath) async {
    final pages = await _channel.invokeMethod<List<dynamic>>('renderPdfPages', {
      'filePath': filePath,
    });
    return pages?.whereType<String>().toList() ?? [];
  }

  Future<void> shareFile(String filePath, String fileName) async {
    await _channel.invokeMethod<void>('shareFile', {
      'filePath': filePath,
      'fileName': fileName,
    });
  }
}
