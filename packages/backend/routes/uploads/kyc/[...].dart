import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:path/path.dart' as p;

/// GET /uploads/kyc/<leadId>/<filename> → Serve KYC document files
/// The [...] catch-all route captures the remaining path segments.
Future<Response> onRequest(RequestContext context, String subPath) async {
  final corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization',
  };

  // Support preflight OPTIONS requests
  if (context.request.method == HttpMethod.options) {
    return Response(
      headers: corsHeaders,
    );
  }

  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      headers: corsHeaders,
    );
  }

  // Prevent directory traversal
  if (subPath.contains('..')) {
    return Response(
      statusCode: HttpStatus.forbidden,
      body: 'Forbidden',
      headers: corsHeaders,
    );
  }

  final filePath = p.join(
    Directory.current.path,
    'uploads',
    'kyc',
    subPath,
  );

  final file = File(filePath);
  if (!file.existsSync()) {
    return Response(
      statusCode: HttpStatus.notFound,
      body: 'File not found',
      headers: corsHeaders,
    );
  }

  // Determine content type from extension
  final ext = p.extension(filePath).toLowerCase();
  String contentType;
  switch (ext) {
    case '.jpg':
    case '.jpeg':
      contentType = 'image/jpeg';
    case '.png':
      contentType = 'image/png';
    case '.gif':
      contentType = 'image/gif';
    case '.webp':
      contentType = 'image/webp';
    case '.pdf':
      contentType = 'application/pdf';
    default:
      contentType = 'application/octet-stream';
  }

  final bytes = await file.readAsBytes();
  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=86400',
      ...corsHeaders,
    },
  );
}
