import 'package:json_annotation/json_annotation.dart';
part 'word_card.g.dart';

@JsonSerializable()
class WordCard {
  
  // --- DÜZELTME BAŞLANGICI ---
  // JsonKey ek açıklamaları buraya, alanların (fields) üstüne taşındı.
  
  @JsonKey(name: 'english') 
  final String englishWord;
  
  @JsonKey(name: 'turkish') 
  final String turkishTranslation;
  
  @JsonKey(name: 'kategori') 
  final String category;
  // --- DÜZELTME SONU ---

  final int reviewIntervalDays; // Öğrenme adımı (0: Yeni/Bilinmiyor, >0: SRS adımı)
  final String? nextReviewTimestamp; // Bir sonraki tekrar zaman damgası (ISO 8601 string)

  WordCard({
    // Ek açıklamalar constructor parametrelerinden kaldırıldı.
    required this.englishWord,
    required this.turkishTranslation,
    required this.category, 
    this.reviewIntervalDays = 0, // Varsayılan olarak 0 (yeni kelime)
    this.nextReviewTimestamp, // Varsayılan olarak null
  });

  WordCard copyWith({
    String? englishWord,
    String? turkishTranslation,
    String? category,
    int? reviewIntervalDays,
    String? nextReviewTimestamp,
  }) {
    return WordCard(
      englishWord: englishWord ?? this.englishWord,
      turkishTranslation: turkishTranslation ?? this.turkishTranslation,
      category: category ?? this.category,
      reviewIntervalDays: reviewIntervalDays ?? this.reviewIntervalDays,
      nextReviewTimestamp: nextReviewTimestamp ?? this.nextReviewTimestamp,
    );
  }

  factory WordCard.fromJson(Map<String, dynamic> json) => _$WordCardFromJson(json);
  Map<String, dynamic> toJson() => _$WordCardToJson(this);
}