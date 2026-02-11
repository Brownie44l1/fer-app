import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class EmotionService {
  // Your Render API URL
  static const String apiUrl = 'https://fer-api-n601.onrender.com/predict';

  Future<Map<String, dynamic>> detectEmotions(dynamic input) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Handle Image File - API expects 'file' as the field name
      if (kIsWeb) {
        if (input is List<int>) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            input,
            filename: 'upload.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      } else {
        if (input is io.File) {
          request.files.add(await http.MultipartFile.fromPath(
            'file',
            input.path,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      print('Sending request to Render API...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        // Your new API returns:
        // {
        //   "emotion": "happy",
        //   "confidence": 0.89,
        //   "confidence_percentage": "89.00%",
        //   "all_predictions": {
        //     "happy": {"probability": 0.89, "percentage": "89.00%"},
        //     "sad": {"probability": 0.05, "percentage": "5.00%"},
        //     ...
        //   }
        // }

        return jsonResponse;

      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
}