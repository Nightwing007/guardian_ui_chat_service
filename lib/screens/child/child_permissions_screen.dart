import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:myapp/screens/child/main_layout.dart';
import 'package:myapp/screens/child/ai_setup_screen.dart';
import 'package:myapp/services/child/app_usage_service.dart';
import 'package:myapp/services/child/monitoring_service.dart';
import 'package:myapp/theme/app_colors.dart';

class ChildPermissionsScreen extends StatefulWidget {
  const ChildPermissionsScreen({super.key});

  @override
  State<ChildPermissionsScreen> createState() => _ChildPermissionsScreenState();
}

class _ChildPermissionsScreenState extends State<ChildPermissionsScreen>
    with WidgetsBindingObserver {
  final _appUsage = AppUsageService();
  final _monitoring = MonitoringService();

  bool _usagePermission = false;
  bool _accessibilityEnabled = false;
  bool _vpnRunning = false;
  bool _locationRunning = false;
  bool _overlayPermission = false;

  /// All 4 required permissions (overlay is optional).
  bool get _ready =>
      _usagePermission &&
      _accessibilityEnabled &&
      _vpnRunning &&
      _locationRunning;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check all permissions when the user returns from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshChecks();
    }
  }

  // ── Permission checks ─────────────────────────────────────────────

  Future<void> _refreshChecks() async {
    final results = await Future.wait([
      _appUsage.hasUsageStatsPermission(),
      _monitoring.isAccessibilityEnabled(),
      _monitoring.isVpnRunning(),
      _monitoring.isLocationTrackingRunning(),
      _appUsage.hasOverlayPermission(),
    ]);

    if (!mounted) return;
    setState(() {
      _usagePermission = results[0];
      _accessibilityEnabled = results[1];
      _vpnRunning = results[2];
      _locationRunning = results[3];
      _overlayPermission = results[4];
    });
  }

  // ── Permission requests ───────────────────────────────────────────

  Future<void> _requestUsageStats() async {
    await _appUsage.openUsageAccessSettings();
    // Status will be refreshed via didChangeAppLifecycleState when user
    // returns from the settings page.
  }

  Future<void> _requestAccessibility() async {
    await _monitoring.openAccessibilitySettings();
  }

  Future<void> _toggleVpn() async {
    if (_vpnRunning) {
      await _monitoring.stopVpn();
    } else {
      final result = await _monitoring.startVpn();
      if (result != 'started') {
        // VPN permission dialog was declined
        return;
      }
    }
    await _refreshChecks();
  }

  Future<void> _toggleLocationTracking() async {
    if (_locationRunning) {
      await _monitoring.stopLocationTracking();
      await _refreshChecks();
    } else {
      final granted = await _ensureLocationPermission();
      if (!granted) return;

      final result = await _monitoring.startLocationTracking();
      if (result == 'started') {
        await _refreshChecks();
      }
    }
  }

  /// Requests runtime location permissions step-by-step:
  /// 1. `locationWhenInUse`
  /// 2. `locationAlways` (background)
  /// 3. Falls back to app settings if permanently denied.
  Future<bool> _ensureLocationPermission() async {
    // Step 1 — foreground
    var status = await Permission.locationWhenInUse.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    // Step 2 — background
    status = await Permission.locationAlways.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    return true;
  }

  Future<void> _toggleOverlay() async {
    await _appUsage.requestOverlayPermission();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Required Permissions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To keep you protected and ensure Guardian AI functions '
                'properly, please enable the following permissions.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _buildPermissionItem(
                title: 'Usage Access',
                description:
                    'Required to monitor app usage and screen time.',
                icon: Icons.data_usage,
                value: _usagePermission,
                onChanged: (_) => _requestUsageStats(),
              ),
              _buildPermissionItem(
                title: 'Accessibility Service',
                description:
                    'Used for URL monitoring and content filtering.',
                icon: Icons.accessibility,
                value: _accessibilityEnabled,
                onChanged: (_) => _requestAccessibility(),
              ),
              _buildPermissionItem(
                title: 'VPN Monitoring',
                description: 'Required to block harmful content.',
                icon: Icons.vpn_lock,
                value: _vpnRunning,
                onChanged: (_) => _toggleVpn(),
              ),
              _buildPermissionItem(
                title: 'Location Tracking',
                description:
                    'Required for location sharing with your parents.',
                icon: Icons.location_on,
                value: _locationRunning,
                onChanged: (_) => _toggleLocationTracking(),
              ),
              _buildPermissionItem(
                title: 'Overlay Permission',
                description:
                    'Required to display alerts over other apps.',
                icon: Icons.layers,
                value: _overlayPermission,
                onChanged: (_) => _toggleOverlay(),
                optional: true,
              ),
              const SizedBox(height: 24),
              if (_ready)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AiModelSetupScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Permission tile ───────────────────────────────────────────────

  Widget _buildPermissionItem({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool optional = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBlueBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AppColors.accentBlue.withValues(alpha: 0.4)
              : AppColors.surfaceOverlay,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.accentBlue.withValues(alpha: 0.2)
                  : AppColors.primaryPurple.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? AppColors.accentBlue : AppColors.textGrey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (optional) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOverlay,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accentBlue,
            activeTrackColor: AppColors.accentBlue.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
