import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'THE KITCHEN',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildRecipeHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(),
            const SizedBox(height: 48),
            _buildSectionTag('A LITTLE STORY'),
            const SizedBox(height: 16),
            Text(
              recipe.description,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            _buildSectionTag('GOOD FOR YOU'),
            const SizedBox(height: 20),
            _buildBenefitsList(),
            const SizedBox(height: 40),
            _buildSectionTag('WHAT YOU NEED'),
            const SizedBox(height: 16),
            _buildIngredientsList(),
            const SizedBox(height: 40),
            _buildSectionTag('THE METHOD'),
            const SizedBox(height: 20),
            _buildCookingSteps(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTag(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        color: Colors.red,
      ),
    );
  }

  Widget _buildRecipeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            recipe.healthTag.toUpperCase(),
            style: const TextStyle(
              color: Colors.red,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          recipe.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem('ENERGY', '${recipe.calories} kcal'),
        _buildStatItem('PREP', '${recipe.ingredients.length} items'),
        _buildStatItem('TIME', '25 min'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsList() {
    return Column(
      children: recipe.benefits.map((benefit) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  benefit,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngredientsList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recipe.ingredients.map((ingredient) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            ingredient,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCookingSteps() {
    return Column(
      children: recipe.steps.asMap().entries.map((entry) {
        final stepNum = entry.key + 1;
        final stepText = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepNum.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  stepText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
