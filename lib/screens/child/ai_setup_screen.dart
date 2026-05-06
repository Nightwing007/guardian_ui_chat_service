import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/main_layout.dart';
import 'package:http/http.dart' as http;

class AiModelSetupScreen extends StatefulWidget {
  const AiModelSetupScreen({super.key});

  @override
  State<AiModelSetupScreen> createState() => _AiModelSetupScreenState();
}

class _AiModelSetupScreenState extends State<AiModelSetupScreen> {
  bool _isDownloading = false;
  bool _isPickingFile = false;
  double _downloadProgress = 0;
  String? _selectedFilePath;
  String _statusMessage = 'Setup your AI assistant to continue';

  // Placeholder URL for the model - in a real app, this would be a valid Gemma model URL
  final String _modelDownloadUrl = 'https://example.com/gemma-2b-it-cpu-int4.bin';

  Future<void> _pickModelFile() async {
    if (_isPickingFile) return;
    
    setState(() {
      _isPickingFile = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow any file type for model files
      );

      if (result != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _statusMessage = 'Model file selected: ${result.files.single.name}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error selecting file: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = 'Downloading AI Model...';
    });

    try {
      // In a real implementation, we would use Dio or similar for better progress tracking
      // and actually download the large model file.
      // For this demonstration, we'll simulate a download.
      
      for (int i = 0; i <= 100; i += 5) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _downloadProgress = i / 100;
        });
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/gemma_model.bin';
      
      // We would write the file here
      // await File(filePath).writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _selectedFilePath = filePath;
          _statusMessage = 'Model downloaded successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download failed: $e';
        });
      }
    }
  }

  void _finishSetup() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainLayout(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg-app.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'AI Assistant Setup',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // AI Icon / Illustration
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentBlue.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/robohead.png',
                      height: 80,
                      width: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Guardian AI Brain',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 48),

                if (_isDownloading) ...[
                  // Progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 12,
                      backgroundColor: AppColors.cardBlueBackground,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ] else if (_selectedFilePath == null) ...[
                  // Choice buttons
                  _buildActionButton(
                    title: 'Download Model',
                    subtitle: 'Automatic setup (Recommended)',
                    icon: Icons.cloud_download_outlined,
                    onTap: _downloadModel,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    title: 'Choose Model File',
                    subtitle: 'Select a local .bin or .gguf file',
                    icon: Icons.folder_open_outlined,
                    onTap: _pickModelFile,
                    isPrimary: false,
                  ),
                ] else ...[
                  // Success state
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Ready!',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Your assistant is prepared to help.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _finishSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.accentBlue.withValues(alpha: 0.1) : AppColors.cardBlueBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? AppColors.accentBlue.withValues(alpha: 0.4) : AppColors.surfaceOverlay,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isPrimary 
                    ? AppColors.accentBlue.withValues(alpha: 0.2)
                    : AppColors.primaryPurple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isPrimary ? AppColors.accentBlue : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}
