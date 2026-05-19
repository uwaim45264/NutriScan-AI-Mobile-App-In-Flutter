// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:tflite_v2/tflite_v2.dart';
//
// class TFLiteService {
//   bool _isModelLoaded = false;
//   bool _isLoading = false;
//
//   Future<void> loadModel() async {
//     if (_isModelLoaded || _isLoading) return;
//     _isLoading = true;
//     try {
//       String? res = await Tflite.loadModel(
//         model: "assets/MobileNet-v2.tflite",
//         labels: "assets/labels.txt",
//       );
//       _isModelLoaded = (res != null);
//       debugPrint('TFLite Model loaded: $_isModelLoaded');
//     } catch (e) {
//       debugPrint('Error loading TFLite model: $e');
//       _isModelLoaded = false;
//     } finally {
//       _isLoading = false;
//     }
//   }
//
//   Future<String?> predict(File imageFile) async {
//     try {
//       if (!await imageFile.exists()) return null;
//
//       // Ensure model is loaded before predicting
//       if (!_isModelLoaded && !_isLoading) {
//         await loadModel();
//       }
//
//       // Wait if it's currently loading
//       int retryCount = 0;
//       while (_isLoading && retryCount < 10) {
//         await Future.delayed(const Duration(milliseconds: 500));
//         retryCount++;
//       }
//
//       if (!_isModelLoaded) {
//         debugPrint("TFLite prediction aborted: Model not loaded");
//         return null;
//       }
//
//       var recognitions = await Tflite.runModelOnImage(
//         path: imageFile.path,
//         numResults: 5,
//         threshold: 0.1,
//         imageMean: 127.5,
//         imageStd: 127.5,
//       );
//
//       if (recognitions == null || recognitions.isEmpty) return null;
//
//       String? bestLabel;
//       for (var rec in recognitions) {
//         if (rec is Map) {
//           String label = (rec['label'] ?? "").toString();
//           // Filter out generic background labels
//           if (!label.toLowerCase().contains("non-food") &&
//               !label.toLowerCase().contains("background")) {
//             bestLabel = label;
//             break;
//           }
//         }
//       }
//
//       bestLabel ??= (recognitions[0] as Map?)?['label']?.toString();
//       if (bestLabel == null) return null;
//
//       // Clean the label (remove ImageNet prefixes like 'n012345 ')
//       final RegExp numPrefix = RegExp(r'^\d+\s+');
//       return bestLabel.replaceFirst(numPrefix, '').trim();
//     } catch (e) {
//       debugPrint("TFLite Prediction Error: $e");
//       return null;
//     }
//   }
//
//   void dispose() {
//     try {
//       if (_isModelLoaded) {
//         Tflite.close();
//       }
//     } catch (e) {
//       debugPrint('Error closing TFLite: $e');
//     } finally {
//       _isModelLoaded = false;
//     }
//   }
// }
