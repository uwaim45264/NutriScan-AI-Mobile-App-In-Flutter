import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class ProfileProvider with ChangeNotifier {
  static const String _boxName = 'user_profile_box';
  UserProfile? _profile;
  final _supabaseService = SupabaseService();

  UserProfile? get profile => _profile;

  Future<void> init() async {
    final box = await Hive.openBox<UserProfile>(_boxName);
    if (box.isNotEmpty) {
      _profile = box.getAt(0);
    }
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    // 1. Save Locally (Hive) - Immediate
    final box = await Hive.openBox<UserProfile>(_boxName);
    if (box.isEmpty) {
      await box.add(profile);
    } else {
      await box.putAt(0, profile);
    }
    _profile = profile;
    notifyListeners();

    // 2. Save to Supabase (Cloud) - Async
    try {
      await _supabaseService.saveProfile(profile);
    } catch (e) {
      debugPrint("Supabase sync failed: $e (Data is safe in Hive)");
    }
  }

  Future<void> deleteProfile() async {
    final nameToDelete = _profile?.name;
    
    // 1. Clear Locally
    final box = await Hive.openBox<UserProfile>(_boxName);
    await box.clear();
    _profile = null;
    notifyListeners();
    
    // 2. Clear from Cloud
    if (nameToDelete != null) {
      try {
        // You can add a delete method to SupabaseService if needed
        // await _supabaseService.deleteProfile(nameToDelete);
      } catch (e) {
        debugPrint("Cloud deletion failed: $e");
      }
    }
  }

  bool get hasProfile => _profile != null;
}
