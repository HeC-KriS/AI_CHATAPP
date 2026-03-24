import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

//use your ipaddress
class ApiService {
  static String baseUrl = dotenv.env["IPADDRESS"] ?? '';

  static Future<String> getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else {
      var iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios";
    }
  }

  static Future<List<Map<String, dynamic>>> getThreads(String userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/threads/$userId"));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) { print("Error fetching threads: $e"); }
    return [];
  }

  static Future<bool> deleteChat(String threadId) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/chat/$threadId"));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> getHistory(String threadId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/history/$threadId")).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print(e); }
    return [];
  }

  static Future<String> chat({
    required String prompt,
    required String modelId,
    required String threadId,
    required String userId,
    required String threadName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "prompt": prompt,
          "model_id": modelId,
          "thread_id": threadId,
          "user_id": userId,
          "thread_name": threadName,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data.containsKey("reply") ? data["reply"] : data["choices"][0]["message"]["content"];
      }
      return "Server Error: ${response.statusCode}";
    } catch (e) { return "Connection Error: $e"; }
  }
}
