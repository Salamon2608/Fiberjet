import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/v1/speed_test/download?size=MB
/// Generates a large response to test download speed.
Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final sizeParam = context.request.url.queryParameters['size'] ?? '5';
  final sizeInMb = int.tryParse(sizeParam) ?? 5;
  
  // Cap at 20MB for safety in dev
  final finalSize = sizeInMb.clamp(1, 20);
  
  // Generate dummy data (a string of 'A' characters)
  final data = List.filled(finalSize * 1024 * 1024, 65); // 65 is 'A'
  
  return Response.bytes(
    body: data,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Length': data.length.toString(),
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  );
}
