import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:file_picker/file_picker.dart';
import 'package:myapp/screens/child/main_layout.dart';
import 'package:myapp/services/child/ai_inference.dart';

class AiModelSetupScreen extends StatefulWidget {
  const AiModelSetupScreen({super.key});

  @override
  State<AiModelSetupScreen> createState() => _AiModelSetupScreenState();
}

enum SetupMode { none, downloading, importing, done, error }

class _AiModelSetupScreenState extends State<AiModelSetupScreen>
    with SingleTickerProviderStateMixin {
  SetupMode _mode = SetupMode.none;
  double _progress = 0;
  String _statusMessage = '';
  late AnimationController _pulseController;
  bool _engineReady = false;

  static const String _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  String get _hfToken => '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _downloadModel() async {
    final ready = await _ensureEngineReady();
    if (!ready) return;
    setState(() {
      _mode = SetupMode.downloading;
      _progress = 0;
      _statusMessage = 'Connecting to HuggingFace...';
    });

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(_modelUrl, token: _hfToken)
          .withProgress((progress) {
        setState(() {
          _progress = progress / 100.0;
          _statusMessage = 'Downloading... ${progress.toStringAsFixed(1)}%';
        });
      }).install();

      await _finalizeActivation();
    } catch (e) {
      _onError(e.toString());
    }
  }

  Future<void> _importModel() async {
    final ready = await _ensureEngineReady();
    if (!ready) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['litertlm'],
      dialogTitle: 'Select Gemma 4 model (.litertlm file)',
    );

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      _onError('Selected file has no path. Please choose a local .litertlm file.');
      return;
    }

    if (!path.toLowerCase().endsWith('.litertlm')) {
      _onError('Invalid file type. Please select a .litertlm model file.');
      return;
    }

    setState(() {
      _mode = SetupMode.importing;
      _progress = 0;
      _statusMessage = 'Loading model from file...';
    });

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromFile(path)
          .withProgress((progress) {
        setState(() {
          _progress = progress / 100.0;
          _statusMessage = 'Installing... $progress%';
        });
      }).install();

      await _finalizeActivation();
    } catch (e) {
      _onError(e.toString());
    }
  }

  Future<bool> _ensureEngineReady() async {
    if (_engineReady) return true;
    try {
      await FlutterGemma.initialize();
      _engineReady = true;
      return true;
    } catch (e) {
      _onError('AI engine failed to initialize. Please restart the app.');
      return false;
    }
  }

  Future<void> _finalizeActivation() async {
    setState(() {
      _statusMessage = 'Activating model...';
    });

    final ready = await AiChannel.ensureModel();
    if (!ready) {
      _onError(
        'Model installed but could not be activated. Please try again or restart the app.',
      );
      return;
    }

    await _onSuccess();
  }

  void _onError(String error) {
    setState(() {
      _mode = SetupMode.error;
      _statusMessage = error;
    });
  }

  Future<void> _onSuccess() async {
    setState(() {
      _mode = SetupMode.done;
      _progress = 1.0;
      _statusMessage = 'Model ready!';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainLayout(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }


  bool get _isBusy =>
      _mode == SetupMode.downloading || _mode == SetupMode.importing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildModelInfo(),
              const SizedBox(height: 32),
              if (!_isBusy && _mode != SetupMode.done) ...[
                _buildOptionCard(
                  icon: Icons.download_rounded,
                  title: 'Download Model',
                  subtitle: 'Download Gemma 4 E2B IT directly\nfrom HuggingFace (~2.41 GB)',
                  color: const Color(0xFF6C63FF),
                  onTap: _downloadModel,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  ],
                ),
                const SizedBox(height: 16),
                _buildOptionCard(
                  icon: Icons.folder_open_rounded,
                  title: 'Import from Device',
                  subtitle: 'Select an existing .litertlm file\nalready on your device',
                  color: const Color(0xFF03DAC6),
                  onTap: _importModel,
                ),
              ],
              if (_isBusy) _buildProgressSection(),
              if (_mode == SetupMode.error) _buildErrorSection(),
              if (_mode == SetupMode.done) _buildSuccessSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3D5AFE)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF)
                      .withOpacity(0.3 + _pulseController.value * 0.3),
                  blurRadius: 20 + _pulseController.value * 10,
                  spreadRadius: _pulseController.value * 3,
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guardian AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Model Setup',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
                ),
                child: const Text(
                  'Gemma 4 E2B IT',
                  style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF03DAC6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF03DAC6).withOpacity(0.3)),
                ),
                child: const Text(
                  '🖼️ Vision',
                  style: TextStyle(
                    color: Color(0xFF03DAC6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _modelStat(Icons.memory_rounded, 'Parameters', '5.1B total · 2.3B active'),
          _modelStat(Icons.storage_rounded, 'File Size', '~2.41 GB (.litertlm format)'),
          _modelStat(Icons.devices_rounded, 'Platform', 'Android · iOS · On-Device'),
          _modelStat(Icons.visibility_rounded, 'Vision', 'Analyze images & screenshots'),
        ],
      ),
    );
  }

  Widget _modelStat(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 16),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final isDownloading = _mode == SetupMode.downloading;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isDownloading ? 'Downloading Model' : 'Importing Model',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: const Color(0xFF6C63FF),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isDownloading) ...[
                const SizedBox(height: 16),
                Text(
                  '💡 Keep the app open. Download will continue in the background.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D6D).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF4D6D).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFFF4D6D), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Error',
                    style: TextStyle(
                      color: Color(0xFFFF4D6D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _mode = SetupMode.none),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4D6D),
                    side: const BorderSide(color: Color(0xFFFF4D6D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF03DAC6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF03DAC6).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF03DAC6), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Model loaded! Launching Guardian AI...',
              style: TextStyle(color: Color(0xFF03DAC6), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
