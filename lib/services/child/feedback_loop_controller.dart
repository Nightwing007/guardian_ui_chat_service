import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ai_inference.dart';
import 'risk_level.dart';
import 'screenshot_controller.dart';

class FeedbackLoopLog {
  final DateTime timestamp;
  final String type;
  final String message;

  FeedbackLoopLog({
    required this.timestamp,
    required this.type,
    required this.message,
  });
}

class FeedbackLoopController extends ChangeNotifier {
  bool _running = false;
  String _lastFeedback = '';
  int _cycleCount = 0;
  final List<FeedbackLoopLog> _logs = <FeedbackLoopLog>[];

  RiskLevel _activeRisk = RiskLevel.low;
  DateTime _peakRiskAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _activePackage = '';
  CaptureFrequencyClass _appClass = CaptureFrequencyClass.normal;
  Duration _nextDelay = const Duration(milliseconds: 900);
  Duration _lastLoggedDelay = Duration.zero;

  /// Subscribes to foreground-app events from native so [setActiveApp] is
  /// called automatically whenever the user switches apps.
  StreamSubscription<dynamic>? _foregroundAppSub;
  static const EventChannel _foregroundAppChannel =
      EventChannel('guardian/foreground_app');

  bool get isRunning => _running;
  String get lastFeedback => _lastFeedback;
  int get cycleCount => _cycleCount;
  List<FeedbackLoopLog> get logs => List.unmodifiable(_logs);
  RiskLevel get activeRisk => _activeRisk;
  int get activeRiskScore => _riskScore(_activeRisk);
  String get activePackage => _activePackage;
  Duration get nextDelay => _nextDelay;
  String get appClassLabel => _appClassName(_appClass);

  static const List<String> _veryLowFrequencyPrefixes = <String>[
    'com.android.systemui',
    'com.android.launcher',
    'com.google.android.apps.nexuslauncher',
    'com.sec.android.app.launcher',
    'com.miui.home',
    'com.android.settings',
    'com.google.android.dialer',
    'com.android.dialer',
    'com.android.contacts',
    'com.google.android.contacts',
    'com.android.camera',
    'com.sec.android.app.camera',
    'com.google.android.apps.photos',
    'com.android.gallery',
    'com.google.android.apps.nbu.files',
    'com.android.documentsui',
    'com.google.android.apps.maps',
    'com.google.android.calendar',
    'com.android.calendar',
    'com.google.android.deskclock',
    'com.android.deskclock',
    'com.google.android.calculator',
    'com.android.calculator2',
  ];

  static const List<String> _reducedFrequencyPrefixes = <String>[
    'com.google.android.youtube',
    'com.google.android.apps.youtube.music',
    'com.spotify.music',
    'com.netflix.mediaclient',
    'com.amazon.avod.thirdpartyclient',
    'com.disney.disneyplus',
    'tv.twitch.android.app',
    'com.mxtech.videoplayer',
    'com.google.android.apps.docs',
    'com.google.android.keep',
  ];

  Future<void> start() async {
    if (_running) return;

    final modelReady = await AiChannel.ensureModel();
    if (!modelReady) {
      debugPrint('[FeedbackLoop] Model not loaded — loop not started');
      _appendLog('status', 'Model not loaded — loop not started');
      notifyListeners();
      return;
    }

    _running = true;
    _refreshAdaptiveDelay(forceLog: true);
    _appendLog('status', 'Feedback loop started');
    notifyListeners();

    // Subscribe to native foreground-app events for adaptive delay tuning.
    _foregroundAppSub ??= _foregroundAppChannel
        .receiveBroadcastStream()
        .listen((dynamic pkg) {
      if (pkg is String) setActiveApp(pkg);
    }, onError: (dynamic _) {});

    await _runLoop();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _foregroundAppSub?.cancel();
    _foregroundAppSub = null;
    _appendLog('status', 'Feedback loop stopped');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> _runLoop() async {
    while (_running) {
      try {
        _refreshAdaptiveDelay();

        final imageBytes = await ScreenshotController.capture();
        if (!_running) break;

        if (imageBytes == null || imageBytes.isEmpty) {
          debugPrint('[FeedbackLoop] Screenshot capture failed');
          _appendLog('error', 'Screenshot capture failed');
          await Future.delayed(_nextDelay);
          continue;
        }

        debugPrint('[FeedbackLoop] Screenshot captured (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');
        _appendLog(
          'capture',
          'Screenshot captured (${(imageBytes.length / 1024).toStringAsFixed(1)} KB) • risk $activeRiskScore • delay ${(nextDelay.inMilliseconds / 1000).toStringAsFixed(1)}s',
        );

        final feedback = await AiChannel.runInference(imageBytes);
        if (!_running) break;

        debugPrint('[FeedbackLoop] Inference result: $feedback');
        _lastFeedback = feedback;
        _cycleCount += 1;
        _appendLog('feedback', feedback);
        notifyListeners();

        _refreshAdaptiveDelay();
        await Future.delayed(_nextDelay);
      } catch (e) {
        _appendLog('error', 'Loop error: $e');
        notifyListeners();
        await Future.delayed(_nextDelay);
      }
    }
  }

  void setActiveApp(String packageName) {
    final normalized = packageName.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _activePackage) return;
    _activePackage = normalized;
    _appClass = _classifyApp(normalized);
    _refreshAdaptiveDelay(forceLog: true);
    _appendLog(
      'timing',
      'Active app updated: $_activePackage (${_appClassName(_appClass)})',
    );
  }

