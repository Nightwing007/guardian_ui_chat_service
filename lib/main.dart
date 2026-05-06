import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/welcome_screen.dart';
import 'package:myapp/screens/parent/parent_main_layout.dart';
import 'package:myapp/services/session_service.dart';

void main() {
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
  Map<String, String?>? _session;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await SessionService.getParentSession();
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryPurple,
          ),
        ),
      );
    }

    if (_session?['isLoggedIn'] == 'true' &&
        _session?['email'] != null &&
        _session?['password'] != null) {
      return ParentMainLayout(
        email: _session!['email']!,
        password: _session!['password']!,
        childHash: _session!['childHash'] ?? '',
      );
    }

    return const WelcomeScreen();
  }
}
