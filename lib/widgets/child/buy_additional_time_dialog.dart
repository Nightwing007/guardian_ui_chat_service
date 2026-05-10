import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/session_service.dart';
import 'package:myapp/theme/app_colors.dart';

class BuyAdditionalTimeDialog extends StatefulWidget {
  final String? appName;
  final String? packageName;
  final VoidCallback? onPurchaseComplete;

  const BuyAdditionalTimeDialog({
    super.key,
    this.appName,
    this.packageName,
    this.onPurchaseComplete,
  });

  @override
  State<BuyAdditionalTimeDialog> createState() =>
      _BuyAdditionalTimeDialogState();
}

class _BuyAdditionalTimeDialogState extends State<BuyAdditionalTimeDialog> {
  final _db = AppDatabase();
  final _auth = AuthService();

  static const int _minutesPerPoint = 10;
  static const Color _matteBlack = Color(0xFF101012);
  static const Color _charcoal = Color(0xFF19191C);
  static const Color _softGrey = Color(0xFFC9C9CF);

  int _pointsToSpend = 1;
  int _totalPoints = 10;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final points = await _db.child.getTotalPoints();
    if (!mounted) return;

    setState(() {
      _totalPoints = points;
      _pointsToSpend = points > 0 ? _pointsToSpend.clamp(1, points) : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedMinutes = _pointsToSpend * _minutesPerPoint;
    final hasPoints = _totalPoints > 0;
    final canBuy = hasPoints && widget.packageName != null && !_isPurchasing;
    final dialogTitle = widget.appName == null
        ? 'Buy Screen Time'
        : 'Buy Time for ${widget.appName}';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_matteBlack, Color(0xFF151518), Color(0xFF0B0B0D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(dialogTitle),
              const SizedBox(height: 20),
              _buildBalanceCard(),
              const SizedBox(height: 16),
              _buildPurchaseCard(hasPoints, selectedMinutes),
              const SizedBox(height: 18),
              _buildPointSlider(hasPoints),
              const SizedBox(height: 18),
              _buildInfoNote(),
              const SizedBox(height: 20),
              _buildActions(canBuy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String dialogTitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Use points to unlock extra minutes for today',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildCloseButton(context),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryMetric(
              label: 'Points left',
              value: '$_totalPoints',
              helper: 'available',
            ),
          ),
          Container(
            width: 1,
            height: 52,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _buildSummaryMetric(
              label: 'Rate',
              value: '1 pt',
              helper: '= 10 min',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(bool hasPoints, int selectedMinutes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: _charcoal,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            hasPoints
                ? '+${_formatMinutes(selectedMinutes)}'
                : 'No time available',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPoints
                ? 'Costs $_pointsToSpend ${_pointsToSpend == 1 ? 'point' : 'points'}'
                : 'Complete tasks to earn points first',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasPoints ? _softGrey : AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _buildPointPackage(1)),
              const SizedBox(width: 8),
              Expanded(child: _buildPointPackage(3)),
              const SizedBox(width: 8),
              Expanded(child: _buildPointPackage(6)),
              const SizedBox(width: 8),
              Expanded(child: _buildPointPackage(12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    final note = widget.packageName == null
        ? 'Point buying is available from a limited app row. This top-level screen time view is only a preview.'
        : 'Extra time is added locally for this app today. Tomorrow it returns to the normal parent-set limit.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _softGrey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool canBuy) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              disabledForegroundColor: Colors.white.withValues(alpha: 0.52),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Request Parent',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: canBuy ? _handleUsePoints : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.62),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Use Points to Buy',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleUsePoints() async {
    final packageName = widget.packageName;
    if (packageName == null || packageName.trim().isEmpty) {
      _showMessage('Choose a limited app first.');
      return;
    }

    setState(() => _isPurchasing = true);

    final result = await _db.child.buyAdditionalAppTime(
      packageName: packageName,
      pointsToSpend: _pointsToSpend,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _isPurchasing = false);
      _showMessage(result.message ?? 'Could not buy extra time.');
      return;
    }

    final session = await SessionService.getChildSession();
    final childHash = session['childHash'];
    final deviceToken = session['deviceToken'];

    if (childHash == null || deviceToken == null) {
      await _rollbackPurchase(packageName, result);
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      _showMessage('Could not sync points. Please reconnect and try again.');
      return;
    }

    final cloudResult = await _auth.spendChildPoints(
      childHash: childHash,
      deviceToken: deviceToken,
      points: _pointsToSpend,
      packageName: packageName,
      additionalMinutes: result.additionalMinutes,
    );

    if (!mounted) return;

    if (cloudResult['success'] != true) {
      await _rollbackPurchase(packageName, result);
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      _showMessage(
        cloudResult['message']?.toString() ??
            'Could not sync points. Please try again.',
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final message =
        'Added ${_formatMinutes(result.additionalMinutes)} for today.';

    await _syncReturnedPointBalance(cloudResult['data']);

    widget.onPurchaseComplete?.call();
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: _charcoal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _rollbackPurchase(
    String packageName,
    AdditionalTimePurchaseResult result,
  ) {
    return _db.child.rollbackAdditionalAppTimePurchase(
      packageName: packageName,
      pointsToRestore: _pointsToSpend,
      minutesToRemove: result.additionalMinutes,
    );
  }

  Future<void> _syncReturnedPointBalance(dynamic data) async {
    if (data is! Map) return;

    final totalPoints =
        _readInt(data['total_points']) ??
        _readInt(data['remaining_points']) ??
        _readInt(data['points']);
    if (totalPoints == null) return;

    await _db.child.setTotalPoints(totalPoints);
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: _charcoal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required String helper,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helper,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _softGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildPointSlider(bool hasPoints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Choose points',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              hasPoints ? '$_pointsToSpend / $_totalPoints pts' : '0 pts',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _softGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: _softGrey,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.12),
            disabledActiveTrackColor: Colors.white.withValues(alpha: 0.12),
            disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            disabledThumbColor: Colors.white.withValues(alpha: 0.38),
          ),
          child: Slider(
            value: hasPoints ? _pointsToSpend.toDouble() : 0,
            min: hasPoints ? 1 : 0,
            max: hasPoints ? _totalPoints.toDouble() : 1,
            divisions: hasPoints && _totalPoints > 1 ? _totalPoints - 1 : null,
            onChanged: hasPoints && !_isPurchasing
                ? (value) => setState(() => _pointsToSpend = value.round())
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPointPackage(int points) {
    final canAfford = points <= _totalPoints;
    final isSelected = canAfford && _pointsToSpend == points;
    final minutes = points * _minutesPerPoint;

    return InkWell(
      onTap: canAfford && !_isPurchasing
          ? () => setState(() => _pointsToSpend = points)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: canAfford ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: canAfford ? 0.12 : 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatMinutes(minutes),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: canAfford
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.34),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$points ${points == 1 ? 'point' : 'points'}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: canAfford
                    ? Colors.white.withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 min';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);

    if (hours > 0 && remainingMinutes > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    if (hours > 0) return '${hours}h';
    return '$remainingMinutes min';
  }
}
