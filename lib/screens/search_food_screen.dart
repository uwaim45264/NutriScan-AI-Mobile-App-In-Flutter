import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../providers/profile_provider.dart';
import '../models/food_analysis.dart';

class SearchFoodScreen extends StatefulWidget {
  const SearchFoodScreen({super.key});

  @override
  State<SearchFoodScreen> createState() => _SearchFoodScreenState();
}

class _SearchFoodScreenState extends State<SearchFoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _structuredResult;
  String? _rawResult;
  int _selectedItemIndex = 0;
  String _selectedLanguage = 'English';

  final List<String> _languages = [
    'English', 'Spanish', 'French', 'Hindi', 'German', 'Chinese', 'Arabic', 'Russian', 'Portuguese', 'Japanese'
  ];
  
  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return;
    
    setState(() {
      _loading = true;
      _structuredResult = null;
      _rawResult = null;
      _selectedItemIndex = 0;
    });

    try {
      // 1. Check Local Cache (Hive)
      final box = await Hive.openBox<FoodAnalysis>('food_analysis_box');
      final cachedLocal = box.values.cast<FoodAnalysis?>().firstWhere(
        (e) => e != null && e.query == cleanQuery && e.language == _selectedLanguage,
        orElse: () => null,
      );

      if (cachedLocal != null) {
        if (mounted) {
          _setResultFromJson(cachedLocal.jsonData);
          setState(() => _loading = false);
        }
        return;
      }

      // Check online cache
      try {
        final cachedCloud = await _supabaseService.getFoodAnalysis(cleanQuery, _selectedLanguage);
        if (cachedCloud != null) {
          if (mounted) {
            _setResultFromJson(cachedCloud.jsonData);
            await box.add(cachedCloud); // Save to local
            setState(() => _loading = false);
          }
          return;
        }
      } catch (e) {
        debugPrint("Cloud cache check failed: $e");
      }

      final profile = Provider.of<ProfileProvider>(context, listen: false).profile;
      String userContext = profile == null
          ? "Guest Mode: Provide general health analysis based on a standard 2000kcal diet."
          : """
            User Profile: 
            - Name: ${profile.name ?? 'User'}
            - Physicals: ${profile.age ?? 'N/A'}yo ${profile.gender ?? ''}, ${profile.height ?? 'N/A'}cm, ${profile.weight ?? 'N/A'}kg
            - Activity: ${profile.activityLevel ?? 'Moderate'}
            - Goal: ${profile.goal ?? 'General Health'}
            - Medical Conditions: ${(profile.healthConditions?.isEmpty ?? true) ? 'None' : profile.healthConditions?.join(', ')}
            - Allergies: ${(profile.allergies?.isEmpty ?? true) ? 'None' : profile.allergies?.join(', ')}
            - Diet Style: ${profile.dietaryPreference ?? 'General'}
            """;

      final prompt = """
        Analyze the food item: "$query".
        Provide an exhaustive nutritional and health report strictly tailored to the user profile provided.
        
        CRITICAL: Provide ALL text values in the JSON response in $_selectedLanguage language. 
        The structure keys must remain in English as defined below, but all string values must be translated to $_selectedLanguage.

        USER CONTEXT:
        $userContext

        STRICT INSTRUCTIONS:
        1. JSON response ONLY. No preamble.
        2. Calculate 'healthScore' (1-10) specifically for this user's profile and goals.
        3. 'reason' MUST start with "Hi ${profile?.name ?? 'there'}" (translated to $_selectedLanguage).
        4. Provide EXTREME detail including:
           - Macros: Protein, Carbs, Fats, Fiber, Sugar, Sodium.
           - Micronutrients: List 5-8 vitamins/minerals with % Daily Value (DV).
           - Technical: Glycemic Index (GI), pH Level, Satiety Index, Antioxidant level, Hydration %.
        5. Provide EXPLICIT 'warnings' if the food contains allergens for the user or conflicts with their medical conditions.
        6. Provide 'personalizedAdvice' regarding their goal: ${profile?.goal ?? 'Health'}.
        7. Suggest 'healthierAlternatives' and 'bestPairedWith' foods.
        8. Include 'storageTips', 'usageTips', and 'bestTime' to eat.

        JSON Structure (Translate all string values to $_selectedLanguage):
        {
          "items": [
            {
              "foodName": "$query",
              "scientificName": "...",
              "healthScore": 9,
              "healthRating": "...",
              "servingSize": "100g",
              "calories": 52,
              "nutrients": {
                "protein": "0.3g", "carbs": "14g", "fats": "0.2g", "fiber": "2.4g", "sugar": "10g", "sodium": "1mg"
              },
              "micronutrients": [
                {"name": "Vitamin C", "dv": "14%"},
                {"name": "Potassium", "dv": "4%"}
              ],
              "glycemicIndex": "...",
              "phLevel": "...",
              "antioxidants": "...",
              "satietyIndex": "...",
              "hydration": "...",
              "recommendation": "...",
              "reason": "Hi [Name]...",
              "personalizedAdvice": "...",
              "warnings": [],
              "benefits": [],
              "bestTime": "...",
              "storageTips": "...",
              "usageTips": "...",
              "bestPairedWith": "...",
              "healthierAlternatives": []
            }
          ]
        }
      """;

      final result = await _aiService.getResponse(prompt, apiKeyOverride: dotenv.env['SEARCH_API_KEY']);
      
      if (!mounted) return;

      String jsonStr = _extractJson(result);
      _setResultFromJson(jsonStr);

      if (_structuredResult != null && _structuredResult!['items'] != null && _structuredResult!['items'].isNotEmpty) {
        final analysis = FoodAnalysis(
          query: cleanQuery,
          foodName: _structuredResult!['items'][0]['foodName'] ?? query,
          jsonData: jsonStr,
          createdAt: DateTime.now(),
          language: _selectedLanguage,
        );
        await box.add(analysis);
        try {
          await _supabaseService.saveFoodAnalysis(analysis);
        } catch (e) {
          debugPrint("Cloud save failed: $e");
        }
      }

    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _rawResult = "Search failed. Please check your connection.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractJson(String input) {
    String jsonStr = input.trim();
    if (jsonStr.contains("```")) {
      final RegExp codeBlock = RegExp(r"```(?:json)?\s*([\s\S]*?)\s*```");
      final matches = codeBlock.allMatches(jsonStr);
      if (matches.isNotEmpty) {
        jsonStr = matches.first.group(1)!;
      } else {
        // Fallback: search for first { and last }
        int start = jsonStr.indexOf('{');
        int end = jsonStr.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          jsonStr = jsonStr.substring(start, end + 1);
        }
      }
    }
    return jsonStr;
  }

  void _setResultFromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr.trim());
      setState(() {
        if (decoded is Map<String, dynamic>) {
          String? itemsKey = decoded.keys.firstWhere(
            (k) => k.toLowerCase() == 'items', 
            orElse: () => '',
          );
          if (itemsKey.isNotEmpty && decoded[itemsKey] is List) {
            _structuredResult = {'items': decoded[itemsKey]};
          } else if (decoded.containsKey('foodName') || decoded.containsKey('food_name')) {
            _structuredResult = {'items': [decoded]};
          } else {
            _rawResult = jsonStr;
          }
        } else if (decoded is List) {
          _structuredResult = {'items': decoded};
        } else {
          _rawResult = jsonStr;
        }
        _selectedItemIndex = 0;
      });
    } catch (e) {
      debugPrint("JSON Parse Error: $e");
      setState(() {
        _rawResult = jsonStr;
        _structuredResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0, centerTitle: true,
        title: Text('EXPERT SEARCH SCAN', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
            onSelected: (String lang) {
              setState(() => _selectedLanguage = lang);
              if (_searchController.text.isNotEmpty) _performSearch(_searchController.text);
            },
            itemBuilder: (context) => _languages.map((l) => PopupMenuItem(value: l, child: Text(l))).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for any food...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search, color: Colors.red, size: 20),
                filled: true, fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white), onPressed: () => _performSearch(_searchController.text)),
              ),
              onSubmitted: _performSearch,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))),
                  if (_structuredResult != null) _buildAnalysis(),
                  if (!_loading && _structuredResult == null && _rawResult != null) _buildRawResult(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysis() {
    if (_structuredResult == null || _structuredResult!['items'] == null) return const SizedBox.shrink();
    final items = _structuredResult!['items'] as List;
    if (items.isEmpty) return const Center(child: Text("No items found", style: TextStyle(color: Colors.white)));
    
    final item = items[_selectedItemIndex < items.length ? _selectedItemIndex : 0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.length > 1) _buildItemSelector(items),
        _buildResultHeader(item),
        const SizedBox(height: 24),
        _buildNutrientGrid(item),
        const SizedBox(height: 12),
        _buildSecondaryNutrients(item),
        const SizedBox(height: 24),
        _buildTechnicalGrid(item),
        const SizedBox(height: 32),
        _buildDetailSection('Why it matters', item['reason'] ?? '', Icons.lightbulb_outline),
        _buildDetailSection('Personalized Advice', item['personalizedAdvice'] ?? '', Icons.star_border),
        _buildListSection('Micronutrients', item['micronutrients'], Icons.science_outlined, Colors.blue),
        _buildListSection('Health Benefits', item['benefits'], Icons.check_circle_outline, Colors.green),
        _buildListSection('Cautions', item['warnings'], Icons.warning_amber_rounded, Colors.orange),
        _buildListSection('Healthier Alternatives', item['healthierAlternatives'], Icons.swap_horiz_rounded, Colors.teal),
        _buildDetailSection('Best Time to Eat', item['bestTime'] ?? '', Icons.access_time),
        _buildDetailSection('Best Paired With', item['bestPairedWith'] ?? '', Icons.restaurant_menu),
        _buildDetailSection('Storage Tips', item['storageTips'] ?? '', Icons.inventory_2_outlined),
        _buildDetailSection('Usage Tips', item['usageTips'] ?? '', Icons.tips_and_updates_outlined),
      ],
    );
  }

  Widget _buildItemSelector(List items) {
    return Container(
      height: 40, margin: const EdgeInsets.only(bottom: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: items.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => setState(() => _selectedItemIndex = index),
          child: Container(
            margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: _selectedItemIndex == index ? Colors.red : const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.center,
            child: Text(items[index]['foodName'] ?? 'Item', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(dynamic item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['foodName']?.toUpperCase() ?? 'FOOD', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text(item['scientificName'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 2),
            Text(item['healthRating'] ?? '', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
          child: Column(children: [
            Text('${item['healthScore'] ?? 0}', style: const TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('SCORE', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  Widget _buildNutrientGrid(dynamic item) {
    final nutrients = item['nutrients'] ?? {};
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5,
      children: [
        _buildNutrientTile('Calories', '${item['calories'] ?? 0} kcal'),
        _buildNutrientTile('Protein', nutrients['protein'] ?? '0g'),
        _buildNutrientTile('Carbs', nutrients['carbs'] ?? '0g'),
        _buildNutrientTile('Fats', nutrients['fats'] ?? '0g'),
      ],
    );
  }

  Widget _buildSecondaryNutrients(dynamic item) {
    final nutrients = item['nutrients'] ?? {};
    return Row(
      children: [
        Expanded(child: _buildSmallNutrientTile('Fiber', nutrients['fiber'] ?? '0g')),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallNutrientTile('Sugar', nutrients['sugar'] ?? '0g')),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallNutrientTile('Sodium', nutrients['sodium'] ?? '0mg')),
      ],
    );
  }

  Widget _buildTechnicalGrid(dynamic item) {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.5,
      children: [
        _buildSmallNutrientTile('GI', item['glycemicIndex'] ?? 'N/A'),
        _buildSmallNutrientTile('pH', item['phLevel'] ?? 'N/A'),
        _buildSmallNutrientTile('Hydration', item['hydration'] ?? 'N/A'),
        _buildSmallNutrientTile('Antioxidants', item['antioxidants'] ?? 'N/A'),
        _buildSmallNutrientTile('Satiety', item['satietyIndex'] ?? 'N/A'),
        _buildSmallNutrientTile('Serving', item['servingSize'] ?? '100g'),
      ],
    );
  }

  Widget _buildNutrientTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildSmallNutrientTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E).withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    if (content.isEmpty || content == "...") return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: Colors.red, size: 16), const SizedBox(width: 8), Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))]),
      const SizedBox(height: 12),
      Text(content, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6)),
    ]));
  }

  Widget _buildListSection(String title, dynamic list, IconData icon, Color color) {
    if (list == null || list is! List || list.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))]),
      const SizedBox(height: 12),
      ...list.map((e) {
        String text = "";
        if (e is Map) {
          text = "${e['name'] ?? ''} (${e['dv'] ?? ''})";
        } else {
          text = e.toString();
        }
        if (text.trim().isEmpty) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14))),
        ]));
      }).toList(),
    ]));
  }

  Widget _buildRawResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: Text(_rawResult ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
    );
  }
}
