import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/ayah_detail_screen.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'models/ayah_model.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة خدمة الإشعارات وتحديد حدث الضغط
  await NotificationService.initNotification(onClicked: (AyahModel ayah) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AyahDetailScreen(
          ayah: ayah,
          fromNotification: true,
        ),
      ),
    );
    // جدولة الإشعار التالي بعد الفتح (من 5 إلى 16 ساعة)
    NotificationService.scheduleRandomNotification(isFirstInstall: false);
  });

  String? userName = await LocalStorageService.getUserName();
  bool isDark = await LocalStorageService.getDarkMode();

  // 2. إذا كان المستخدم قد سجل حسابه بالفعل سابقاً، يتم تفعيل وسرد الجدولة
  if (userName != null && userName.isNotEmpty) {
    await NotificationService.requestPermission();
    NotificationService.scheduleRandomNotification(isFirstInstall: false);
  }

  runApp(MyApp(hasName: userName != null && userName.isNotEmpty, initialIsDark: isDark));
}

class MyApp extends StatefulWidget {
  final bool hasName;
  final bool initialIsDark;

  const MyApp({Key? key, required this.hasName, required this.initialIsDark}) : super(key: key);

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialIsDark;
  }

  void toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
    LocalStorageService.saveDarkMode(isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'تَذْكِرَةٌ',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'ArabicFont',
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'ArabicFont',
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: widget.hasName ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
