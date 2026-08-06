import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/ayah_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static List<AyahModel> _allAyahs = [];
  static Function(AyahModel)? onNotificationClicked;

  // 1. تهيئة الإشعارات وتحديد المنطقة الزمنية بناءً على جهاز المستخدم أوتوماتيكياً
  static Future<void> initNotification({Function(AyahModel)? onClicked}) async {
    onNotificationClicked = onClicked;
    
    // استخدام التوقيت المحلي للجهاز مباشرة
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(details.payload!);
            final AyahModel ayah = AyahModel(
              id: data['id'],
              text: data['text'],
              tafseer: data['tafseer'],
              audioPath: data['audioPath'].isEmpty ? null : data['audioPath'],
            );
            if (onNotificationClicked != null) {
              onNotificationClicked!(ayah);
            }
          } catch (e) {
            // تجاهل أخطاء التفكيك
          }
        }
      },
    );

    await _loadAyahs();
  }

  // 2. طلب الصلاحيات (الإشعارات + المنبهات الدقيقة)
  static Future<bool> requestPermission() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    final bool? granted = await androidImplementation?.requestNotificationsPermission();
    
    try {
      await androidImplementation?.requestExactAlarmsPermission();
    } catch (_) {}

    return granted ?? false;
  }

  // 3. تحميل الآيات
  static Future<void> _loadAyahs() async {
    if (_allAyahs.isNotEmpty) return;
    try {
      String jsonString = await rootBundle.loadString('assets/quran_data.json');
      List<dynamic> jsonList = jsonDecode(jsonString);
      _allAyahs = jsonList.map((e) => AyahModel.fromJson(e)).toList();
    } catch (e) {
      _allAyahs = [];
    }
  }

  // 4. اختيار الآية العشوائية غير المكررة
  static Future<AyahModel> getNextAyahInCycle() async {
    await _loadAyahs();
    if (_allAyahs.isEmpty) {
      return AyahModel(
        id: 1,
        text: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
        tafseer: 'تفسير افتراضي',
        audioPath: 'audio/1.mp3',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    List<String>? remainingStrList = prefs.getStringList('remaining_ayah_ids');

    List<int> remainingIds = [];
    if (remainingStrList == null || remainingStrList.isEmpty) {
      remainingIds = _allAyahs.map((a) => a.id).toList();
      remainingIds.shuffle(Random());
    } else {
      remainingIds = remainingStrList.map((idStr) => int.parse(idStr)).toList();
    }

    int chosenId = remainingIds.removeAt(0);

    await prefs.setStringList(
      'remaining_ayah_ids',
      remainingIds.map((id) => id.toString()).toList(),
    );

    return _allAyahs.firstWhere(
      (a) => a.id == chosenId,
      orElse: () => _allAyahs.first,
    );
  }

  // 5. دالة الجدولة الرئيسية (من 5 إلى 16 ساعة بعد أول إشعار)
  static Future<void> scheduleRandomNotification({bool isFirstInstall = false}) async {
    AyahModel nextAyah = await getNextAyahInCycle();
    Random random = Random();

    int minutesToAdd;
    if (isFirstInstall) {
      // إشعار أول سريع للمستخدم للتجربة والتأكد (من 5 إلى 15 دقيقة)
      minutesToAdd = 5 + random.nextInt(11);
    } else {
      // 🎯 الحد الأدنى 5 ساعات، والحد الأقصى 16 ساعة (5 + 0..11)
      int hours = 5 + random.nextInt(12);
      minutesToAdd = hours * 60;
    }

    List<String> words = nextAyah.text.trim().split(RegExp(r'\s+'));
    String titleWords = words.take(3).join(' ');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tazkara_quran_channel_v3',
      'إشعارات آيات تذكرة',
      channelDescription: 'إشعارات دورية بآيات القرآن الكريم وتفسيرها',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // استخدام التوقيت المحلي الفعلي للتليفون (tz.local)
    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesToAdd));

    await _notificationsPlugin.cancelAll();

    await _notificationsPlugin.zonedSchedule(
      0,
      '$titleWords... (انقر للتفسير)',
      nextAyah.text,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'id': nextAyah.id,
        'text': nextAyah.text,
        'tafseer': nextAyah.tafseer,
        'audioPath': nextAyah.audioPath ?? '',
      }),
    );
  }

  // 🧪 دالة تجريبية سريعة (إشعار بعد 10 ثواني للضمان والتجربة)
  static Future<void> testNotificationAfter10Seconds() async {
    AyahModel ayah = await getNextAyahInCycle();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tazkara_quran_channel_v3',
      'إشعارات آيات تذكرة',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      999,
      'تَذْكِرَةٌ - تجربة فورية',
      ayah.text,
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'id': ayah.id,
        'text': ayah.text,
        'tafseer': ayah.tafseer,
        'audioPath': ayah.audioPath ?? '',
      }),
    );
  }
}
