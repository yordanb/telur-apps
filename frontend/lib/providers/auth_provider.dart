import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final token = await ApiService.getToken();
    if (token != null) {
      try {
        final response = await ApiService.get('/auth/me');
        if (response.statusCode == 200) {
          _user = User.fromJson(jsonDecode(response.body));
          _isAuthenticated = true;
        } else {
          await logout();
        }
      } catch (e) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'username=$username&password=$password',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await ApiService.saveToken(data['access_token']);

        final userResponse = await ApiService.get('/auth/me');
        _user = User.fromJson(jsonDecode(userResponse.body));
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.removeToken();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
