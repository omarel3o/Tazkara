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

  // 1. تهيئة الإشعارات والمفتاح
  static Future<void> initNotification({Function(AyahModel)? onClicked}) async {
    onNotificationClicked = onClicked;
    
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

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
            // التعامل مع أي خطأ أثناء تحليل البيانات
          }
        }
      },
    );

    await _loadAyahs();
  }

  // 2. طلب صلاحية الإشعارات
  static Future<bool> requestPermission() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await androidImplementation?.requestNotificationsPermission();
    return granted ?? false;
  }

  // 3. قراءة كافة الآيات من الملف بدون تقييم بعدد معين
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

  // 4. الحصول على الآية التالية في الحلقة العشوائية
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

  // 5. جدولة الإشعار (isFirstInstall: true للإشعار الأول من 5 لـ 120 دقيقة)
  static Future<void> scheduleRandomNotification({bool isFirstInstall = false}) async {
    AyahModel nextAyah = await getNextAyahInCycle();
    Random random = Random();

    int minutesToAdd;
    if (isFirstInstall) {
      // من 5 دقائق إلى 120 دقيقة للإشعار الأول
      minutesToAdd = 5 + random.nextInt(116);
    } else {
      // من 5 ساعات (300 دقيقة) إلى 16 ساعة (960 دقيقة) للإشعارات التالية
      int hours = 5 + random.nextInt(12); // بين 5 و 16 ساعة
      minutesToAdd = hours * 60;
    }

    // اقتصاص أول 3 كلمات للعنوان
    List<String> words = nextAyah.text.trim().split(RegExp(r'\s+'));
    String titleWords = words.take(3).join(' ');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tazkara_quran_channel',
      'إشعارات آيات تذكرة',
      channelDescription: 'إشعارات دورية بآيات القرآن الكريم وتفسيرها',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesToAdd));

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
}