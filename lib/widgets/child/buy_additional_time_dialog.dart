import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/theme/app_colors.dart';

class BuyAdditionalTimeDialog extends StatefulWidget {
  final String? appName;
  const BuyAdditionalTimeDialog({super.key, this.appName});

  @override
  State<BuyAdditionalTimeDialog> createState() => _BuyAdditionalTimeDialogState();
}

class _BuyAdditionalTimeDialogState extends State<BuyAdditionalTimeDialog> {
  final _db = AppDatabase();
  double _sliderValue = 5;
  int _totalPoints = 10;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final points = await _db.child.getTotalPoints();
    if (mounted) setState(() => _totalPoints = points);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.appName == null
                        ? "Buy Additional\nScreen Time"
                        : "Buy Additional\nTime for ${widget.appName}",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DBE2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "$_totalPoints pts",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Choose extra time",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTimeChip(15, "15m"),
                const SizedBox(width: 8),
                _buildTimeChip(30, "30m"),
                const SizedBox(width: 8),
                _buildTimeChip(60, "1h"),
                const SizedBox(width: 8),
                _buildTimeChip(120, "2h"),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Points to use: ${_sliderValue.toInt()}",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _sliderValue,
              min: 1,
              max: _totalPoints.toDouble(),
              divisions: _totalPoints > 1 ? _totalPoints - 1 : 1,
              activeColor: AppColors.accentBlue,
              inactiveColor: Colors.grey.shade700,
              onChanged: (value) {
                setState(() => _sliderValue = value);
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Added ${_sliderValue.toInt()} minutes!",
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.accentBlue,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Confirm",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(int minutes, String label) {
    final isSelected = _sliderValue == minutes.toDouble();
    return GestureDetector(
      onTap: () {
        setState(() => _sliderValue = minutes.toDouble());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentBlue : Colors.grey.shade600,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}