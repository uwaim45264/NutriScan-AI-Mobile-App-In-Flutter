import 'package:hive/hive.dart';

part 'food_analysis.g.dart';

@HiveType(typeId: 4)
class FoodAnalysis extends HiveObject {
  @HiveField(0)
  final String query;

  @HiveField(1)
  final String foodName;

  @HiveField(2)
  final String jsonData;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String language;

  @HiveField(5)
  final String? imagePath; // Local path for offline

  @HiveField(6)
  final String? imageUrl;  // Remote URL for online

  FoodAnalysis({
    required this.query,
    required this.foodName,
    required this.jsonData,
    required this.createdAt,
    required this.language,
    this.imagePath,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'query': query.toLowerCase(),
      'food_name': foodName,
      'json_data': jsonData,
      'created_at': createdAt.toIso8601String(),
      'language': language,
      'image_url': imageUrl,
      'image_path': imagePath,
    };
  }

  factory FoodAnalysis.fromMap(Map<String, dynamic> map) {
    return FoodAnalysis(
      query: map['query'] ?? '',
      foodName: map['food_name'] ?? '',
      jsonData: map['json_data'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      language: map['language'] ?? 'English',
      imageUrl: map['image_url'],
      imagePath: map['image_path'],
    );
  }
}
