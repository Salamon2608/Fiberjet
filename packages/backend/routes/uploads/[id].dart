import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:path/path.dart' as p;

/// GET /uploads/:filename → Serve uploaded image files
Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  print('${context.request.method.value} /uploads/$id');

  final corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  };

  // Support preflight OPTIONS requests
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: corsHeaders,
    );
  }

  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      headers: corsHeaders,
    );
  }

  final filename = id;
  final filePath = p.join(
    Directory.current.path,
    'uploads',
    filename,
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
  final ext = p.extension(filename).toLowerCase();
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

