import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../providers/profile_provider.dart';
import '../models/meal_plan.dart';
import 'meal_detailed_planner_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  bool _loading = false;
  MealPlan? _mealPlan;
  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();

  String? _selectedContinent;
  String? _selectedCountry;
  String _selectedLanguage = 'English';

  final Map<String, List<String>> _continentsData = {
    'Asia': ['India', 'China', 'Japan', 'Thailand', 'Vietnam', 'Korea', 'Pakistan', 'Indonesia'],
    'Europe': ['Italy', 'France', 'Greece', 'Spain', 'Germany', 'Turkey', 'UK'],
    'Africa': ['Nigeria', 'Egypt', 'Ethiopia', 'Morocco', 'South Africa', 'Kenya'],
    'North America': ['USA', 'Mexico', 'Canada', 'Jamaica', 'Cuba'],
    'South America': ['Brazil', 'Peru', 'Argentina', 'Colombia', 'Chile'],
    'Oceania': ['Australia', 'New Zealand', 'Fiji', 'Samoa'],
    'Antarctica': ['Research Station Cuisines'],
  };

  final Map<String, String> _countryToLanguage = {
    'India': 'Hindi', 'China': 'Chinese', 'Japan': 'Japanese', 'Pakistan': 'Urdu',
    'Mexico': 'Spanish', 'Spain': 'Spanish', 'France': 'French', 'Germany': 'German',
    'Italy': 'Italian', 'Brazil': 'Portuguese', 'USA': 'English', 'UK': 'English',
    'Canada': 'English', 'Australia': 'English', 'Egypt': 'Arabic', 'Morocco': 'Arabic',
    'Turkey': 'Turkish', 'Thailand': 'Thai', 'Vietnam': 'Vietnamese', 'Korea': 'Korean',
  };

  String _cleanJsonResponse(String response) {
    if (response.contains("```json")) {
      response = response.split("```json")[1].split("```")[0];
    } else if (response.contains("```")) {
      final parts = response.split("```");
      if (parts.length >= 3) response = parts[1];
    }
    return response.trim();
  }

  Future<void> _generateMealPlan({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _mealPlan = null;
    });

    final profile = Provider.of<ProfileProvider>(context, listen: false).profile;
    final userId = profile?.name ?? 'guest';
    final country = _selectedCountry ?? 'Global';
    final language = _selectedLanguage;
    final cacheKey = 'meal_plan_${userId}_${country}_${language}';

    if (!forceRefresh) {
      // 1. Check Hive First (Fastest, works offline)
      try {
        final box = await Hive.openBox('meal_plans_box');
        final cachedData = box.get(cacheKey);
        if (cachedData != null) {
          setState(() {
            _mealPlan = cachedData as MealPlan;
            _loading = false;
          });
          debugPrint('Loaded meal plan from Hive');
          return;
        }
      } catch (e) {
        debugPrint('Hive read error: $e');
      }

      // 2. Check Supabase (Online sync)
      try {
        final existingPlan = await _supabaseService.getMealPlan(userId, country, language);
        if (existingPlan != null) {
          setState(() {
            _mealPlan = existingPlan;
            _loading = false;
          });
          // Cache to Hive for future offline use
          final box = await Hive.openBox('meal_plans_box');
          await box.put(cacheKey, existingPlan);
          debugPrint('Loaded meal plan from Supabase and saved to Hive');
          return;
        }
      } catch (e) {
        debugPrint('Supabase fetch error: $e');
      }
    }

    // 3. Call AI (If no cache or forced refresh)
    String userContext = profile == null
        ? "Guest Mode: Provide a general balanced daily meal plan based on standard 2000kcal intake."
        : """
          User Profile: 
          - Name: ${profile.name}
          - Physicals: ${profile.age}yo ${profile.gender}, ${profile.height}cm, ${profile.weight}kg
          - Activity: ${profile.activityLevel}
          - Goal: ${profile.goal}
          - Medical: ${profile.healthConditions.isEmpty ? 'None' : profile.healthConditions.join(', ')}
          - Allergies: ${profile.allergies.isEmpty ? 'None' : profile.allergies.join(', ')}
          - Diet Style: ${profile.dietaryPreference}
          """;

    String regionContext = (_selectedCountry != null)
        ? "Specialize in $_selectedCountry cuisine and use $_selectedLanguage language."
        : "Provide general international healthy cuisine in English.";

    final prompt = """
      Act as a professional personalized nutritionist. 
      
      USER CONTEXT:
      $userContext

      REGION CONTEXT:
      $regionContext

      TASK:
      Generate a daily meal plan that is MEDICALLY SAFE and PERFECTLY TAILORED for this user. 
      
      STRICT GUIDELINES:
      1. MEDICAL PRECISION: If user has Diabetes, avoid high-glycemic foods. If Hypertension, avoid high sodium.
      2. PERSONALIZATION: Address the user by name (${profile?.name ?? 'the user'}) in the 'summary' and each meal 'description'.
      3. BENEFITS: In the 'benefits' list, explain exactly why each meal is good for ${profile?.name ?? 'the user'}'s specific goal or medical condition.

      IMPORTANT: All text content MUST be in ${_selectedLanguage}.
      Return the response as a valid JSON object.
      
      JSON Structure:
      {
        "totalCalories": 2200,
        "summary": "Personalized summary in ${_selectedLanguage} addressing the user.",
        "meals": [
          {
            "type": "Breakfast",
            "name": "Meal name in ${_selectedLanguage}",
            "description": "Short personalized description in ${_selectedLanguage}",
            "calories": 450,
            "ingredients": ["Ingredient with quantity", "Ingredient with quantity"],
            "steps": ["Detailed prep step", "Detailed prep step"],
            "benefits": ["Personalized benefit 1", "Personalized benefit 2"]
          },
          ... (include Lunch, Dinner, and Snacks)
        ]
      }
    """;

    try {
      final result = await _aiService.getResponse(
        prompt, 
        apiKeyOverride: dotenv.env['MEAL_API_KEY']
      );
      
      final cleanedResult = _cleanJsonResponse(result);
      final decoded = jsonDecode(cleanedResult);
      final newPlan = MealPlan.fromJson(decoded);

      setState(() {
        _mealPlan = newPlan;
      });

      // Save to Supabase
      await _supabaseService.saveMealPlan(userId, country, language, newPlan);
      
      // Save to Hive
      final box = await Hive.openBox('meal_plans_box');
      await box.put(cacheKey, newPlan);
      debugPrint('Generated and saved meal plan to Supabase and Hive');

    } catch (e) {
      debugPrint('Error generating meal plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create your plan.', style: TextStyle(fontSize: 12, color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RegionPicker(
          continentsData: _continentsData,
          onSelectionComplete: (continent, country) {
            setState(() {
              _selectedContinent = continent;
              _selectedCountry = country;
              _selectedLanguage = _countryToLanguage[country] ?? 'English';
            });
            Navigator.pop(context);
            _generateMealPlan();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileName = Provider.of<ProfileProvider>(context).profile?.name ?? "friend";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'STRATEGY',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.public_rounded, color: Colors.red, size: 22),
            onPressed: _showSelectionBottomSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
                  const SizedBox(height: 32),
                  Text(
                    'Curating your daily path...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildHeaderInfo(profileName),
                ),
                const SizedBox(height: 48),
                if (_mealPlan == null)
                  _buildEmptyState()
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildSectionTag('THE FOCUS'),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildSummaryInfo(),
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildSectionTag('YOUR SCHEDULE'),
                  ),
                  const SizedBox(height: 24),
                  ..._mealPlan!.meals.map((meal) => _buildMealCard(meal)).toList(),
                  const SizedBox(height: 32),
                  _buildRegenerateAction(),
                  const SizedBox(height: 60),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionTag(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        color: Colors.red,
      ),
    );
  }

  Widget _buildHeaderInfo(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello $name,',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your daily\npath today.',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A simple, personalized guide to help you find your natural rhythm today.',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            'Ready to start?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a region to generate a plan that fits your life and goals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: _showSelectionBottomSheet,
            child: Container(
              height: 64,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text(
                'CHOOSE REGION',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedCountry ?? "Global"} Based'.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white),
            ),
            Text(
              '${_mealPlan!.totalCalories} kcal total',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _mealPlan!.summary,
          style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildMealCard(Meal meal) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealDetailedPlannerScreen(meal: meal),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meal.type.toUpperCase(),
                  style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                Text(
                  '${meal.calories} kcal',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              meal.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, height: 1.1, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              meal.description,
              style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.6),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegenerateAction() {
    return Center(
      child: TextButton(
        onPressed: () => _generateMealPlan(forceRefresh: true),
        child: Text(
          'REGENERATE PLAN',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _RegionPicker extends StatefulWidget {
  final Map<String, List<String>> continentsData;
  final Function(String, String) onSelectionComplete;

  const _RegionPicker({
    required this.continentsData,
    required this.onSelectionComplete,
  });

  @override
  State<_RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<_RegionPicker> {
  String? _selectedContinent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                if (_selectedContinent != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedContinent = null),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                  ),
                if (_selectedContinent != null) const SizedBox(width: 16),
                Text(
                  _selectedContinent == null ? 'Select Region' : 'Select Country',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedContinent == null ? _buildContinentList() : _buildCountryList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildContinentList() {
    final continents = widget.continentsData.keys.toList();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      itemCount: continents.length,
      itemBuilder: (context, index) {
        final continent = continents[index];
        return GestureDetector(
          onTap: () => setState(() => _selectedContinent = continent),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
            ),
            child: Row(
              children: [
                Text(continent, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[800]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountryList() {
    final countries = widget.continentsData[_selectedContinent] ?? [];
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        return GestureDetector(
          onTap: () => widget.onSelectionComplete(_selectedContinent!, country),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
            ),
            child: Row(
              children: [
                Text(country, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                const Icon(Icons.add_rounded, size: 20, color: Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }
}
