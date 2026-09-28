import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/notes_page.dart';
import 'pages/tasks_page.dart';
import 'pages/usaha_page.dart';
import 'services/realtime_sync_manager.dart';

void main() {
  RealtimeSyncManager.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Simpel',
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFF143D59), // Navy blue
          onPrimary: Colors.white,
          secondary: const Color(0xFFF4B41A), // Yellow
          onSecondary: Colors.black,
          background: const Color(0xFFFFF5E4), // Cream
          onBackground: Colors.black,
          surface: const Color(0xFFFFF5E4), // Cream
          onSurface: Colors.black,
          error: Colors.red,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF143D59), // Navy blue
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFF4B41A), // Yellow
          foregroundColor: Color(0xFF143D59), // Navy blue
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF143D59), // Navy blue
          selectedItemColor: Color(0xFFF4B41A), // Yellow
          unselectedItemColor: Color(0xFFB0A295), // Soft brown/grey
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    NotesPage(),
    TasksPage(),
    UsahaPage(), // Menu baru: Usaha
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: _pages[
          _selectedIndex], // Jangan pakai Scaffold lagi di NotesPage/TasksPage
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Catatan'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tugas'),
          BottomNavigationBarItem(icon: Icon(Icons.business_center), label: 'Usaha'),
        ],
      ),
    );
  }
}
