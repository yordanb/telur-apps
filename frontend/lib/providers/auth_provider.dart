import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../services/api_service.dart';

// ============== Auth State ==============
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Auth Notifier ==============
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => checkAuth());
    return const AuthState();
  }

  Future<void> checkAuth() async {
    final token = await ApiService.getToken();
    if (token != null) {
      try {
        final response = await ApiService.get('/auth/me');
        if (response.statusCode == 200) {
          state = AuthState(
            user: User.fromJson(jsonDecode(response.body)),
            isAuthenticated: true,
          );
        } else {
          await logout();
        }
      } catch (e) {
        await logout();
      }
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Body sebagai Map agar http meng-URL-encode otomatis.
      // Versi lama memakai string mentah 'username=$u&password=$p' sehingga
      // password berisi & = + % atau spasi selalu gagal (tapi di /docs bisa).
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username.trim(), 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await ApiService.saveToken(data['access_token']);

        final userResponse = await ApiService.get('/auth/me');
        if (userResponse.statusCode == 200) {
          state = AuthState(
            user: User.fromJson(jsonDecode(userResponse.body)),
            isAuthenticated: true,
          );
          return true;
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'Gagal mengambil data user',
          );
          return false;
        }
      } else if (response.statusCode == 401) {
        state = state.copyWith(
          isLoading: false,
          error: 'Username atau password salah',
        );
        return false;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Login gagal. Coba lagi.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.removeToken();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
