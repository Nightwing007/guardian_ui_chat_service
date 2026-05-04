import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SetScreenTimeBottomSheet extends StatefulWidget {
  final Duration initialDuration;
  final String title;

  const SetScreenTimeBottomSheet({
    super.key,
    this.initialDuration = const Duration(hours: 3),
    this.title = 'Set Screen Time',
  });

  @override
  State<SetScreenTimeBottomSheet> createState() => _SetScreenTimeBottomSheetState();
}

class _SetScreenTimeBottomSheetState extends State<SetScreenTimeBottomSheet> {
  late Duration _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E20), // Dark grey background matching the screenshot
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Time Picker
            SizedBox(
              height: 180,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: _selectedDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    setState(() {
                      _selectedDuration = newDuration;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _selectedDuration);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF385E8E), // Blue button from screenshot
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
