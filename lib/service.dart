import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class EmotionService {
  // Your Railway API URL
  static const String apiUrl = 'https://fer-api-production.up.railway.app/predict/image';

  Future<Map<String, dynamic>> detectEmotions(dynamic input) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Handle Image File - Your API expects 'image' as the field name
      if (kIsWeb) {
        if (input is List<int>) {
          request.files.add(http.MultipartFile.fromBytes(
            'image', // Changed from 'file' to 'image'
            input,
            filename: 'upload.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      } else {
        if (input is io.File) {
          request.files.add(await http.MultipartFile.fromPath(
            'image', // Changed from 'file' to 'image'
            input.path,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      print('Sending request to Railway API...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        // Your API returns:
        // {
        //   "class": "sad",
        //   "confidence": 0.59339464,
        //   "predictions": {
        //     "angry": 0.1526471,
        //     "disgusted": -0.14833826,
        //     "fearful": 0.009242615,
        //     "happy": -0.2986916,
        //     "neutral": -0.55322206,
        //     "sad": 0.59339464,
        //     "surprised": -0.24444328
        //   }
        // }

        // Extract the predictions (emotion probabilities)
        var predictions = jsonResponse['predictions'];
        
        if (predictions == null) {
          return {}; // No predictions found
        }

        // Convert the predictions to the format expected by the UI
        // The UI expects emotion names as keys with their confidence values
        Map<String, dynamic> emotions = {};
        
        predictions.forEach((emotion, value) {
          // Convert negative values to 0 and ensure all values are doubles
          double confidence = (value as num).toDouble();
          // Some models return negative values for low confidence
          // We'll keep them as-is since they might be logits
          // If you want only positive values, uncomment the line below:
          // confidence = confidence < 0 ? 0.0 : confidence;
          emotions[emotion] = confidence;
        });

        print('Detected emotion: ${jsonResponse['class']} with confidence: ${jsonResponse['confidence']}');
        print('All emotions: $emotions');

        return emotions;

      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
}