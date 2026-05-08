import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/parent/app_parent_database.dart';

class SetScreenTimeBottomSheet extends StatefulWidget {
  final Duration initialDuration;
  final String title;
  final String? childHash;
  final String? email;
  final String? password;
  final String? packageName;
  final int? limitId;
  final bool hasLimit;

  const SetScreenTimeBottomSheet({
    super.key,
    this.initialDuration = const Duration(hours: 3),
    this.title = 'Set Screen Time',
    this.childHash,
    this.email,
    this.password,
    this.packageName,
    this.limitId,
    this.hasLimit = false,
  });

  @override
  State<SetScreenTimeBottomSheet> createState() => _SetScreenTimeBottomSheetState();
}

class _SetScreenTimeBottomSheetState extends State<SetScreenTimeBottomSheet> {
  late Duration _selectedDuration;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
  }

  Future<void> _onUnrestrict() async {
    print('Unrestrict called: limitId=${widget.limitId}, package=${widget.packageName}, childHash=${widget.childHash}');

    if (widget.packageName == null || widget.childHash == null) return;

    setState(() => _isDeleting = true);

    await AppParentDatabase().deleteAppLimit(
      childHash: widget.childHash!,
      packageName: widget.packageName!,
    );

    if (widget.limitId != null && widget.email != null && widget.password != null) {
      print('Deleting cloud limit with id: ${widget.limitId}');
      final result = await AuthService().deleteAppLimit(
        email: widget.email!,
        password: widget.password!,
        childHash: widget.childHash!,
        limitId: widget.limitId!,
      );
      print('Delete result: $result');
    } else {
      print('Skipping cloud delete - missing limitId or credentials');
    }

    if (mounted) {
      Navigator.pop(context, null);
    }
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

            if (widget.hasLimit) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : _onUnrestrict,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4444),
                    side: const BorderSide(color: Color(0xFFFF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF4444),
                          ),
                        )
                      : const Text('Unrestrict', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _selectedDuration);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF385E8E),
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
