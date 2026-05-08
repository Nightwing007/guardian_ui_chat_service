import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/child/app_usage_service.dart';
import 'package:myapp/services/session_service.dart';

class UsageSubmissionService {
  static final UsageSubmissionService _instance =
      UsageSubmissionService._internal();
  factory UsageSubmissionService() => _instance;
  UsageSubmissionService._internal();

  static const _baseUrl = 'https://seraphguardlabs.com';
  static const _interval = Duration(seconds: 20);

  Timer? _timer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    debugPrint('UsageSubmissionService started');
    await _submitUsage();

    _timer = Timer.periodic(_interval, (_) async {
      if (_isRunning) {
        await _submitUsage();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('UsageSubmissionService stopped');
  }

  Future<void> _submitUsage() async {
    try {
      final usageList = await AppUsageService().getTodayUsage();
      if (usageList.isEmpty) {
        debugPrint('UsageSubmissionService: No usage data to store');
        return;
      }

      final apps = usageList
          .where((u) => u.totalTimeInForeground.inMilliseconds > 0)
          .map(
            (u) => {
              'package_name': u.packageName,
              'app_name': u.appName,
              'foreground_ms': u.totalTimeInForeground.inMilliseconds,
              'opens': 0,
            },
          )
          .toList();

      if (apps.isEmpty) {
        debugPrint('UsageSubmissionService: No apps with usage data');
        return;
      }

      final session = await SessionService.getChildSession();
      final deviceToken = session['deviceToken'];
      final childHash = session['childHash'];
      await AppDatabase().initialize();
      if (childHash != null && childHash.isNotEmpty) {
        await AppDatabase().child.upsertLocalUsageSnapshot(
          apps,
          childHash: childHash,
        );
      }

      final isPaired =
          session['role'] == SessionService.childRole &&
          session['isLinked'] == 'true' &&
          deviceToken != null &&
          deviceToken.isNotEmpty &&
          childHash != null &&
          childHash.isNotEmpty;

      if (!isPaired) {
        debugPrint(
          'UsageSubmissionService: Usage saved locally; paired cloud credentials are not complete',
        );
        return;
      }

      debugPrint(
        'UsageSubmissionService: Submitting usage for ${apps.length} apps',
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/children/$childHash/usage'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Token': deviceToken,
            },
            body: jsonEncode({'apps': apps}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('UsageSubmissionService: Status ${response.statusCode}');
      debugPrint('UsageSubmissionService: Body ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
          'UsageSubmissionService: Failed to submit usage; keeping local copy',
        );
        return;
      }

      await AppDatabase().child.markLocalUsageSynced(childHash: childHash);
    } catch (e) {
      debugPrint('UsageSubmissionService: Error handling usage: $e');
    }
  }
}
