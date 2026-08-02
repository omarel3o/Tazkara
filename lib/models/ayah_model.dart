class AyahModel {
  final int id;
  final String text;
  final String tafseer;
  final String? audioPath;

  AyahModel({
    required this.id,
    required this.text,
    required this.tafseer,
    this.audioPath,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json) {
    String rawAudio = (json['audio_file'] ?? '').toString().trim();
    String? audio;
    if (rawAudio.isNotEmpty) {
      audio = 'audio/$rawAudio';
    }

    return AyahModel(
      id: json['id'] as int,
      text: json['aya_text'] as String,
      tafseer: json['tafseer'] as String,
      audioPath: audio,
    );
  }
}