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

  static Future<void> initNotification() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // يتم التعامل مع فتح الشاشة من الإشعار
      },
    );

    await _loadAyahs();
  }

  static Future<bool> requestPermission() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await androidImplementation?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> _loadAyahs() async {
    if (_allAyahs.isNotEmpty) return;
    try {
      String jsonString = await rootBundle.loadString('assets/quran_data.json');
      List<dynamic> jsonList = jsonDecode(jsonString);
      _allAyahs = jsonList.map((data) => AyahModel.fromJson(data)).toList();
    } catch (e) {
      _allAyahs = [];
    }
  }

  // الحصول على الآية التالية وفقاً للحلقة العشوائية (دون تكرار حتى تنتهي الـ 56 آية)
  static Future<AyahModel> getNextAyahInCycle() async {
    await _loadAyahs();
    if (_allAyahs.isEmpty) {
      return AyahModel(id: 1, text: 'جارٍ تحميل الآيات...', tafseer: '');
    }

    final prefs = await SharedPreferences.getInstance();
    List<String>? remainingIdsStr = prefs.getStringList('remaining_ayah_ids');

    List<int> remainingIds = [];
    if (remainingIdsStr != null && remainingIdsStr.isNotEmpty) {
      remainingIds = remainingIdsStr.map((e) => int.parse(e)).toList();
    }

    // إنشاء دورة عشوائية جديدة عند الانتهاء أو البدء لأول مرة
    if (remainingIds.isEmpty) {
      remainingIds = _allAyahs.map((a) => a.id).toList();
      remainingIds.shuffle(Random());
    }

    int currentAyahId = remainingIds.removeAt(0);

    // حفظ المتبقي من الدورة العشوائية
    await prefs.setStringList(
      'remaining_ayah_ids',
      remainingIds.map((e) => e.toString()).toList(),
    );

    return _allAyahs.firstWhere(
      (a) => a.id == currentAyahId,
      orElse: () => _allAyahs.first,
    );
  }

  // جدولة الإشعار بمدة عشوائية مابين 8 إلى 22 ساعة فعلياً
  static Future<void> scheduleRandomNotification() async {
    AyahModel nextAyah = await getNextAyahInCycle();
    
    // 1. حساب الوقت العشوائي بين 8 و 22 ساعة
    Random random = Random();
    int randomHours = 8 + random.nextInt(15); // من 8 إلى 22 ساعة

    // 2. اقتطاع أول كلمتين فقط للعنوان
    List<String> words = nextAyah.text.trim().split(RegExp(r'\s+'));
    String firstTwoWords = words.take(2).join(' ');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tazkara_quran_channel',
      'إشعارات آيات تذكرة',
      channelDescription: 'إشعارات يومية بآيات القرآن الكريم وتفسيرها',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // 3. استخدام التوقيت العشوائي (randomHours) لجدولة الإشعار المستقبلي
    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(hours: randomHours));

    await _notificationsPlugin.zonedSchedule(
      0,
      '$firstTwoWords... (انقر للتفسير)',
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
}