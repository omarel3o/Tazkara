import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/ayah_model.dart';

class AyahDetailScreen extends StatefulWidget {
  final AyahModel ayah;
  final bool fromNotification;

  const AyahDetailScreen({
    Key? key,
    required this.ayah,
    this.fromNotification = false,
  }) : super(key: key);

  @override
  State<AyahDetailScreen> createState() => _AyahDetailScreenState();
}

class _AyahDetailScreenState extends State<AyahDetailScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;
  bool _hasAudio = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    if (widget.ayah.audioPath == null || widget.ayah.audioPath!.trim().isEmpty) {
      _hasAudio = false;
    } else {
      _initAudio();
    }
  }

  void _initAudio() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  void _togglePlay() async {
    if (!_hasAudio) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(AssetSource(widget.ayah.audioPath!));
    }
  }

  void _setSpeed(double speed) async {
    setState(() {
      _playbackRate = speed;
    });
    await _audioPlayer.setPlaybackRate(speed);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text('آية رقم ${widget.ayah.id}'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. المشغل أو العبارة البديلة
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      const Text(
                        'سماع الآية',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      if (!_hasAudio)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'سيتم توفر سماع الآية قريباً',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 45,
                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                              color: Colors.green,
                              onPressed: _togglePlay,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Text(_formatDuration(_position), style: const TextStyle(fontSize: 12)),
                              Expanded(
                                child: Slider(
                                  min: 0,
                                  max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                                  value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                                  onChanged: (val) async {
                                    await _audioPlayer.seek(Duration(seconds: val.toInt()));
                                  },
                                ),
                              ),
                              Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [0.5, 1.0, 1.25, 1.5].map((speed) {
                            return ChoiceChip(
                              label: Text('${speed}x'),
                              selected: _playbackRate == speed,
                              onSelected: (_) => _setSpeed(speed),
                            );
                          }).toList(),
                        )
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. عرض نص الآية
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Text(
                  widget.ayah.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. التفسير والمعاني
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التفسير والمعاني:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.ayah.tafseer,
                      style: const TextStyle(fontSize: 16, height: 1.7),
                    ),
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