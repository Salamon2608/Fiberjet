import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

class ApiResponse {
  static Object? _customEncoder(dynamic object) {
    if (object is DateTime) {
      return object.toIso8601String();
    }
    return object; // Let jsonEncode handle the rest or throw if unencodable
  }

  /// Returns a standardized success response.
  static Response success({
    dynamic data,
    String message = 'Success',
    int statusCode = HttpStatus.ok,
  }) {
    final bodyStr = jsonEncode(
      {
        'success': true,
        'message': message,
        'data': data,
      },
      toEncodable: _customEncoder,
    );
    return Response(
      statusCode: statusCode,
      body: bodyStr,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store, no-cache, must-revalidate, max-age=0',
        'pragma': 'no-cache',
        'expires': '0',
      },
    );
  }

  /// Returns a standardized error response.
  static Response error({
    required String message,
    dynamic data,
    int statusCode = HttpStatus.badRequest,
  }) {
    final bodyStr = jsonEncode(
      {
        'success': false,
        'message': message,
        'data': data,
      },
      toEncodable: _customEncoder,
    );
    return Response(
      statusCode: statusCode,
      body: bodyStr,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store, no-cache, must-revalidate, max-age=0',
        'pragma': 'no-cache',
        'expires': '0',
      },
    );
  }
}
