import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/profile_provider.dart';

class BMICalculatorScreen extends StatefulWidget {
  const BMICalculatorScreen({super.key});

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

enum UnitSystem { metric, imperial }

class _BMICalculatorScreenState extends State<BMICalculatorScreen> with SingleTickerProviderStateMixin {
  UnitSystem _unitSystem = UnitSystem.metric;
  String _gender = 'MALE';
  double _heightCm = 170;
  double _weightKg = 70;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<ProfileProvider>(context, listen: false).profile;
    if (profile != null) {
      _heightCm = profile.height;
      _weightKg = profile.weight;
      _gender = profile.gender.toUpperCase();
    }
  }

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));

  @override
  Widget build(BuildContext context) {
    final status = _getBMIStatus();
    final profileName = Provider.of<ProfileProvider>(context).profile?.name ?? "friend";

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
          'BODY INSIGHTS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
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
            _buildHeader(profileName),
            const SizedBox(height: 32),
            _buildGenderToggle(),
            const SizedBox(height: 16),
            _buildUnitSelector(),
            const SizedBox(height: 40),
            
            // Visualizer Section
            Center(
              child: _BodyVisualizer(
                bmi: _bmi,
                gender: _gender,
                color: status.color,
              ),
            ),
            
            const SizedBox(height: 40),
            _buildBMIResult(status),
            const SizedBox(height: 48),
            _buildSectionTag('ADJUST METRICS'),
            const SizedBox(height: 32),
            _buildSliderInput(
              label: 'Height',
              value: _unitSystem == UnitSystem.metric ? _heightCm : _cmToInches(_heightCm),
              display: _unitSystem == UnitSystem.metric ? '${_heightCm.toInt()} cm' : _cmToFeetInches(_heightCm),
              min: _unitSystem == UnitSystem.metric ? 100 : 40,
              max: _unitSystem == UnitSystem.metric ? 250 : 100,
              onChanged: (v) => setState(() => _heightCm = _unitSystem == UnitSystem.metric ? v : _inchesToCm(v)),
            ),
            const SizedBox(height: 32),
            _buildSliderInput(
              label: 'Weight',
              value: _unitSystem == UnitSystem.metric ? _weightKg : _kgToLbs(_weightKg),
              display: _unitSystem == UnitSystem.metric ? '${_weightKg.toInt()} kg' : '${(_kgToLbs(_weightKg)).toInt()} lbs',
              min: _unitSystem == UnitSystem.metric ? 30 : 65,
              max: _unitSystem == UnitSystem.metric ? 200 : 450,
              onChanged: (v) => setState(() => _weightKg = _unitSystem == UnitSystem.metric ? v : _lbsToKg(v)),
            ),
            const SizedBox(height: 48),
            _buildReferenceSection(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderToggle() {
    return Row(
      children: [
        _genderBtn('MALE', Icons.male_rounded),
        const SizedBox(width: 12),
        _genderBtn('FEMALE', Icons.female_rounded),
      ],
    );
  }

  Widget _genderBtn(String label, IconData icon) {
    final active = _gender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 44,
          decoration: BoxDecoration(
            color: active ? Colors.red : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : Colors.white.withOpacity(0.3)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: active ? Colors.white : Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cmToFeetInches(double cm) {
    double totalInches = cm / 2.54;
    int feet = (totalInches / 12).floor();
    int inches = (totalInches % 12).round();
    if (inches == 12) { feet++; inches = 0; }
    return "$feet'$inches\"";
  }
  double _lbsToKg(double lbs) => lbs / 2.20462;
  double _kgToLbs(double kg) => kg * 2.20462;
  double _inchesToCm(double inches) => inches * 2.54;
  double _cmToInches(double cm) => cm / 2.54;

  Widget _buildHeader(String name) {
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
          'Balance your\nwell-being.',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Understanding your composition helps you move toward your natural rhythm.',
          style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSectionTag(String title) {
    return Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.red));
  }

  Widget _buildUnitSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _unitBtn('METRIC', UnitSystem.metric),
          _unitBtn('IMPERIAL', UnitSystem.imperial),
        ],
      ),
    );
  }

  Widget _unitBtn(String label, UnitSystem system) {
    final active = _unitSystem == system;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _unitSystem = system),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(color: active ? Colors.red : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: active ? Colors.white : Colors.white.withOpacity(0.3)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBMIResult(_BMIStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _bmi.toStringAsFixed(1),
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: -4, height: 0.9, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'current index',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: status.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(
            status.label.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: status.color),
          ),
        ),
        const SizedBox(height: 16),
        Text(status.description, style: TextStyle(fontSize: 15, color: Colors.grey[400], height: 1.5)),
      ],
    );
  }

  Widget _buildSliderInput({
    required String label,
    required double value,
    required String display,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            Text(display, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.red,
            inactiveTrackColor: const Color(0xFF1C1C1E),
            thumbColor: Colors.red,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildReferenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTag('RANGES'),
        const SizedBox(height: 24),
        _rangeRow('Underweight', '< 18.5', Colors.orange.shade300),
        _rangeRow('Healthy', '18.5 – 24.9', Colors.green.shade400),
        _rangeRow('Overweight', '25.0 – 29.9', Colors.orange.shade400),
        _rangeRow('Above Range', '30.0+', Colors.red.shade400),
      ],
    );
  }

  Widget _rangeRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3))),
        ],
      ),
    );
  }

  _BMIStatus _getBMIStatus() {
    if (_bmi < 18.5) return _BMIStatus('Light', Colors.orange.shade300, 'Your body might need more nourishment to reach its full potential.');
    if (_bmi < 25) return _BMIStatus('Healthy', Colors.green.shade400, 'You’re in a great place. Keep listening to your body\'s needs.');
    if (_bmi < 30) return _BMIStatus('Substantial', Colors.orange.shade400, 'Focus on steady, sustainable habits to find your natural balance.');
    return _BMIStatus('High', Colors.red.shade400, 'Small, mindful changes can make a big difference in how you feel every day.');
  }
}

