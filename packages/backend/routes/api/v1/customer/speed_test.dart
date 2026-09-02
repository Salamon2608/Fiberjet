import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// Safely converts a postgres NUMERIC/String value to double.
double _toDouble(dynamic v) =>
    num.tryParse(v?.toString() ?? '')?.toDouble() ?? 0.0;

/// POST /api/v1/customer/speed_test → Save a new speed test result
/// GET  /api/v1/customer/speed_test → Get latest speed test results (last 30)
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Speed test history ────────────────────────────────
  if (request.method == HttpMethod.get) {
    final limit =
        (int.tryParse(request.url.queryParameters['limit'] ?? '30') ?? 30)
            .clamp(1, 100);

    try {
      // LIMIT cannot be a bound parameter — embed directly (safe, clamped to 1-100)
      final result = await db.query(
        '''
        SELECT id, download_mbps, upload_mbps, ping_ms, jitter_ms, created_at
        FROM speed_tests
        WHERE user_id = @userId
        ORDER BY created_at DESC
        LIMIT $limit
        ''',
        substitutionValues: {'userId': user.id},
      );

      // Serialize rows — NUMERIC cols come back as String from the postgres driver
      final tests = result.map((r) {
        final m = r.toColumnMap();
        return {
          'id': m['id']?.toString(),
          'download_mbps': _toDouble(m['download_mbps']),
          'upload_mbps': _toDouble(m['upload_mbps']),
          'ping_ms': _toDouble(m['ping_ms']),
          'jitter_ms': _toDouble(m['jitter_ms']),
          'created_at': m['created_at'] is DateTime
              ? (m['created_at'] as DateTime).toIso8601String()
              : m['created_at']?.toString(),
        };
      }).toList();

      // Calculate averages
      double avgDown = 0, avgUp = 0, avgPing = 0;
      if (tests.isNotEmpty) {
        for (final t in tests) {
          avgDown += t['download_mbps'] as double;
          avgUp += t['upload_mbps'] as double;
          avgPing += t['ping_ms'] as double;
        }
        avgDown /= tests.length;
        avgUp /= tests.length;
        avgPing /= tests.length;
      }

      return ApiResponse.success(
        data: {
          'tests': tests,
          'total': tests.length,
          'averages': {
            'download_mbps': double.parse(avgDown.toStringAsFixed(2)),
            'upload_mbps': double.parse(avgUp.toStringAsFixed(2)),
            'ping_ms': double.parse(avgPing.toStringAsFixed(2)),
          },
        },
      );
    } catch (e, st) {
      print('SPEED_TEST_GET_ERROR: $e\n$st');
      return ApiResponse.error(
        message: 'Failed to fetch speed test history: $e',
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  // ── POST: Record new speed test ────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final downloadMbps = num.tryParse(body['download_mbps']?.toString() ?? '');
    final uploadMbps = num.tryParse(body['upload_mbps']?.toString() ?? '');
    final pingMs = num.tryParse(body['ping_ms']?.toString() ?? '') ?? 0;
    final jitterMs = num.tryParse(body['jitter_ms']?.toString() ?? '') ?? 0;

    if (downloadMbps == null || uploadMbps == null) {
      return ApiResponse.error(
        message: 'download_mbps and upload_mbps are required',
      );
    }

    try {
      final result = await db.query(
        '''
        INSERT INTO speed_tests (user_id, download_mbps, upload_mbps, ping_ms, jitter_ms)
        VALUES (@userId, @download, @upload, @ping, @jitter)
        RETURNING id, download_mbps, upload_mbps, ping_ms, jitter_ms, created_at
        ''',
        substitutionValues: {
          'userId': user.id,
          'download': downloadMbps,
          'upload': uploadMbps,
          'ping': pingMs,
          'jitter': jitterMs,
        },
      );

      final m = result.first.toColumnMap();
      return ApiResponse.success(
        message: 'Speed test recorded',
        statusCode: HttpStatus.created,
        data: {
          'id': m['id']?.toString(),
          'download_mbps': _toDouble(m['download_mbps']),
          'upload_mbps': _toDouble(m['upload_mbps']),
          'ping_ms': _toDouble(m['ping_ms']),
          'jitter_ms': _toDouble(m['jitter_ms']),
          'created_at': m['created_at'] is DateTime
              ? (m['created_at'] as DateTime).toIso8601String()
              : m['created_at']?.toString(),
        },
      );
    } catch (e) {
      return ApiResponse.error(
        message: 'Failed to record speed test: $e',
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
