import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  String gender;

  @HiveField(3)
  double height; // in cm

  @HiveField(4)
  double weight; // in kg

  @HiveField(5)
  String activityLevel;

  @HiveField(6)
  List<String> healthConditions;

  @HiveField(7)
  List<String> allergies;

  @HiveField(8)
  String dietaryPreference;

  @HiveField(9)
  String goal;

  UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.healthConditions,
    required this.allergies,
    required this.dietaryPreference,
    required this.goal,
  });
}
