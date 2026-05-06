import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/child_permissions_screen.dart';

class LinkParentScreen extends StatefulWidget {
  const LinkParentScreen({super.key});

  @override
  State<LinkParentScreen> createState() => _LinkParentScreenState();
}

class _LinkParentScreenState extends State<LinkParentScreen> {
  final _codeController = TextEditingController();
  int _selectedOption = 0; // 0 = scan, 1 = type code

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChildPermissionsScreen(),
      ),
    );
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
                description: 'Scan the QR code displayed on your parent\'s device',
                icon: Icons.qr_code_scanner,
                isSelected: _selectedOption == 0,
                onTap: () => setState(() => _selectedOption = 0),
              ),
              
              const SizedBox(height: 16),
              
              // Option 2: Type Code
              _buildOptionCard(
                title: 'Enter Code',
                description: 'Manually enter the 6-digit code from your parent\'s device',
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
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: AppColors.cardBlueBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.accentBlue, width: 2),
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
                  onPressed: _submit,
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
            Radio<int>(
              value: isSelected ? 1 : 0,
              groupValue: isSelected ? 1 : 0,
              onChanged: (_) => onTap(),
              activeColor: AppColors.accentBlue,
            ),
          ],
        ),
      ),
    );
  }
}