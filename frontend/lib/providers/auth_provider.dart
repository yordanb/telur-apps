import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;

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
          _error = null;
        } else {
          await logout();
          _error = 'Session expired. Please login again.';
        }
      } catch (e) {
        await logout();
        _error = 'Network error. Please check your connection.';
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
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
        _error = null;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _isLoading = false;
        _error = 'Username atau password salah';
        notifyListeners();
        return false;
      } else {
        _isLoading = false;
        _error = 'Login failed. Please try again.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.removeToken();
    _user = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