  void applyRiskSignal(RiskLevel risk) {
    if (risk == RiskLevel.low) {
      _refreshAdaptiveDelay();
      return;
    }

    _peakRiskAt = DateTime.now();
    _refreshAdaptiveDelay(forceLog: true);
    _appendLog(
      'timing',
      'Risk signal: ${risk.name.toUpperCase()}',
    );
  }

  void _refreshAdaptiveDelay({bool forceLog = false}) {
    final now = DateTime.now();
    final effectiveRisk = _resolveEffectiveRisk(now);
    final computedDelay = _computeDelay(effectiveRisk, _appClass);

    final changed =
        forceLog || effectiveRisk != _activeRisk || computedDelay != _nextDelay;
    _activeRisk = effectiveRisk;
    _nextDelay = computedDelay;

    if (!changed) return;

    final delta = (_nextDelay.inMilliseconds - _lastLoggedDelay.inMilliseconds).abs();
    if (forceLog || delta >= 400) {
      _lastLoggedDelay = _nextDelay;
      _appendLog(
        'timing',
        'Delay tuned to ${(computedDelay.inMilliseconds / 1000).toStringAsFixed(1)}s (risk ${_riskScore(_activeRisk)}, class ${_appClassName(_appClass)})',
      );
    }
    notifyListeners();
  }

  RiskLevel _resolveEffectiveRisk(DateTime now) {
    final elapsed = now.difference(_peakRiskAt).inSeconds;
    if (elapsed <= 20) return RiskLevel.high;
    if (elapsed <= 45) return RiskLevel.medium;
    return RiskLevel.low;
  }

  Duration _computeDelay(RiskLevel risk, CaptureFrequencyClass appClass) {
    final baseMs = switch (risk) {
      RiskLevel.high => 700,
      RiskLevel.medium => 1700,
      RiskLevel.low => 3200,
    };
    final multiplier = switch (appClass) {
      CaptureFrequencyClass.normal => 1.0,
      CaptureFrequencyClass.reduced => 1.7,
      CaptureFrequencyClass.veryLow => 2.8,
    };

    final ms = (baseMs * multiplier).round();
    return Duration(milliseconds: ms.clamp(500, 15000));
  }

  int _riskScore(RiskLevel risk) {
    return switch (risk) {
      RiskLevel.high => 90,
      RiskLevel.medium => 60,
      RiskLevel.low => 20,
    };
  }

  CaptureFrequencyClass _classifyApp(String packageName) {
    if (packageName.isEmpty) return CaptureFrequencyClass.normal;
    if (_veryLowFrequencyPrefixes.any(packageName.startsWith)) {
      return CaptureFrequencyClass.veryLow;
    }
    if (_reducedFrequencyPrefixes.any(packageName.startsWith)) {
      return CaptureFrequencyClass.reduced;
    }

    if (packageName.contains('.game') ||
        packageName.contains('.video') ||
        packageName.contains('.music')) {
      return CaptureFrequencyClass.reduced;
    }

    return CaptureFrequencyClass.normal;
  }

  String _appClassName(CaptureFrequencyClass value) {
    return switch (value) {
      CaptureFrequencyClass.normal => 'normal',
      CaptureFrequencyClass.reduced => 'reduced',
      CaptureFrequencyClass.veryLow => 'very_low',
    };
  }

  void _appendLog(String type, String message) {
    _logs.insert(
      0,
      FeedbackLoopLog(
        timestamp: DateTime.now(),
        type: type,
        message: message,
      ),
    );
    if (_logs.length > 120) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _running = false;
    _foregroundAppSub?.cancel();
    _foregroundAppSub = null;
    super.dispose();
  }
}

enum CaptureFrequencyClass {
  normal,
  reduced,
  veryLow,
}
