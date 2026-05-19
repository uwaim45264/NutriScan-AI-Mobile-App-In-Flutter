import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  final String apiKey;
  final String baseUrl = "https://api.groq.com/openai/v1/chat/completions";

  AIService({String? manualKey})
      : apiKey = manualKey ?? 
                 dotenv.env['GROQ_API_KEY'] ?? 
                 dotenv.env['GROK_API_KEY'] ?? 
                 '';


  Future<String> analyzeImage(File image, String prompt, {String? apiKeyOverride}) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final activeKey = apiKeyOverride ?? apiKey;


    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $activeKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "meta-llama/llama-4-scout-17b-16e-instruct",
        "messages": [
          {
            "role": "system",
            "content": "You are a world-class clinical nutritionist and food scientist. Your task is to provide exhaustive, scientifically accurate, and personalized nutritional analysis based on food images. Always respond in valid JSON format. Be extremely detailed."
          },
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/jpeg;base64,$base64Image"
                }
              }
            ]
          }
        ],
        "max_tokens": 4096,
        "temperature": 0.1, 
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ?? 'No result from AI';
    } else {
      throw HttpException('API Error ${response.statusCode}: ${response.body}');
    }
  }


  Future<String> getResponse(String prompt, {String? apiKeyOverride}) async {
    final activeKey = apiKeyOverride ?? apiKey;
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $activeKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {
            "role": "system",
            "content": "You are a world-class clinical nutritionist and food scientist. Provide exhaustive, accurate, and personalized nutritional analysis. Always return valid JSON."
          },
          {"role": "user", "content": prompt}
        ],
        "max_tokens": 4096,
        "temperature": 0.3,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ?? '';
    } else {
      throw HttpException('API Error: ${response.statusCode}');
    }
  }
}
