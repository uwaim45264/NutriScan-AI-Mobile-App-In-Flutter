import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  final TextEditingController _customOptionController = TextEditingController();

  List<String> _selectedActivityLevels = [];
  List<String> _selectedPreferences = [];
  List<String> _selectedGoals = [];
  List<String> _selectedConditions = [];
  List<String> _selectedAllergies = [];

  final List<String> _activityLevels = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'];
  final List<String> _conditions = [
    'Diabetes (Type 1)', 'Diabetes (Type 2)', 'Prediabetes', 'Diarrhea', 'Gestational Diabetes',
    'Hypertension', 'Hypotension', 'High Cholesterol', 'Heart Disease', 'Arrhythmia',
    'Congestive Heart Failure', 'Stroke History', 'PCOS', 'Endometriosis', 'Menopause',
    'Thyroid Issues (Hypothyroidism)', 'Thyroid Issues (Hyperthyroidism)', 'Hashimoto’s',
    'Graves’ Disease', 'IBS', 'IBD', 'Crohn’s Disease', 'Ulcerative Colitis',
    'GERD / Acid Reflux', 'Celiac Disease', 'Lactose Intolerance', 'Fructose Malabsorption',
    'None'
  ];
  final List<String> _allergies = [
    'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 'Wheat', 'Soy', 'Shellfish',
    'Fish', 'Sesame', 'Mustard', 'Sulfites', 'Corn', 'Nightshades', 'Latex',
    'Avocado', 'Banana', 'Kiwi', 'Chestnut', 'Celery', 'Lupin', 'Molluscs'
  ];
  final List<String> _preferences = [
    'Vegan', 'Vegetarian', 'Pescatarian', 'Flexitarian', 'Keto', 'Low-Carb',
    'High-Protein', 'Paleo', 'Whole30', 'Mediterranean', 'DASH', 'MIND',
    'Gluten-Free', 'Dairy-Free', 'Lactose-Free', 'Egg-Free', 'Nut-Free',
    'Halal', 'Kosher', 'Jain', 'Low-FODMAP', 'Intermittent Fasting',
    'Carb Cycling', 'Plant-Based', 'Raw Food', 'Ayurvedic', 'Macrobiotic'
  ];
  final List<String> _goals = [
    'Lose Weight', 'Maintain Weight', 'Gain Muscle', 'Improve Endurance',
    'Manage Blood Sugar', 'Lower Blood Pressure', 'Lower Cholesterol',
    'Boost Energy', 'Improve Gut Health', 'Enhance Sleep', 'Build Immunity',
    'Reduce Inflammation', 'Support Pregnancy', 'Postpartum Recovery',
    'General Health & Wellness', 'Athletic Peak Performance', 'Longevity / Anti-Aging'
  ];

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<ProfileProvider>(context, listen: false).profile;
    _nameController = TextEditingController(text: profile?.name ?? '');

    if (profile != null) {
      _selectedActivityLevels = profile.activityLevel.split(', ').where((e) => e.isNotEmpty).toList();
      _selectedPreferences = profile.dietaryPreference.split(', ').where((e) => e.isNotEmpty).toList();
      _selectedGoals = profile.goal.split(', ').where((e) => e.isNotEmpty).toList();
      _selectedConditions = List.from(profile.healthConditions);
      _selectedAllergies = List.from(profile.allergies);

      _syncOptions(_selectedActivityLevels, _activityLevels);
      _syncOptions(_selectedPreferences, _preferences);
      _syncOptions(_selectedGoals, _goals);
      _syncOptions(_selectedConditions, _conditions);
      _syncOptions(_selectedAllergies, _allergies);
    }
  }

  void _syncOptions(List<String> selected, List<String> options) {
    for (var item in selected) {
      if (!options.contains(item)) {
        options.add(item);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customOptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final existingProfile = Provider.of<ProfileProvider>(context, listen: false).profile;

      final profile = UserProfile(
        name: _nameController.text,
        age: existingProfile?.age ?? 25,
        gender: existingProfile?.gender ?? 'Other',
        height: existingProfile?.height ?? 170.0,
        weight: existingProfile?.weight ?? 70.0,
        activityLevel: _selectedActivityLevels.join(', '),
        healthConditions: _selectedConditions,
        allergies: _selectedAllergies,
        dietaryPreference: _selectedPreferences.join(', '),
        goal: _selectedGoals.join(', '),
      );

      await Provider.of<ProfileProvider>(context, listen: false).saveProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your settings have been saved.', style: TextStyle(fontSize: 12, color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Profile?', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        content: const Text('This will permanently remove your data from the database.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              await Provider.of<ProfileProvider>(context, listen: false).deleteProfile();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = Provider.of<ProfileProvider>(context).hasProfile;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              );
            }
          },
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'YOUR PROFILE',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        actions: [
          if (hasProfile)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _confirmDelete,
              tooltip: 'Delete Profile',
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 48),

                    _buildSectionTag('IDENTITY'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nameController,
                      label: 'How should we address you?',
                      hint: 'Your name',
                      validator: (v) => v!.isEmpty ? 'Please let us know your name' : null,
                    ),
                    const SizedBox(height: 32),

                    _buildSectionTag('YOUR RHYTHM'),
                    const SizedBox(height: 16),
                    _buildMultiSelectField(
                      label: 'How do you move during the day?',
                      selectedItems: _selectedActivityLevels,
                      options: _activityLevels,
                      onChanged: (items) => setState(() => _selectedActivityLevels = items),
                    ),
                    const SizedBox(height: 16),
                    _buildMultiSelectField(
                      label: 'Any dietary paths you follow?',
                      selectedItems: _selectedPreferences,
                      options: _preferences,
                      onChanged: (items) => setState(() => _selectedPreferences = items),
                    ),
                    const SizedBox(height: 16),
                    _buildMultiSelectField(
                      label: 'What is your main focus right now?',
                      selectedItems: _selectedGoals,
                      options: _goals,
                      onChanged: (items) => setState(() => _selectedGoals = items),
                    ),
                    const SizedBox(height: 32),

                    _buildSectionTag('SENSITIVITIES'),
                    const SizedBox(height: 16),
                    _buildMultiSelectField(
                      label: 'Any health considerations to keep in mind?',
                      selectedItems: _selectedConditions,
                      options: _conditions,
                      onChanged: (items) => setState(() => _selectedConditions = items),
                    ),
                    const SizedBox(height: 16),
                    _buildMultiSelectField(
                      label: 'Any food sensitivities or allergies?',
                      selectedItems: _selectedAllergies,
                      options: _allergies,
                      onChanged: (items) => setState(() => _selectedAllergies = items),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(32, 10, 32, 40),
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: _buildSaveButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell us about\nyourself.',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'This helps us understand your needs and provide a more personal experience.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<String> selectedItems,
    required List<String> options,
    required void Function(List<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showMultiSelectBottomSheet(context, label, selectedItems, options, onChanged),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
            child: Text(
              selectedItems.isEmpty ? 'None selected' : selectedItems.join(', '),
              style: TextStyle(color: selectedItems.isEmpty ? Colors.white24 : Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  void _showMultiSelectBottomSheet(
    BuildContext context,
    String title,
    List<String> selectedItems,
    List<String> options,
    void Function(List<String>) onChanged,
  ) {
    _customOptionController.clear();
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredOptions = options
                .where((option) => option.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 16),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search options...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white24),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => setModalState(() => searchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customOptionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Add custom...',
                              hintStyle: TextStyle(color: Colors.white24),
                              isDense: true,
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.red),
                          onPressed: () {
                            final val = _customOptionController.text.trim();
                            if (val.isNotEmpty && !options.contains(val)) {
                              setModalState(() {
                                options.insert(0, val);
                                selectedItems.add(val);
                                _customOptionController.clear();
                              });
                              onChanged(List.from(selectedItems));
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredOptions.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No matches found', style: TextStyle(color: Colors.white24))))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredOptions.length,
                            itemBuilder: (context, index) {
                              final option = filteredOptions[index];
                              final isSelected = selectedItems.contains(option);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(option, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) const Icon(Icons.check, color: Colors.red, size: 18),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      onPressed: () {
                                        setModalState(() {
                                          options.remove(option);
                                          selectedItems.remove(option);
                                        });
                                        onChanged(List.from(selectedItems));
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setModalState(() {
                                    isSelected ? selectedItems.remove(option) : selectedItems.add(option);
                                  });
                                  onChanged(List.from(selectedItems));
                                },
                              );
                            },
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _submit,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: const Text('SAVE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    );
  }
}
