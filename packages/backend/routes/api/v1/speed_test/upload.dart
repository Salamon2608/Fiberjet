import 'dart:io';

import 'package:backend/utils/api_response.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/speed_test/upload
/// Accepts data to test upload speed.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    int totalBytes = 0;
    await for (final chunk in context.request.bytes()) {
      totalBytes += chunk.length;
    }
    
    final sizeInMb = totalBytes / (1024 * 1024);
    
    return ApiResponse.success(
      message: 'Upload complete',
      data: {
        'size_bytes': totalBytes,
        'size_mb': sizeInMb.toStringAsFixed(2),
      },
    );
  } catch (e) {
    return ApiResponse.error(message: 'Upload failed: $e');
  }
}
