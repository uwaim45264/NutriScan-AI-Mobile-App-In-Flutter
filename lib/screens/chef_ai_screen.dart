import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../providers/profile_provider.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class ChefAIScreen extends StatefulWidget {
  const ChefAIScreen({super.key});

  @override
  State<ChefAIScreen> createState() => _ChefAIScreenState();
}

class _ChefAIScreenState extends State<ChefAIScreen> {
  bool _loading = false;
  List<Recipe> _recipes = [];
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
    'India': 'Hindi',
    'China': 'Chinese',
    'Japan': 'Japanese',
    'Pakistan': 'Urdu',
    'Mexico': 'Spanish',
    'Spain': 'Spanish',
    'France': 'French',
    'Germany': 'German',
    'Italy': 'Italian',
    'Brazil': 'Portuguese',
    'USA': 'English',
    'UK': 'English',
    'Canada': 'English',
    'Australia': 'English',
    'Egypt': 'Arabic',
    'Morocco': 'Arabic',
    'Turkey': 'Turkish',
    'Thailand': 'Thai',
    'Vietnam': 'Vietnamese',
    'Korea': 'Korean',
  };

  String _cleanJsonResponse(String response) {
    if (response.contains("```json")) {
      response = response.split("```json")[1].split("```")[0];
    } else if (response.contains("```")) {
      final parts = response.split("```");
      if (parts.length >= 3) {
        response = parts[1];
      }
    }
    return response.trim();
  }

  Future<void> _generateRecipes({bool forceRefresh = false}) async {
    if (_selectedContinent == null || _selectedCountry == null) return;

    setState(() {
      _loading = true;
      _recipes = [];
    });

    final profile = Provider.of<ProfileProvider>(context, listen: false).profile;
    final userId = profile?.name ?? 'guest';
    final country = _selectedCountry!;
    final language = _selectedLanguage;
    final cacheKey = 'chef_recipes_${userId}_${country}_${language}';

    if (!forceRefresh) {
      // 1. Try Hive first (Offline/Fast)
      try {
        final box = await Hive.openBox('chef_recipes_box');
        final cachedData = box.get(cacheKey);
        if (cachedData != null) {
          setState(() {
            _recipes = (cachedData as List).cast<Recipe>();
            _loading = false;
          });
          debugPrint('Recipes loaded from Hive');
          return;
        }
      } catch (e) {
        debugPrint('Hive read error: $e');
      }

      // 2. Try Supabase (Online)
      try {
        final existingRecipes = await _supabaseService.getRecipes(userId, country, language);
        if (existingRecipes != null && existingRecipes.isNotEmpty) {
          setState(() {
            _recipes = existingRecipes;
            _loading = false;
          });
          // Cache to Hive for future offline use
          final box = await Hive.openBox('chef_recipes_box');
          await box.put(cacheKey, existingRecipes);
          debugPrint('Recipes loaded from Supabase and cached to Hive');
          return;
        }
      } catch (e) {
        debugPrint('Supabase recipes fetch error: $e');
      }
    }

    // 3. Call AI
    String userContext;
    if (profile == null) {
      userContext = "Guest Mode: Provide general healthy recipe suggestions.";
    } else {
      userContext = """
        User Profile:
        - Name: ${profile.name}
        - Physicals: ${profile.age}yo ${profile.gender}, ${profile.height}cm, ${profile.weight}kg
        - Activity Level: ${profile.activityLevel}
        - Health Conditions: ${profile.healthConditions.join(", ")}
        - Allergies: ${profile.allergies.join(", ")}
        - Dietary Preference: ${profile.dietaryPreference}
        - Primary Goal: ${profile.goal}
      """;
    }

    final prompt = """
      Act as a professional personalized nutritionist and executive chef specializing in $country cuisine. 
      
      USER CONTEXT:
      $userContext

      TASK:
      Generate exactly 10 high-quality recipes from $country that are PERFECTLY SUITED for the user's profile.
      
      STRICT GUIDELINES:
      1. If the user has a health condition (like Diabetes or Hypertension), recipes MUST be low-sugar or low-sodium respectively.
      2. If the user has ALLERGIES, recipes MUST NOT contain those ingredients.
      3. PERSONALIZATION: Address the user by name (${profile?.name ?? 'the user'}) in the 'description' and 'benefits' for each recipe.
      
      IMPORTANT: All text content MUST be in $language language.
      
      Return the response as a valid JSON array of objects. 
      Each object must have these keys:
      - name: (string in $language)
      - ingredients: (array of strings in $language)
      - steps: (array of strings in $language)
      - calories: (integer)
      - healthTag: (string in $language)
      - description: (string in $language, personalized for the user's goal)
      - benefits: (array of strings in $language, explaining why it's good for the user's specific health profile)
    """;

    try {
      final result = await _aiService.getResponse(
        prompt, 
        apiKeyOverride: dotenv.env['CHEF_API_KEY']
      );
      
      final cleanedResult = _cleanJsonResponse(result);
      final List<dynamic> jsonList = jsonDecode(cleanedResult);
      final newRecipes = jsonList.map((e) => Recipe.fromJson(e)).toList();
      
      setState(() {
        _recipes = newRecipes;
      });

      // Save to Supabase
      await _supabaseService.saveRecipes(userId, country, language, newRecipes);
      
      // Save to Hive
      final box = await Hive.openBox('chef_recipes_box');
      await box.put(cacheKey, newRecipes);
      debugPrint('Generated recipes saved to Supabase and Hive');

    } catch (e) {
      debugPrint('Error generating recipes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate recipes.', style: TextStyle(fontSize: 12, color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
            _generateRecipes();
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
          'KITCHEN COMPANION',
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
          if (_recipes.isNotEmpty)
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
                    'Crafting your $_selectedCountry menu...',
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
                if (_recipes.isEmpty)
                  _buildEmptyState()
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildSectionTag('DISCOVER'),
                  ),
                  const SizedBox(height: 24),
                  ..._recipes.map((recipe) => _buildRecipeCard(recipe)).toList(),
                  const SizedBox(height: 16),
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
          'Flavors for\nyour rhythm.',
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
          'Explore dishes curated for your unique journey, inspired by world cuisines.',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
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
          const Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            'Ready to explore?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a region to find inspiration for your next healthy meal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.5),
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

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    recipe.healthTag.toUpperCase(),
                    style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
                Text(
                  '${recipe.calories} kcal',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              recipe.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, height: 1.1, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              recipe.description,
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
        onPressed: () => _generateRecipes(forceRefresh: true),
        child: Text(
          'REFRESH MENU',
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
