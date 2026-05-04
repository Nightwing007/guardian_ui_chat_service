import 'package:flutter/material.dart';
import 'package:myapp/screens/child/main_layout.dart';
import 'package:myapp/theme/app_colors.dart';

class ChildPermissionsScreen extends StatefulWidget {
  const ChildPermissionsScreen({super.key});

  @override
  State<ChildPermissionsScreen> createState() => _ChildPermissionsScreenState();
}

class _ChildPermissionsScreenState extends State<ChildPermissionsScreen> {
  bool _usageAccess = false;
  bool _accessibilityService = false;
  bool _vpnMonitoring = false;
  bool _locationTracking = false;
  bool _overlayPermission = false;

  bool get _allPermissionsGranted {
    return _usageAccess &&
        _accessibilityService &&
        _vpnMonitoring &&
        _locationTracking &&
        _overlayPermission;
  }

  void _turnOnAll() {
    setState(() {
      _usageAccess = true;
      _accessibilityService = true;
      _vpnMonitoring = true;
      _locationTracking = true;
      _overlayPermission = true;
    });
  }

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
        child: Padding(
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
                'To keep you protected and ensure Guardian AI functions properly, please enable the following permissions.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _turnOnAll,
                    child: Text(
                      'Turn On All',
                      style: TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionItem(
                      title: 'Usage Access',
                      description: 'Required to monitor app usage and screen time.',
                      icon: Icons.data_usage,
                      value: _usageAccess,
                      onChanged: (val) {
                        setState(() => _usageAccess = val);
                      },
                    ),
                    _buildPermissionItem(
                      title: 'Accessibility Service',
                      description: 'Used for URL monitoring and content filtering.',
                      icon: Icons.accessibility,
                      value: _accessibilityService,
                      onChanged: (val) {
                        setState(() => _accessibilityService = val);
                      },
                    ),
                    _buildPermissionItem(
                      title: 'VPN Monitoring',
                      description: 'Required to block harmful content.',
                      icon: Icons.vpn_lock,
                      value: _vpnMonitoring,
                      onChanged: (val) {
                        setState(() => _vpnMonitoring = val);
                      },
                    ),
                    _buildPermissionItem(
                      title: 'Location Tracking',
                      description: 'Required for location sharing with your parents.',
                      icon: Icons.location_on,
                      value: _locationTracking,
                      onChanged: (val) {
                        setState(() => _locationTracking = val);
                      },
                    ),
                    _buildPermissionItem(
                      title: 'Overlay Permission',
                      description: 'Required to display alerts over other apps.',
                      icon: Icons.layers,
                      value: _overlayPermission,
                      onChanged: (val) {
                        setState(() => _overlayPermission = val);
                      },
                    ),
                  ],
                ),
              ),
              if (_allPermissionsGranted) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainLayout(),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBlueBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.surfaceOverlay,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.accentBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentBlue,
            activeTrackColor: AppColors.accentBlue.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
