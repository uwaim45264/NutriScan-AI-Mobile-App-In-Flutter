import 'package:hive/hive.dart';

part 'meal_plan.g.dart';

@HiveType(typeId: 2)
class MealPlan extends HiveObject {
  @HiveField(0)
  final List<Meal> meals;
  @HiveField(1)
  final int totalCalories;
  @HiveField(2)
  final String summary;

  MealPlan({
    required this.meals,
    required this.totalCalories,
    required this.summary,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      meals: (json['meals'] as List).map((e) => Meal.fromJson(e)).toList(),
      totalCalories: json['totalCalories'] ?? 0,
      summary: json['summary'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meals': meals.map((m) => m.toMap()).toList(),
      'total_calories': totalCalories,
      'summary': summary,
    };
  }

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    return MealPlan(
      meals: (map['meals'] as List).map((e) => Meal.fromMap(e as Map<String, dynamic>)).toList(),
      totalCalories: map['total_calories'] ?? 0,
      summary: map['summary'] ?? '',
    );
  }
}

@HiveType(typeId: 3)
class Meal extends HiveObject {
  @HiveField(0)
  final String type; // Breakfast, Lunch, etc.
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final int calories;
  @HiveField(4)
  final List<String> ingredients;
  @HiveField(5)
  final List<String> steps;
  @HiveField(6)
  final List<String> benefits;

  Meal({
    required this.type,
    required this.name,
    required this.description,
    required this.calories,
    required this.ingredients,
    required this.steps,
    required this.benefits,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      calories: json['calories'] ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      benefits: List<String>.from(json['benefits'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'description': description,
      'calories': calories,
      'ingredients': ingredients,
      'steps': steps,
      'benefits': benefits,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      type: map['type'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      calories: map['calories'] ?? 0,
      ingredients: List<String>.from(map['ingredients'] ?? []),
      steps: List<String>.from(map['steps'] ?? []),
      benefits: List<String>.from(map['benefits'] ?? []),
    );
  }
}
