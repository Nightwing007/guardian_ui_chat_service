import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ConnectedChildrenScreen extends StatefulWidget {
  final String email;
  final String password;
  final VoidCallback onBack;

  const ConnectedChildrenScreen({
    super.key,
    required this.email,
    required this.password,
    required this.onBack,
  });

  @override
  State<ConnectedChildrenScreen> createState() => _ConnectedChildrenScreenState();
}

class _ConnectedChildrenScreenState extends State<ConnectedChildrenScreen> {
  final _authService = AuthService();
  List<dynamic> _children = [];
  bool _isLoading = true;
  String? _selectedChildHash;
  String? _pairingToken;
  bool _isGeneratingToken = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    print('Loading children...');
    final result = await _authService.getChildren(
      email: widget.email,
      password: widget.password,
    );
    print('getChildren result: $result');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'];
          print('Children data: $data');
          if (data is List) {
            _children = data;
          } else if (data is Map && data.containsKey('children')) {
            _children = data['children'] ?? [];
          } else {
            _children = [];
          }
        } else {
          print('Error loading children: ${result['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to load children')),
          );
        }
      });
    }
  }

  Future<void> _generatePairingToken(String childHash) async {
    setState(() {
      _isGeneratingToken = true;
      _selectedChildHash = childHash;
      _pairingToken = null;
    });

    final result = await _authService.generatePairingToken(
      email: widget.email,
      password: widget.password,
      childHash: childHash,
    );

    if (mounted) {
      setState(() {
        _isGeneratingToken = false;
        if (result['success'] == true) {
          _pairingToken = result['data']['pairing_token'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to generate token')),
          );
        }
      });
    }
  }

  void _showPairingDialog(String childName, String childHash) {
    String? localPairingToken = _pairingToken;
    bool localIsGenerating = _isGeneratingToken;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E20),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pair with $childName',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Show this QR code to your child\'s device',
                  style: GoogleFonts.poppins(
                    color: AppColors.textGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                if (localIsGenerating)
                  const CircularProgressIndicator(color: Colors.white)
                else if (localPairingToken != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: localPairingToken!,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBlueBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            localPairingToken!,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(content: Text('Token copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: () async {
                      setModalState(() => localIsGenerating = true);
                      
                      final result = await _authService.generatePairingToken(
                        email: widget.email,
                        password: widget.password,
                        childHash: childHash,
                      );

                      if (modalContext.mounted) {
                        setModalState(() {
                          localIsGenerating = false;
                          if (result['success'] == true) {
                            localPairingToken = result['data']['pairing_token'];
                            _pairingToken = localPairingToken;
                          } else {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(result['message'] ?? 'Failed')),
                            );
                          }
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Generate Pairing Token',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: Text(
          'Connected Children',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _children.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.child_care, color: AppColors.textGrey, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No children connected',
                        style: GoogleFonts.poppins(
                          color: AppColors.textGrey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a child account to get started',
                        style: GoogleFonts.poppins(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _children.length,
                  itemBuilder: (context, index) {
                    final child = _children[index];
                    final childName = '${child['first_name']} ${child['last_name'] ?? ''}'.trim();
                    final childHash = child['child_hash'];
                    final isPaired = child['is_paired'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBlueBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.2),
                            child: Icon(
                              Icons.child_care,
                              color: AppColors.accentBlue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  childName,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isPaired ? Icons.check_circle : Icons.link_off,
                                      color: isPaired ? Colors.green : AppColors.textGrey,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isPaired ? 'Paired' : 'Not paired',
                                      style: GoogleFonts.poppins(
                                        color: isPaired ? Colors.green : AppColors.textGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!isPaired)
                            ElevatedButton(
                              onPressed: () => _showPairingDialog(childName, childHash),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Pair',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}