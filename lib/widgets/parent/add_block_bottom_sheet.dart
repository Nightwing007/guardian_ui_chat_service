import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AddBlockBottomSheet extends StatefulWidget {
  const AddBlockBottomSheet({super.key});

  @override
  State<AddBlockBottomSheet> createState() => _AddBlockBottomSheetState();
}

class _AddBlockBottomSheetState extends State<AddBlockBottomSheet> {
  String _selectedType = 'Website'; // 'Website' or 'App'
  String _selectedApp = 'Instagram'; // Default app
  final TextEditingController _urlController = TextEditingController();
  
  // Mock list of apps installed
  final List<String> _availableApps = ['Instagram', 'Snapchat', 'TikTok', 'YouTube', 'Facebook'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF242426), // Dark grey background
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
            // Drag Handle
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Block Type Dropdown
            const Text('Block', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDropdown(
              icon: _selectedType == 'Website' ? Icons.language : Icons.apps,
              value: _selectedType,
              items: ['Website', 'App'],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedType = val);
                }
              },
            ),
            const SizedBox(height: 16),

            // Dynamic Field (Site URL or Select App)
            if (_selectedType == 'Website') ...[
              const Text('Site URL', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade600),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g., tiktok.com',
                    hintStyle: TextStyle(color: Colors.white30),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ] else ...[
              const Text('Select App', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDropdown(
                icon: Icons.smartphone,
                value: _selectedApp,
                items: _availableApps,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedApp = val);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),

            // Block For Timer
            const Text('Block For', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: const Duration(hours: 2, minutes: 15),
                  onTimerDurationChanged: (Duration newDuration) {
                    // Handle duration change
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
                  final String name = _selectedType == 'Website' ? _urlController.text : _selectedApp;
                  if (name.isEmpty) return; // Prevent empty

                  final IconData icon = _selectedType == 'Website' ? Icons.language : Icons.apps;
                  final Color color = _selectedType == 'Website' ? Colors.blueAccent : const Color(0xFF25D366);

                  Navigator.pop(context, {
                    'name': name,
                    'icon': icon,
                    'color': color,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade600),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: const Color(0xFF242426),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(item),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
