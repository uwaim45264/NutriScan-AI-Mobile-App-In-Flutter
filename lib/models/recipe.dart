import 'package:hive/hive.dart';

part 'recipe.g.dart';

@HiveType(typeId: 1)
class Recipe extends HiveObject {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final List<String> ingredients;
  @HiveField(2)
  final List<String> steps;
  @HiveField(3)
  final int calories;
  @HiveField(4)
  final String healthTag;
  @HiveField(5)
  final String description;
  @HiveField(6)
  final List<String> benefits;

  Recipe({
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.calories,
    required this.healthTag,
    required this.description,
    required this.benefits,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      name: json['name'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      calories: json['calories'] ?? 0,
      healthTag: json['healthTag'] ?? '',
      description: json['description'] ?? '',
      benefits: List<String>.from(json['benefits'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ingredients': ingredients,
      'steps': steps,
      'calories': calories,
      'health_tag': healthTag,
      'description': description,
      'benefits': benefits,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      name: map['name'] ?? '',
      ingredients: List<String>.from(map['ingredients'] ?? []),
      steps: List<String>.from(map['steps'] ?? []),
      calories: map['calories'] ?? 0,
      healthTag: map['health_tag'] ?? '',
      description: map['description'] ?? '',
      benefits: List<String>.from(map['benefits'] ?? []),
    );
  }
}
