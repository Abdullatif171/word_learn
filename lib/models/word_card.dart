// ignore_for_file: invalid_annotation_target

import 'package:json_annotation/json_annotation.dart';
part 'word_card.g.dart';

@JsonSerializable()
class WordCard {
  final String englishWord;
  final String turkishTranslation;
  final String category; // Yeni eklenen kategori alanı

  WordCard({
    @JsonKey(name: 'english') required this.englishWord,
    @JsonKey(name: 'turkish') required this.turkishTranslation,
    @JsonKey(name: 'kategori') required this.category, 
  });

  factory WordCard.fromJson(Map<String, dynamic> json) => _$WordCardFromJson(json);
  Map<String, dynamic> toJson() => _$WordCardToJson(this);
}