import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum SosState { initial, sending, success }

class SosBottomSheet extends StatefulWidget {
  final VoidCallback? onChatPressed;

  const SosBottomSheet({super.key, this.onChatPressed});

  @override
  State<SosBottomSheet> createState() => _SosBottomSheetState();
}

class _SosBottomSheetState extends State<SosBottomSheet> with SingleTickerProviderStateMixin {
  SosState _currentState = SosState.initial;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Takes 3 seconds
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentState = SosState.success;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startSending() {
    setState(() {
      _currentState = SosState.sending;
    });
    _animationController.forward();
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF222428), // Dark modal background to match screens
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content tightly
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Central Animated Icon
          _buildIcon(),

          const SizedBox(height: 24),

          // Dynamic Title & Description
          Text(
            _currentState == SosState.success
                ? 'Alert Sent Successfully'
                : 'Send Emergency Alert?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _currentState == SosState.success
                ? 'Your parent has been notified and\nyour live location is now shared.'
                : 'This will instantly notify your parent\nand share your live location for\nimmediate help.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textGrey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Dynamic Action Area
          _buildActionArea(),

          const SizedBox(height: 24),

          // Footer Text
          Text(
            'Guardians will be notified via SMS and App alert.',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (_currentState == SosState.success) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFE4F9E0), // Light green circle
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.check_rounded,
            color: Color(0xFF4ADE80), // Bright green check
            size: 40,
          ),
        ),
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB), // Light red/pink circle
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.sosRed.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.shield,
              color: AppColors.sosRed,
              size: 44,
            ),
            const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (_currentState == SosState.initial) {
      return Column(
        children: [
          _buildSendButton(),
          const SizedBox(height: 24),
          _buildCancelText(),
        ],
      );
    }

    if (_currentState == SosState.sending) {
      return Column(
        children: [
          const SizedBox(height: 16),
          // Progress Loader
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _animationController.value,
                        minHeight: 4,
                        backgroundColor: Colors.white,
                        color: AppColors.sosRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SENDING...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.sosRed,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 60), // Space to keep size consistent with button hidden
          _buildCancelText(),
        ],
      );
    }

    // Success state actions
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSuccessActionButton(
          icon: Icons.phone,
          label: 'Call Parent',
          color: const Color(0xFF4A84F6),
          backgroundColor: const Color(0xFFB5C8E8),
        ),
        const SizedBox(width: 16),
        _buildSuccessActionButton(
          icon: Icons.chat_bubble_rounded,
          label: 'Send Message',
          color: const Color(0xFF4ADE80),
          backgroundColor: const Color(0xFFBFE0C1),
          onTap: () {
            Navigator.pop(context); // Close the bottom sheet
            if (widget.onChatPressed != null) {
              widget.onChatPressed!();
            }
          },
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _startSending,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.sosRed,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.locationDot, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Send SOS',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelText() {
    return GestureDetector(
      onTap: _cancel,
      child: Text(
        'Cancel',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSuccessActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color, // Text color matches icon background
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
