import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:myapp/config/ai_prompt.dart';

class AiChannel {
  static dynamic _model;

  static bool get isModelLoaded => _model != null;

  static Future<bool> ensureModel() async {
    if (_model != null) return true;
    try {
      _model = await _getModel(PreferredBackend.gpu);
      return true;
    } catch (e) {
      debugPrint('[AiChannel] GPU model load failed: $e');
    }

    try {
      _model = await _getModel(PreferredBackend.cpu);
      return true;
    } catch (e) {
      debugPrint('[AiChannel] CPU model load failed: $e');
      return false;
    }
  }

  static Future<dynamic> _getModel(PreferredBackend backend) async {
    return FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: backend,
      supportImage: true,
      maxNumImages: 1,
    );
  }

  static Future<String> runInference(Uint8List imageBytes) async {
    try {
      final loaded = await ensureModel();
      if (!loaded) return 'Error: No active inference model set.';

      final chat = await _model.createChat(
        systemInstruction: aiSystemPrompt,
        supportImage: true,
      );

      await chat.addQueryChunk(
        Message.withImage(
          text:
              'Analyze this screenshot for child safety and provide concise feedback.',
          imageBytes: imageBytes,
          isUser: true,
        ),
      );

      var responseText = '';
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          responseText += response.token;
        }
      }
      return responseText.trim().isEmpty
          ? 'No feedback generated.'
          : responseText.trim();
    } catch (e) {
      return 'Error: $e';
    }
  }

  static void dispose() {
    try {
      _model?.close();
    } catch (_) {}
    _model = null;
  }
}
