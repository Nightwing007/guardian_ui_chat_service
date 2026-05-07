import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myapp/services/child/app_usage_service.dart';
import 'package:myapp/services/child/device_auth_service.dart';

class UsageSubmissionService {
  static final UsageSubmissionService _instance = UsageSubmissionService._internal();
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

    print('UsageSubmissionService started');
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
    print('UsageSubmissionService stopped');
  }

  Future<void> _submitUsage() async {
    try {
      if (!await DeviceAuthService().isDeviceRegistered()) {
        print('UsageSubmissionService: Device not registered, skipping submission');
        return;
      }

      final childHash = await DeviceAuthService().getChildHash();
      final deviceToken = await DeviceAuthService().getDeviceToken();

      final usageList = await AppUsageService().getTodayUsage();
      if (usageList.isEmpty) {
        print('UsageSubmissionService: No usage data to submit');
        return;
      }

      final apps = usageList
          .where((u) => u.totalTimeInForeground.inMilliseconds > 0)
          .map((u) => {
                'package_name': u.packageName,
                'app_name': u.appName,
                'foreground_ms': u.totalTimeInForeground.inMilliseconds,
                'opens': 0,
              })
          .toList();

      if (apps.isEmpty) {
        print('UsageSubmissionService: No apps with usage data');
        return;
      }

      print('UsageSubmissionService: Submitting usage for ${apps.length} apps');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/children/$childHash/usage'),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': deviceToken,
        },
        body: jsonEncode({'apps': apps}),
      ).timeout(const Duration(seconds: 15));

      print('UsageSubmissionService: Status ${response.statusCode}');
      print('UsageSubmissionService: Body ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('UsageSubmissionService: Failed to submit usage: ${response.body}');
      }
    } catch (e) {
      print('UsageSubmissionService: Error submitting usage: $e');
    }
  }
}
