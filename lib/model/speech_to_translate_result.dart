class SpeechToTranslateResult {
  final String? audio;
  final String? text;
  final String? translateText;
  final String type;
  final String reason;

  SpeechToTranslateResult({
    required this.type,
    required this.reason,
    this.audio,
    this.text,
    this.translateText,
  });

  factory SpeechToTranslateResult.fromJson(Map<String, dynamic> json) {
    return SpeechToTranslateResult(
      type: json['type'],
      reason: json['reason'],
      audio: json['audio'],
      text: json['text'],
      translateText: json['translateText'],
    );
  }
}
