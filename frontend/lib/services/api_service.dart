import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // API Backend URL
  static const String baseUrl = 'https://egg.mibt.my.id/api';

  /// Batas tunggu tiap request — tanpa ini request yang macet (mis. DNS
  /// emulator rusak) membuat spinner berputar selamanya tanpa pesan error.
  static const Duration requestTimeout = Duration(seconds: 20);

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await getHeaders();
    final response = await http
        .get(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
        )
        .timeout(requestTimeout);
    return response;
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return response;
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http
        .put(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return response;
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await getHeaders();
    final response = await http
        .delete(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
        )
        .timeout(requestTimeout);
    return response;
  }

  static dynamic handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'An error occurred');
    }
  }
}
