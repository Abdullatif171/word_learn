// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Deck _$DeckFromJson(Map<String, dynamic> json) => Deck(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  downloadUrl: json['downloadUrl'] as String,
  wordCount: (json['wordCount'] as num).toInt(),
);

Map<String, dynamic> _$DeckToJson(Deck instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'downloadUrl': instance.downloadUrl,
  'wordCount': instance.wordCount,
};
