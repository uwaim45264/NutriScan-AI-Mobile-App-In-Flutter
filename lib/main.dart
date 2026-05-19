import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_profile.dart';
import 'models/recipe.dart';
import 'models/meal_plan.dart';
import 'models/food_analysis.dart';
import 'providers/profile_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Registering the generated adapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RecipeAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(MealPlanAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(MealAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(FoodAnalysisAdapter());
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. AI features will require a valid API key.");
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final profileProvider = ProfileProvider();
  await profileProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileProvider),
      ],
      child: const NutriScanApp(),
    ),
  );
}

class NutriScanApp extends StatelessWidget {
  const NutriScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriScan AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
