import 'package:flutter/material.dart';
import 'package:fiberjet/services/api_service.dart';
import 'package:fiberjet/services/storage_service.dart';

/// Manages authentication state: login, logout, token persistence, and role routing.
class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _userRole;
  Map<String, dynamic>? _currentUser;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get userRole {
    if (_userRole == null) return null;
    final r = _userRole!.trim().toLowerCase();
    if (r == 'tech') return 'technician';
    if (r.contains('sales')) return 'sales';
    return r;
  }
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Initialize — check for stored token on app launch
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final token = await StorageService.getToken();
    if (token != null) {
      ApiService.setToken(token);
      // Validate token by fetching profile
      final result = await ApiService.get('/auth/profile');
      if (result.success && result.data != null) {
        _currentUser = result.data as Map<String, dynamic>;
        _userRole = _currentUser?['role'] as String?;
        _isLoggedIn = true;
      } else {
        // Token expired or invalid
        await StorageService.clearToken();
        ApiService.setToken(null);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Login with email and password
  Future<String?> loginWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await StorageService.saveToken(token);
        ApiService.setToken(token);
        _currentUser = user;
        _userRole = user?['role'] as String?;
        _isLoggedIn = true;
      }
    }

    _isLoading = false;
    notifyListeners();

    return result.success ? null : result.message;
  }

  /// Login with phone and OTP
  Future<String?> loginWithOTP(String phone, String otp) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post('/auth/otp/verify', body: {
      'phone': phone,
      'otp': otp,
    });

    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await StorageService.saveToken(token);
        ApiService.setToken(token);
        _currentUser = user;
        _userRole = user?['role'] as String?;
        _isLoggedIn = true;
      }
    }

    _isLoading = false;
    notifyListeners();

    return result.success ? null : result.message;
  }

  /// Logout — clear token and navigate to login
  Future<void> logout() async {
    // Call backend to invalidate token
    await ApiService.post('/auth/logout');

    await StorageService.clearToken();
    ApiService.setToken(null);
    _isLoggedIn = false;
    _userRole = null;
    _currentUser = null;
    notifyListeners();
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    final result = await ApiService.get('/auth/profile');
    if (result.success && result.data != null) {
      _currentUser = result.data as Map<String, dynamic>;
      notifyListeners();
    }
  }
}
