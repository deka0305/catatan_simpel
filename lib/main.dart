import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'notes_page.dart';
import 'tasks_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Simpel',
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
        scaffoldBackgroundColor: const Color(0xFFFFF5E4), // Cream
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
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: kDebugMode ? false : true,
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Catatan' : 'Tugas'),
        backgroundColor: Color(0xFF143D59),
      ),
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
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Catatan'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tugas'),
        ],
      ),
    );
  }
}
