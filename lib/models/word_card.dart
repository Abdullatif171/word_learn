import 'package:json_annotation/json_annotation.dart';
part 'word_card.g.dart';

@JsonSerializable()
class WordCard {
  final String englishWord;
  final String turkishTranslation;
  final String category;
  // Yeni Alanlar
  final int reviewIntervalDays; // Öğrenme adımı (0: Yeni/Bilinmiyor, >0: SRS adımı)
  final String? nextReviewTimestamp; // Bir sonraki tekrar zaman damgası (ISO 8601 string)

  WordCard({
    @JsonKey(name: 'english') required this.englishWord,
    @JsonKey(name: 'turkish') required this.turkishTranslation,
    @JsonKey(name: 'kategori') required this.category, 
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