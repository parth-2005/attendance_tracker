import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/settings.dart';
import 'models/subject.dart';
import 'screens/dashboard_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_edit_subject.dart';
import 'screens/subject_calendar_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final Box<Settings> _settingsBox;

  final _router = GoRouter(
    initialLocation: '/',
    routes: [
      // Root route renders a BottomNavShell which manages internal tab state
      GoRoute(
        path: '/',
        name: 'root',
        builder: (c, s) => const BottomNavShell(),
      ),
      GoRoute(
        path: '/calendar/:id',
        name: 'calendar-subject',
        builder: (c, s) {
          final id = s.pathParameters['id'] ?? '';
          return CalendarScreen(subjectId: id);
        },
      ),
      GoRoute(path: '/add-subject', name: 'add-subject', builder: (c, s) => AddEditSubjectScreen(subject: s.extra as Subject?)),
      GoRoute(
        path: '/subject/:id',
        name: 'subject-calendar',
        builder: (c, s) {
          final id = s.pathParameters['id'] ?? '';
          return SubjectCalendarScreen(subjectId: id);
        },
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box<Settings>('settings');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _settingsBox.listenable(),
      builder: (context, Box<Settings> box, _) {
        final settings = box.get('prefs');
        final darkMode = settings?.darkMode ?? true;

        final colorScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: darkMode ? Brightness.dark : Brightness.light,
        );

        final theme = ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          primaryColor: const Color(0xFF1E88E5),
        );

        return MaterialApp.router(
          title: 'Attendance Tracker',
          theme: theme,
          routerConfig: _router,
        );
      },
    );
  }

}

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => GoRouter.of(context).push('/add-subject'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}