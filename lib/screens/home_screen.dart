import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../models/ayah_model.dart';
import 'ayah_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isDarkMode = false;
  bool _isLoadingAyah = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    String? name = await LocalStorageService.getUserName();
    bool dark = await LocalStorageService.getDarkMode();
    setState(() {
      _userName = name ?? '';
      _isDarkMode = dark;
    });
  }

  void _openRandomAyah() async {
    if (_isLoadingAyah) return;
    setState(() {
      _isLoadingAyah = true;
    });

    AyahModel ayah = await NotificationService.getNextAyahInCycle();

    setState(() {
      _isLoadingAyah = false;
    });

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AyahDetailScreen(ayah: ayah, fromNotification: false),
      ),
    );
  }

  void _showChangeNameDialog() {
    TextEditingController nameController = TextEditingController(text: _userName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير الاسم', textAlign: TextAlign.center),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'أدخل الاسم الجديد',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'الرجاء إدخال الاسم';
              }
              RegExp arabicRegex = RegExp(r'^[\u0600-\u06FF\s]+$');
              if (!arabicRegex.hasMatch(value.trim())) {
                return 'يجب كتابة الاسم باللغة العربية فقط';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                String newName = nameController.text.trim();
                await LocalStorageService.saveUserName(newName);
                setState(() {
                  _userName = newName;
                });
                if (!mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _openDeveloperLink() async {
    final Uri url = Uri.parse('https://portfolio.omar-khaled.workers.dev/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تَذْكِرَةٌ'),
        actions: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'change_name') {
                  _showChangeNameDialog();
                } else if (value == 'about') {
                  _openDeveloperLink();
                } else if (value == 'toggle_theme') {
                  bool newMode = !_isDarkMode;
                  setState(() {
                    _isDarkMode = newMode;
                  });
                  MyApp.of(context)?.toggleTheme(newMode);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'change_name',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('تغيير الاسم'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'about',
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20),
                      SizedBox(width: 8),
                      Text('عن المطور'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_theme',
                  child: Row(
                    children: [
                      Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
                      const SizedBox(width: 8),
                      Text(_isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن'),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // 1. مربع الترحيب
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'السلام عليكم يا $_userName',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'صَلِّ عَلَى النَّبِيِّ',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 2. زر آية اليوم في المنتصف
              InkWell(
                onTap: _openRandomAyah,
                borderRadius: BorderRadius.circular(20),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoadingAyah)
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          const Icon(Icons.auto_stories, size: 35, color: Colors.green),
                        const SizedBox(width: 15),
                        const Text(
                          'آية اليوم',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // 3. تقييم التطبيق في الأسفل اليسار
              Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Rating App',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        4,
                        (index) => const Icon(Icons.star, color: Colors.amber, size: 18),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}