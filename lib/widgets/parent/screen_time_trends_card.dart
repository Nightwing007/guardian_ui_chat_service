import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

class ScreenTimeTrendsCard extends StatelessWidget {
  const ScreenTimeTrendsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.weeklyActivityGradientStart,
            AppColors.weeklyActivityGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Screen Time Trends',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Daily Limit: ',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                        const TextSpan(
                          text: '3 hr',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: Colors.grey.shade300, size: 14),
                    const SizedBox(width: 6),
                    Text('This Week', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade300, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Today Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Today',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: '2h 15m',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '/3h',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade300, // Empty part
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.85, // 2h 15m out of 3h
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A), // Filled dark blue part
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            children: [
              _buildLegendItem(const Color(0xFF2563EB), 'Today'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFF38BDF8), 'Previous Day'),
            ],
          ),
          const SizedBox(height: 40),

          // Chart Area
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Custom painted curves
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrendsChartPainter(),
                  ),
                ),
                
                // Tooltip
                Positioned(
                  top: -24,
                  left: 170, // Rough position for THU
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '2h 15m',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Little triangle pointer
                      CustomPaint(
                        size: const Size(10, 5),
                        painter: _TooltipTrianglePainter(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // X Axis Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('MON', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('TUE', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('WED', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('THU', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('FRI', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('SAT', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('SUN', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _TrendsChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkBluePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final lightBluePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    
    // Light Blue Line (Previous Day)
    final lightPath = Path();
    lightPath.moveTo(0, h * 0.7);
    lightPath.cubicTo(w * 0.15, h * 0.6, w * 0.3, h * 0.9, w * 0.45, h * 0.7);
    lightPath.cubicTo(w * 0.6, h * 0.5, w * 0.7, h * 0.95, w * 0.85, h * 0.7);
    lightPath.cubicTo(w * 0.9, h * 0.6, w * 0.95, h * 0.75, w, h * 0.7);
    canvas.drawPath(lightPath, lightBluePaint);

    // Dark Blue Line (Today)
    final darkPath = Path();
    darkPath.moveTo(0, h * 0.5);
    darkPath.cubicTo(w * 0.2, h * 0.3, w * 0.3, h * 0.6, w * 0.5, h * 0.3); // Peak at THU
    darkPath.cubicTo(w * 0.65, h * 0.7, w * 0.8, h * 0.3, w, h * 0.5);
    canvas.drawPath(darkPath, darkBluePaint);

    // Draw the dot on THU (middle) for Dark Blue Line
    final dotPaint = Paint()..color = const Color(0xFF2563EB);
    final innerDotPaint = Paint()..color = const Color(0xFF0D1721);
    
    // The peak of the dark curve around middle is roughly at w*0.5, h*0.35 based on cubic bezier
    // Let's just draw it exactly where the tooltip points
    final Offset dotPosition = Offset(w * 0.55, h * 0.35); 
    
    canvas.drawCircle(dotPosition, 6, dotPaint);
    canvas.drawCircle(dotPosition, 3, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TooltipTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3B82F6);
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
