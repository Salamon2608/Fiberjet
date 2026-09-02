import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API service for all backend communication.
/// Handles authentication headers, error parsing, and environment switching.
class ApiService {
  static const Duration _timeoutDuration = Duration(seconds: 10);

  // ── Configuration ─────────────────────────────────────────
  static String get _devBaseUrl {
    // Physical Android device: use the PC's local network IP so the phone
    // can reach the dart_frog backend running on the development machine.
    // PC IP: 192.168.1.46  (auto-detected — updated for local network)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.46:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  static const String _prodBaseUrl = 'https://api.fiberjet.in';

  static String get baseUrl => kReleaseMode ? _prodBaseUrl : _devBaseUrl;

  static String? _authToken;

  /// Load the token from storage (Call this early in main.dart or splash screen)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
    } catch (e) {
      debugPrint('Failed to load auth token: $e');
    }
  }

  /// Set the JWT token after login and persist it
  static Future<void> setToken(String? token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('auth_token', token);
      } else {
        await prefs.remove('auth_token');
      }
    } catch (e) {
      debugPrint('Failed to save auth token: $e');
    }
  }

  /// Get the current token
  static String? get token => _authToken;

  /// Check if user is authenticated
  static bool get isAuthenticated =>
      _authToken != null && _authToken!.isNotEmpty;

  // ── Headers ────────────────────────────────────────────────
  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ── HTTP Methods ───────────────────────────────────────────

  /// GET request
  static Future<ApiResult> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v1$path',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers).timeout(_timeoutDuration);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'Connection timed out. Unable to reach backend server ($baseUrl).',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// POST request
  static Future<ApiResult> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1$path');
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeoutDuration);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'Connection timed out. Unable to reach backend server ($baseUrl).',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// PUT request
  static Future<ApiResult> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1$path');
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeoutDuration);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'Connection timed out. Unable to reach backend server ($baseUrl).',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// PATCH request
  static Future<ApiResult> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1$path');
      final response = await http
          .patch(
            uri,
            headers: _headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeoutDuration);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'Connection timed out. Unable to reach backend server ($baseUrl).',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// POST Multipart request (for file uploads)
  static Future<ApiResult> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1$path');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers.addAll(_headers);
      // Remove Content-Type because MultipartRequest sets its own with boundary
      request.headers.remove('Content-Type');
      
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      if (files != null) {
        request.files.addAll(files);
      }
      
      final streamedResponse = await request.send().timeout(_timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);
      
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'Connection timed out. Unable to reach backend server ($baseUrl).',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  /// DELETE request
  static Future<ApiResult> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1$path');
      final response = await http.delete(uri, headers: _headers).timeout(_timeoutDuration);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResult(
        success: false,
        message: 'Connection timed out. Unable to reach backend server ($baseUrl).',
      );
    } catch (e) {
      return ApiResult(success: false, message: 'Network error: $e');
    }
  }

  // ── Response Parsing ───────────────────────────────────────
  static ApiResult _parseResponse(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Build error message including details if present
      String msg = json['message'] as String? ?? json['error'] as String? ?? 'An error occurred';
      if (json['details'] != null) {
        msg = '$msg\n${json['details']}';
      }
      return ApiResult(
        success: json['success'] as bool? ?? (response.statusCode >= 200 && response.statusCode < 300),
        data: json['data'],
        message: msg,
        statusCode: response.statusCode,
      );
    } catch (e) {
      // Show truncated raw body for debugging
      final bodyPreview = response.body.length > 200 
          ? '${response.body.substring(0, 200)}...' 
          : response.body;
      return ApiResult(
        success: false,
        message: 'Failed to parse response: $bodyPreview',
        statusCode: response.statusCode,
      );
    }
  }
}

/// Standardized API response wrapper
class ApiResult {
  final bool success;
  final dynamic data;
  final String message;
  final int? statusCode;

  ApiResult({
    required this.success,
    this.data,
    this.message = '',
    this.statusCode,
  });

  /// True if the request returned a 401 (token expired/invalid)
  bool get isUnauthorized => statusCode == 401;
}
