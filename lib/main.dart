import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/home_tab.dart';
import 'screens/place_tab.dart';
import 'screens/clothing_tab.dart';
import 'screens/season_tab.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
  );
  await NotificationService().init();
  runApp(const ClosetMapApp());
}

class ClosetMapApp extends StatelessWidget {
  const ClosetMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '옷장지도',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C8EE6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 1),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeTab(),
    PlaceTab(),
    ClothingTab(),
    SeasonTab(),
  ];

  static const _labels = ['홈', '보관 장소', '내 옷', '계절 전환'];
  static const _icons = [
    Icons.home_outlined,
    Icons.inventory_2_outlined,
    Icons.checkroom_outlined,
    Icons.swap_horiz,
  ];
  static const _activeIcons = [
    Icons.home,
    Icons.inventory_2,
    Icons.checkroom,
    Icons.swap_horiz,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _labels[_index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          const names = ['home', 'places', 'clothes', 'season'];
          AnalyticsService.logTabViewed(names[i]);
        },
        destinations: List.generate(
          4,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_activeIcons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