class _BodyVisualizer extends StatelessWidget {
  final double bmi;
  final String gender;
  final Color color;

  const _BodyVisualizer({required this.bmi, required this.gender, required this.color});

  @override
  Widget build(BuildContext context) {
    double scale = (bmi - 15).clamp(0, 25) / 25.0;
    
    return SizedBox(
      height: 240,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 120 + (scale * 60),
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          
          TweenAnimationBuilder<double>(
            key: ValueKey(gender),
            tween: Tween(begin: 0.8, end: 1.0 + (scale * 0.4)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, widthScale, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(0.1),
                child: CustomPaint(
                  size: Size(80 * widthScale, 200),
                  painter: _BodyPainter(
                    color: color,
                    gender: gender,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final Color color;
  final String gender;

  _BodyPainter({required this.color, required this.gender});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    double w = size.width;
    double h = size.height;

    if (gender == 'MALE') {
      path.addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.15), width: w * 0.3, height: h * 0.15));
      path.moveTo(w * 0.3, h * 0.25);
      path.quadraticBezierTo(w * 0.5, h * 0.22, w * 0.7, h * 0.25);
      path.lineTo(w * 0.75, h * 0.5);
      path.lineTo(w * 0.25, h * 0.5);
      path.close();
      canvas.drawRRect(RRect.fromLTRBR(w * 0.3, h * 0.52, w * 0.45, h * 0.95, const Radius.circular(10)), paint);
      canvas.drawRRect(RRect.fromLTRBR(w * 0.55, h * 0.52, w * 0.7, h * 0.95, const Radius.circular(10)), paint);
    } else {
      path.addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.15), width: w * 0.28, height: h * 0.14));
      path.moveTo(w * 0.35, h * 0.25);
      path.quadraticBezierTo(w * 0.5, h * 0.23, w * 0.65, h * 0.25);
      path.quadraticBezierTo(w * 0.8, h * 0.45, w * 0.6, h * 0.55);
      path.lineTo(w * 0.4, h * 0.55);
      path.quadraticBezierTo(w * 0.2, h * 0.45, w * 0.35, h * 0.25);
      path.close();
      canvas.drawRRect(RRect.fromLTRBR(w * 0.32, h * 0.57, w * 0.48, h * 0.95, const Radius.circular(15)), paint);
      canvas.drawRRect(RRect.fromLTRBR(w * 0.52, h * 0.57, w * 0.68, h * 0.95, const Radius.circular(15)), paint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) => 
      oldDelegate.color != color || oldDelegate.gender != gender;
}

class _BMIStatus {
  final String label;
  final Color color;
  final String description;
  _BMIStatus(this.label, this.color, this.description);
}
