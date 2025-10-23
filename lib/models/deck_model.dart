// models/deck_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'deck_model.g.dart'; // Bu dosyanın 'flutter pub run build_runner build' ile oluşturulması gerekir

@JsonSerializable()
class Deck {
  final String id;
  final String name;
  final String description;
  final String downloadUrl; // Firebase Storage URL'si (bizim simülasyonda ID olarak kullanılacak)
  final int wordCount;

  Deck({
    required this.id,
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.wordCount,
  });

  factory Deck.fromJson(Map<String, dynamic> json) => _$DeckFromJson(json);
  Map<String, dynamic> toJson() => _$DeckToJson(this);
}