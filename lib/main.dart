import 'dart:async';
import 'dart:ui';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/home_tab.dart';
import 'screens/onboarding_screen.dart';
import 'screens/place_tab.dart';
import 'screens/clothing_tab.dart';
import 'screens/season_tab.dart';
import 'services/analytics_service.dart';
import 'services/backup_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/season_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
  );
  await NotificationService().init();
  // 시작을 막지 않도록 비동기로 실행 (둘 다 멱등)
  unawaited(DatabaseService().migrateLegacyImages());
  unawaited(_maybeNotifySeasonChange());
  runApp(const ClosetMapApp());
}

/// 마지막 실행 시점과 계절이 바뀌었으면 보관/꺼내기 리마인드 알림 발송
Future<void> _maybeNotifySeasonChange() async {
  final prefs = await SharedPreferences.getInstance();
  final current = SeasonService.currentSeason().name;
  final last = prefs.getString('last_seen_season');
  if (last != null && last != current) {
    await NotificationService()
        .showSeasonChangeAlert(SeasonService.seasonChangeMessage());
  }
  await prefs.setString('last_seen_season', current);
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
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showOnboarding = !(prefs.getBool('onboarding_done') ?? false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_showOnboarding!) {
      return OnboardingScreen(
        onDone: () => setState(() => _showOnboarding = false),
      );
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onMenuSelected(String value) async {
    if (value == 'backup') {
      final err = await BackupService.exportBackup();
      if (err != null) _showSnack(err);
      return;
    }
    if (value == 'restore') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('백업에서 복원'),
          content: const Text(
              '현재 앱의 모든 데이터(옷·보관 장소·사진·코디 기록)가 '
              '백업 파일의 내용으로 교체됩니다.\n계속할까요?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('복원')),
          ],
        ),
      );
      if (ok != true) return;
      final err = await BackupService.importBackup();
      if (err == 'cancelled') return;
      _showSnack(err ?? '복원이 완료됐어요!');
    }
  }

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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('백업 만들기'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 20),
                    SizedBox(width: 10),
                    Text('백업에서 복원'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
