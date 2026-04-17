import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/tasks_screen.dart';
import 'package:myapp/screens/chat_screen.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/custom_bottom_nav_bar.dart';
import 'package:myapp/widgets/sos_bottom_sheet.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

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
        extendBody: true,
        body: SafeArea(
          bottom: false, 
          child: IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
                onNavigate: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
              const TasksScreen(),
              ChatScreen(),
              Center(child: Text("Safety - Coming Soon", style: TextStyle(color: Colors.white))),
              Center(child: Text("Profile - Coming Soon", style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
        floatingActionButton: _currentIndex == 0 
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: FloatingActionButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SosBottomSheet(
                      onChatPressed: () {
                        setState(() {
                          _currentIndex = 2; // Jump to Chat tab
                        });
                      },
                    ),
                  );
                },
                backgroundColor: AppColors.sosRed,
                shape: const CircleBorder(),
                child: Text(
                  'SOS',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
