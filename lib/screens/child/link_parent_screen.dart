import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/child_permissions_screen.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/child/device_auth_service.dart';
import 'package:myapp/services/session_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class LinkParentScreen extends StatefulWidget {
  const LinkParentScreen({super.key});

  @override
  State<LinkParentScreen> createState() => _LinkParentScreenState();
}

class _LinkParentScreenState extends State<LinkParentScreen> {
  final _codeController = TextEditingController();
  int _selectedOption = 0;
  bool _isLoading = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan QR code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startScanning() async {
    await _requestCameraPermission();
    if (mounted) {
      setState(() => _selectedOption = 0);
      _showScannerDialog();
    }
  }

  void _showScannerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Scan QR Code',
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _codeController.text = barcode.rawValue!;
                      Navigator.pop(context);
                      _submit();
                      break;
                    }
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Point camera at the QR code from parent\'s device',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the pairing code or scan QR'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().claimPairingToken(
      pairingToken: code,
      deviceModel: 'Android Device',
      platform: 'Android',
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      final deviceToken = result['device_token'] as String;
      final childHash = result['child_hash']?.toString();
      final childName = result['child_name']?.toString();
      await SessionService.saveChildSession(
        deviceToken: deviceToken,
        childHash: childHash,
        childName: childName,
      );
      if (childHash != null && childHash.trim().isNotEmpty) {
        await DeviceAuthService().saveCredentials(
          childHash: childHash,
          deviceToken: deviceToken,
        );
      } else {
        await DeviceAuthService().saveDeviceToken(deviceToken);
      }

      if (childHash != null &&
          childHash.trim().isNotEmpty &&
          childName != null &&
          childName.trim().isNotEmpty) {
        await AppDatabase().initialize();
        await AppDatabase().child.saveLinkedChildSettings(
          deviceToken: deviceToken,
          childHash: childHash,
          childName: childName,
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChildPermissionsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to connect'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link with Parent',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect with your parent\'s device to sync data and share progress.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Option 1: Scan QR
              _buildOptionCard(
                title: 'Scan QR Code',
                description:
                    'Scan the QR code displayed on your parent\'s device',
                icon: Icons.qr_code_scanner,
                isSelected: _selectedOption == 0,
                onTap: _startScanning,
              ),

              const SizedBox(height: 16),

              // Option 2: Type Code
              _buildOptionCard(
                title: 'Enter Code',
                description:
                    'Manually enter the code from your parent\'s device',
                icon: Icons.keyboard,
                isSelected: _selectedOption == 1,
                onTap: () => setState(() => _selectedOption = 1),
              ),

              const SizedBox(height: 24),

              // Show text field if option 2 is selected
              if (_selectedOption == 1) ...[
                Text(
                  'Enter Code',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                      letterSpacing: 2,
                    ),
                    filled: true,
                    fillColor: AppColors.cardBlueBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.accentBlue,
                        width: 2,
                      ),
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading
                        ? AppColors.primaryPurple.withValues(alpha: 0.5)
                        : AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
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

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBlueBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentBlue : AppColors.surfaceOverlay,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentBlue.withValues(alpha: 0.2)
                    : AppColors.primaryPurple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.accentBlue : AppColors.textGrey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.accentBlue : AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}
