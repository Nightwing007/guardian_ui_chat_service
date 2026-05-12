import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/ai_setup_screen.dart';
import 'package:myapp/screens/child/main_layout.dart';
import 'package:myapp/screens/welcome_screen.dart';
import 'package:myapp/screens/parent/parent_main_layout.dart';
import 'package:myapp/services/child/ai_inference.dart';
import 'package:myapp/services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterGemma.initialize();
  } catch (e) {
    debugPrint('[Main] FlutterGemma init failed: $e');
  }
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian AI UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SessionWrapper(),
    );
  }
}

class SessionWrapper extends StatefulWidget {
  const SessionWrapper({super.key});

  @override
  State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper> {
  bool _isLoading = true;
  Map<String, String?>? _parentSession;
  Map<String, String?>? _childSession;
  bool _childAiReady = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final parentSession = await SessionService.getParentSession();
    final childSession = await SessionService.getChildSession();
    var childAiReady = false;
    if (childSession?['role'] == SessionService.childRole &&
        childSession?['isLinked'] == 'true' &&
        childSession?['deviceToken'] != null) {
      childAiReady = await AiChannel.ensureModel();
    }
    setState(() {
      _parentSession = parentSession;
      _childSession = childSession;
      _childAiReady = childAiReady;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_childSession?['role'] == SessionService.childRole &&
        _childSession?['isLinked'] == 'true' &&
        _childSession?['deviceToken'] != null) {
      if (!_childAiReady) {
        return const AiModelSetupScreen();
      }
      return const MainLayout();
    }

    if (_parentSession?['isLoggedIn'] == 'true' &&
        _parentSession?['email'] != null &&
        _parentSession?['password'] != null) {
      return ParentMainLayout(
        email: _parentSession!['email']!,
        password: _parentSession!['password']!,
        childHash: _parentSession!['childHash'] ?? '',
      );
    }

    return const WelcomeScreen();
  }
}
