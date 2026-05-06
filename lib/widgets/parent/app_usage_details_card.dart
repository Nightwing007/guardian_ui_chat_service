import 'package:flutter/material.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/widgets/parent/app_usage_item.dart';

class AppUsageDetailsCard extends StatefulWidget {
  final String email;
  final String password;
  final String childHash;

  const AppUsageDetailsCard({
    super.key,
    required this.email,
    required this.password,
    required this.childHash,
  });

  @override
  State<AppUsageDetailsCard> createState() => _AppUsageDetailsCardState();
}

class _AppUsageDetailsCardState extends State<AppUsageDetailsCard> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _apps = [];
  int _totalMs = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsage();
  }

  Future<void> _fetchUsage() async {
    if (widget.childHash.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No child account linked yet.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await AuthService().getChildUsage(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    );

    if (!mounted) return;

    if (result['success']) {
      final data = result['data'] as Map<String, dynamic>;
      final apps = (data['apps'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      setState(() {
        _isLoading = false;
        _apps = apps;
        _totalMs = data['total_foreground_ms'] ?? 0;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result['message'];
      });
    }
  }

  String _formatMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '< 1m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'App Usage Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isLoading)
              IconButton(
                onPressed: _fetchUsage,
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                tooltip: 'Refresh',
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF38BDF8),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 32),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_apps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.phone_android_outlined, color: Colors.white24, size: 40),
              SizedBox(height: 12),
              Text(
                'No usage data for today',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by most used
    final sorted = List<Map<String, dynamic>>.from(_apps)
      ..sort((a, b) => (b['foreground_ms'] as int).compareTo(a['foreground_ms'] as int));

    return Column(
      children: sorted.asMap().entries.map((entry) {
        final index = entry.key;
        final app = entry.value;
        final ms = app['foreground_ms'] as int;
        final pct = _totalMs > 0 ? ((ms / _totalMs) * 100).round() : 0;
        final isLast = index == sorted.length - 1;

        return AppUsageItem(
          icon: _buildAppIcon(app['package_name'] as String),
          appName: app['app_name'] as String,
          category: app['package_name'] as String,
          usageTime: _formatMs(ms),
          percentage: pct.clamp(1, 100),
          showDivider: !isLast,
        );
      }).toList(),
    );
  }

  Widget _buildAppIcon(String packageName) {
    // Map well-known package names to colors; fall back to a generic icon
    final iconMap = <String, Map<String, dynamic>>{
      'com.instagram.android': {'icon': Icons.camera_alt, 'color': const Color(0xFFE1306C)},
      'com.whatsapp': {'icon': Icons.chat, 'color': const Color(0xFF25D366)},
      'com.facebook.katana': {'icon': Icons.facebook, 'color': const Color(0xFF1877F2)},
      'com.google.android.youtube': {'icon': Icons.play_circle_fill, 'color': const Color(0xFFFF0000)},
      'com.google.android.gm': {'icon': Icons.email, 'color': const Color(0xFFEA4335)},
      'org.telegram.messenger': {'icon': Icons.send, 'color': const Color(0xFF0088CC)},
      'com.snapchat.android': {'icon': Icons.crop_square, 'color': const Color(0xFFFFFC00)},
      'com.twitter.android': {'icon': Icons.alternate_email, 'color': const Color(0xFF1DA1F2)},
    };

    final entry = iconMap[packageName];
    if (entry != null) {
      return Icon(entry['icon'] as IconData, color: entry['color'] as Color, size: 24);
    }

    return const Icon(Icons.apps, color: Colors.white54, size: 24);
  }
}
