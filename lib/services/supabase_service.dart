import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/food_analysis.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  Future<String?> uploadImage(File imageFile, String folder) async {
    try {
      if (!await imageFile.exists()) return null;
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$folder/$fileName';
      
      await _supabase.storage.from('food_images').upload(path, imageFile).timeout(const Duration(seconds: 15));
      
      final String publicUrl = _supabase.storage.from('food_images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase uploadImage error: $e');
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    try {
      final data = {
        'name': profile.name,
        'age': profile.age,
        'gender': profile.gender,
        'height': profile.height,
        'weight': profile.weight,
        'activity_level': profile.activityLevel,
        'health_conditions': profile.healthConditions,
        'allergies': profile.allergies,
        'dietary_preference': profile.dietaryPreference,
        'goal': profile.goal,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('profiles').upsert(data, onConflict: 'name').timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Supabase saveProfile error: $e');
    }
  }

  Future<UserProfile?> getProfile(String name) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('name', name)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response != null) {
        return UserProfile(
          name: response['name'],
          age: response['age'],
          gender: response['gender'],
          height: (response['height'] as num).toDouble(),
          weight: (response['weight'] as num).toDouble(),
          activityLevel: response['activity_level'],
          healthConditions: List<String>.from(response['health_conditions'] ?? []),
          allergies: List<String>.from(response['allergies'] ?? []),
          dietaryPreference: response['dietary_preference'],
          goal: response['goal'],
        );
      }
    } catch (e) {
      debugPrint('Supabase getProfile error: $e');
    }
    return null;
  }

  Future<void> saveFoodAnalysis(FoodAnalysis analysis) async {
    try {
      await _supabase.from('food_analysis')
          .upsert(analysis.toMap(), onConflict: 'query, language')
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Supabase saveFoodAnalysis error: $e');
    }
  }

  Future<FoodAnalysis?> getFoodAnalysis(String query, String language) async {
    try {
      final response = await _supabase
          .from('food_analysis')
          .select()
          .eq('query', query.toLowerCase())
          .eq('language', language)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response != null) {
        return FoodAnalysis.fromMap(response);
      }
    } catch (e) {
      debugPrint('Supabase getFoodAnalysis error: $e');
    }
    return null;
  }

  Future<void> saveMealPlan(String userId, String country, String language, MealPlan plan) async {
    try {
      final data = plan.toMap();
      data['user_id'] = userId;
      data['country'] = country;
      data['language'] = language;
      data['created_at'] = DateTime.now().toIso8601String();

      await _supabase.from('meal_plans').upsert(data, onConflict: 'user_id, country, language');
    } catch (e) {
      debugPrint('Supabase saveMealPlan error: $e');
    }
  }

  Future<MealPlan?> getMealPlan(String userId, String country, String language) async {
    try {
      final response = await _supabase
          .from('meal_plans')
          .select()
          .eq('user_id', userId)
          .eq('country', country)
          .eq('language', language)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response != null) {
        return MealPlan.fromMap(response);
      }
    } catch (e) {
      debugPrint('Supabase getMealPlan error: $e');
    }
    return null;
  }

  Future<void> saveRecipes(String userId, String country, String language, List<Recipe> recipes) async {
    try {
      final data = {
        'user_id': userId,
        'country': country,
        'language': language,
        'recipes': recipes.map((r) => r.toMap()).toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('chef_recipes').upsert(data, onConflict: 'user_id, country, language');
    } catch (e) {
      debugPrint('Supabase saveRecipes error: $e');
    }
  }

  Future<List<Recipe>?> getRecipes(String userId, String country, String language) async {
    try {
      final response = await _supabase
          .from('chef_recipes')
          .select()
          .eq('user_id', userId)
          .eq('country', country)
          .eq('language', language)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response != null && response['recipes'] != null) {
        return (response['recipes'] as List)
            .map((r) => Recipe.fromMap(r as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Supabase getRecipes error: $e');
    }
    return null;
  }
}
