import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../providers/profile_provider.dart';
import '../models/food_analysis.dart';

class ScanFoodScreen extends StatefulWidget {
  const ScanFoodScreen({super.key});

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen> {
  File? _image;
  bool _loading = false;
  bool _isSaved = false;
  Map<String, dynamic>? _structuredResult;
  String? _rawResult;
  int _selectedItemIndex = 0;
  String _selectedLanguage = 'English';
  late VideoPlayerController _videoController;

  final List<String> _languages = [
    'English', 'Spanish', 'French', 'Hindi', 'German', 'Chinese', 'Arabic', 'Russian', 'Portuguese', 'Japanese'
  ];
  
  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/5.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        _videoController.setLooping(true);
        _videoController.setVolume(0);
        _videoController.play();
        setState(() {});
      }).catchError((e) => debugPrint("Video error: $e"));
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source, 
        imageQuality: 50, 
        maxWidth: 1024,   
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _image = File(pickedFile.path);
          _structuredResult = null;
          _rawResult = null;
          _selectedItemIndex = 0;
          _isSaved = false;
        });
        _analyzeImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error selecting image: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;
    
    // Capture profile immediately to avoid post-async context issues
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final profile = profileProvider.profile;
    
    setState(() {
      _loading = true;
      _rawResult = null;
      _structuredResult = null;
    });

    try {
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
        IDENTIFY ALL DISTINCT FOOD ITEMS in this image.
        For EACH item found, provide an EXHAUSTIVE nutritional report.
        Return valid JSON ONLY.
        
        If NO food items are found, return: {"items": []}
        
        IMPORTANT: Provide ALL text descriptions and values (foodName, scientificName, healthRating, reason, personalizedAdvice, bestTime, bestPairedWith, storageTips, usageTips, benefits, warnings, healthierAlternatives, and micronutrient names) EXCLUSIVELY in the $_selectedLanguage language.
        
        USER CONTEXT: $userContext

        JSON Structure:
        {
          "items": [
            {
              "foodName": "...",
              "scientificName": "...",
              "healthScore": 9,
              "healthRating": "...",
              "servingSize": "100g",
              "calories": 52,
              "nutrients": { "protein": "0.3g", "carbs": "14g", "fats": "0.2g", "fiber": "2.4g", "sugar": "10g", "sodium": "1mg" },
              "micronutrients": [ {"name": "Vitamin C", "dv": "14%"}, {"name": "Potassium", "dv": "4%"} ],
              "glycemicIndex": "...",
              "phLevel": "...",
              "antioxidants": "...",
              "satietyIndex": "...",
              "hydration": "...",
              "reason": "Hi [Name]...",
              "personalizedAdvice": "...",
              "warnings": [],
              "benefits": [],
              "bestTime": "...",
              "bestPairedWith": "...",
              "storageTips": "...",
              "usageTips": "...",
              "healthierAlternatives": []
            }
          ]
        }
      """;

      final result = await _aiService.analyzeImage(
        _image!, 
        prompt,
        apiKeyOverride: dotenv.env['SCAN_API_KEY']
      );
      
      if (!mounted) return;
      await _processAIResponse(result);

    } catch (e) {
      debugPrint("Scan primary error: $e");
      if (mounted) {
        setState(() {
          _rawResult = "Analysis failed. Please check your internet connection.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cloud analysis unavailable. Online connection required."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _processAIResponse(String? rawResult, {bool isFromCache = false}) async {
    if (rawResult == null || rawResult.isEmpty) return;
    
    try {
      String jsonStr = rawResult.trim();
      // Improved JSON extraction
      if (jsonStr.contains("{")) {
        int startIndex = jsonStr.indexOf("{");
        int endIndex = jsonStr.lastIndexOf("}");
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          jsonStr = jsonStr.substring(startIndex, endIndex + 1);
        }
      }

      final dynamic decoded = jsonDecode(jsonStr);
      List<Map<String, dynamic>> itemsList = [];

      if (decoded is Map) {
        if (decoded['items'] is List) {
          for (var item in decoded['items']) {
            if (item is Map) itemsList.add(Map<String, dynamic>.from(item));
          }
        } else if (decoded.containsKey('foodName')) {
          itemsList.add(Map<String, dynamic>.from(decoded));
        }
      } else if (decoded is List) {
        for (var item in decoded) {
          if (item is Map) itemsList.add(Map<String, dynamic>.from(item));
        }
      }

      if (itemsList.isEmpty) {
        if (!mounted) return;
        if (!isFromCache) {
          _showNoFoodDialog();
        }
        setState(() {
          _structuredResult = null;
          _rawResult = isFromCache ? "No valid data in cache" : null;
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _structuredResult = {'items': itemsList};
        _selectedItemIndex = 0;
        _rawResult = null;
        _isSaved = isFromCache;
      });

      if (!isFromCache) {
        await _cacheAnalysis(jsonStr, itemsList);
      }

    } catch (e) {
      debugPrint("Error processing AI response: $e");
      if (mounted) {
        setState(() {
          _rawResult = isFromCache ? "Error loading history" : rawResult;
          _structuredResult = null;
        });
      }
    }
  }

  void _showNoFoodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.red.withOpacity(0.2))),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.no_photography_outlined, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("NO FOOD DETECTED", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
        content: const Text(
          "Our AI couldn't identify any clear food items in this image. Please ensure the food is well-lit and clearly visible in the frame.",
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TRY AGAIN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Future<void> _cacheAnalysis(String jsonStr, List<Map<String, dynamic>> items) async {
    if (_image == null) return;
    
    try {
      final box = await Hive.openBox<FoodAnalysis>('food_analysis_box');
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = "scan_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final localImagePath = path.join(appDir.path, fileName);
      
      File localImage;
      try {
        localImage = await _image!.copy(localImagePath);
      } catch (e) {
        localImage = _image!;
      }
      
      String? remoteImageUrl;
      try {
        remoteImageUrl = await _supabaseService.uploadImage(_image!, 'scans');
      } catch (_) {}

      for (var item in items) {
        final String foodName = (item['foodName'] ?? 'Unknown').toString();
        final analysis = FoodAnalysis(
          query: foodName.toLowerCase(), 
          foodName: foodName,
          jsonData: jsonStr, 
          createdAt: DateTime.now(),
          language: _selectedLanguage,
          imagePath: localImage.path,
          imageUrl: remoteImageUrl,
        );
        await box.add(analysis);
        try {
          await _supabaseService.saveFoodAnalysis(analysis);
        } catch (_) {}
      }
      
      if (mounted) setState(() => _isSaved = true);
    } catch (e) {
      debugPrint("Error caching scan: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0, centerTitle: true,
        title: Text('EXPERT NUTRITION SCAN', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
            onSelected: (String lang) {
              setState(() => _selectedLanguage = lang);
              if (_image != null) _analyzeImage();
            },
            itemBuilder: (BuildContext context) => _languages.map((lang) => PopupMenuItem(value: lang, child: Text(lang))).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCard(),
                  const SizedBox(height: 32),
                  if (!_loading && _structuredResult == null && _rawResult == null) _buildWelcome(),
                  if (_loading) _buildLoading(),
                  if (_structuredResult != null) _buildAnalysis(),
                  if (!_loading && _structuredResult == null && _rawResult != null) _buildRawResult(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      height: 300, width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _image != null 
            ? Image.file(_image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white10))) 
            : (_videoController.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : const Center(child: Icon(Icons.center_focus_weak, size: 64, color: Colors.white10))),
      ),
    );
  }

  Widget _buildWelcome() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scan Fresh\nFoods.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1.5)),
        SizedBox(height: 12),
        Text('Identify multiple items and get exhaustive nutritional insights tailored to your profile.', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(
      children: [
        CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
        SizedBox(height: 16),
        Text('Analyzing food items...', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    )));
  }

  Widget _buildAnalysis() {
    if (_structuredResult == null || _structuredResult!['items'] == null) return const SizedBox.shrink();
    final List items = _structuredResult!['items'];
    if (items.isEmpty) return const Center(child: Text("No items identified", style: TextStyle(color: Colors.white)));
    
    final int safeIndex = _selectedItemIndex < items.length ? _selectedItemIndex : 0;
    final dynamic item = items[safeIndex];
    if (item is! Map) return const SizedBox.shrink();
    
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
        _buildDetailSection('Why it matters', item['reason'], Icons.lightbulb_outline),
        _buildDetailSection('Personalized Advice', item['personalizedAdvice'], Icons.star_border),
        _buildListSection('Micronutrients', item['micronutrients'], Icons.science_outlined, Colors.blue),
        _buildListSection('Health Benefits', item['benefits'], Icons.check_circle_outline, Colors.green),
        _buildListSection('Cautions', item['warnings'], Icons.warning_amber_rounded, Colors.orange),
        _buildListSection('Healthier Alternatives', item['healthierAlternatives'], Icons.swap_horiz_rounded, Colors.teal),
        _buildDetailSection('Best Time to Eat', item['bestTime'], Icons.access_time),
        _buildDetailSection('Best Paired With', item['bestPairedWith'], Icons.restaurant_menu),
        _buildDetailSection('Storage Tips', item['storageTips'], Icons.inventory_2_outlined),
        _buildDetailSection('Usage Tips', item['usageTips'], Icons.tips_and_updates_outlined),
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
            child: Text((items[index]['foodName'] ?? 'Item').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(Map item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item['foodName']?.toString().toUpperCase() ?? 'IDENTIFIED FOOD', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                if (_isSaved) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.history_rounded, color: Colors.orange, size: 12),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text((item['scientificName'] ?? '').toString(), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 2),
            Text((item['healthRating'] ?? '').toString(), style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildNutrientGrid(Map item) {
    final dynamic nutrients = item['nutrients'];
    final Map n = (nutrients is Map) ? nutrients : {};
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5,
      children: [
        _buildNutrientTile('Calories', '${item['calories'] ?? 0} kcal'),
        _buildNutrientTile('Protein', (n['protein'] ?? '0g').toString()),
        _buildNutrientTile('Carbs', (n['carbs'] ?? '0g').toString()),
        _buildNutrientTile('Fats', (n['fats'] ?? '0g').toString()),
      ],
    );
  }

  Widget _buildSecondaryNutrients(Map item) {
    final dynamic nutrients = item['nutrients'];
    final Map n = (nutrients is Map) ? nutrients : {};
    return Row(
      children: [
        Expanded(child: _buildSmallNutrientTile('Fiber', (n['fiber'] ?? '0g').toString())),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallNutrientTile('Sugar', (n['sugar'] ?? '0g').toString())),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallNutrientTile('Sodium', (n['sodium'] ?? '0mg').toString())),
      ],
    );
  }

  Widget _buildTechnicalGrid(Map item) {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.5,
      children: [
        _buildSmallNutrientTile('GI', (item['glycemicIndex'] ?? 'N/A').toString()),
        _buildSmallNutrientTile('pH', (item['phLevel'] ?? 'N/A').toString()),
        _buildSmallNutrientTile('Hydration', (item['hydration'] ?? 'N/A').toString()),
        _buildSmallNutrientTile('Antioxidants', (item['antioxidants'] ?? 'N/A').toString()),
        _buildSmallNutrientTile('Satiety', (item['satietyIndex'] ?? 'N/A').toString()),
        _buildSmallNutrientTile('Serving', (item['servingSize'] ?? '100g').toString()),
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

  Widget _buildDetailSection(String title, dynamic content, IconData icon) {
    final String str = (content ?? "").toString();
    if (str.isEmpty || str == "...") return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: Colors.red, size: 16), const SizedBox(width: 8), Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))]),
      const SizedBox(height: 12),
      Text(str, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6)),
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

  Widget _buildBottomActions() {
    return Container(padding: const EdgeInsets.fromLTRB(24, 0, 24, 40), child: Row(children: [
      Expanded(child: _buildActionButton('GALLERY', Icons.image_outlined, () => _pickImage(ImageSource.gallery), false)),
      const SizedBox(width: 16),
      Expanded(child: _buildActionButton('CAMERA', Icons.camera_alt_rounded, () => _pickImage(ImageSource.camera), true)),
    ]));
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap, bool primary) {
    return GestureDetector(onTap: onTap, child: Container(
      height: 56, decoration: BoxDecoration(color: primary ? Colors.red : const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
      ]),
    ));
  }
}
