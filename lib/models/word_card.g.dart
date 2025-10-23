// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WordCard _$WordCardFromJson(Map<String, dynamic> json) => WordCard(
  englishWord: json['english'] as String,
  turkishTranslation: json['turkish'] as String,
  category: json['kategori'] as String,
);

Map<String, dynamic> _$WordCardToJson(WordCard instance) => <String, dynamic>{
  'english': instance.englishWord,
  'turkish': instance.turkishTranslation,
  'kategori': instance.category,
};
