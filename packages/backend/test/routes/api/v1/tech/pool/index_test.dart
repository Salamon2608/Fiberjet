import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import '../../../../../../routes/api/v1/tech/pool/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockPostgresService extends Mock implements PostgresService {}
class _MockUserModel extends Mock implements UserModel {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('GET /api/v1/tech/pool', () {
    late RequestContext context;
    late Request request;
    late PostgresService db;
    late UserModel user;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      db = _MockPostgresService();
      user = _MockUserModel();

      when(() => context.request).thenReturn(request);
      when(() => context.read<PostgresService>()).thenReturn(db);
      when(() => context.read<UserModel>()).thenReturn(user);

      when(() => user.id).thenReturn('tech-789');
    });

    test('responds with methodNotAllowed if method is not GET', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns combined pool of jobs and complaints sorted by created_at descending', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      // Setup mock job row
      final mockJobRow = _MockResultRow();
      final jobMap = {
        'id': 'job-123',
        'type': 'installation',
        'status': 'pending',
        'customer_name': 'Alice Smith',
        'customer_phone': '555-0100',
        'address': '123 Main St',
        'scheduled_at': DateTime.utc(2026, 5, 22, 10, 0),
        'created_at': DateTime.utc(2026, 5, 21, 9, 0),
      };
      when(() => mockJobRow.toColumnMap()).thenReturn(jobMap);

      final mockJobResult = _MockResult();
      when(() => mockJobResult.iterator).thenReturn([mockJobRow].iterator);
      when(() => mockJobResult.map<Map<String, dynamic>>(any())).thenAnswer((invocation) {
        final f = invocation.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [f(mockJobRow)];
      });

      // Setup mock complaint row (created after job)
      final mockComplaintRow = _MockResultRow();
      final complaintMap = {
        'id': 'complaint-456',
        'title': 'No Connection',
        'category': 'Technical Support',
        'description': 'Red light flashing on router',
        'status': 'open',
        'customer_name': 'Bob Jones',
        'customer_phone': '555-0200',
        'created_at': DateTime.utc(2026, 5, 22, 14, 0),
      };
      when(() => mockComplaintRow.toColumnMap()).thenReturn(complaintMap);

      final mockComplaintResult = _MockResult();
      when(() => mockComplaintResult.iterator).thenReturn([mockComplaintRow].iterator);
      when(() => mockComplaintResult.map<Map<String, dynamic>>(any())).thenAnswer((invocation) {
        final f = invocation.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [f(mockComplaintRow)];
      });

      // Mock database queries sequentially or based on query string
      when(() => db.query(
        any(),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((invocation) async {
        final queryStr = invocation.positionalArguments[0] as String;
        if (queryStr.contains('FROM complaints')) {
          return mockComplaintResult;
        } else {
          return mockJobResult;
        }
      });

      when(() => db.query(any())).thenAnswer((invocation) async {
        final queryStr = invocation.positionalArguments[0] as String;
        if (queryStr.contains('FROM complaints')) {
          return mockComplaintResult;
        } else {
          return mockJobResult;
        }
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['data'], isA<Map<String, dynamic>>());
      
      final poolList = body['data']['pool'] as List<dynamic>;
      expect(poolList.length, equals(2));

      // The complaint should be first because it was created at 14:00 (Job was at 09:00)
      expect(poolList[0]['type'], equals('complaint'));
      expect(poolList[0]['id'], equals('complaint-456'));
      expect(poolList[0]['title'], equals('No Connection'));

      expect(poolList[1]['type'], equals('job'));
      expect(poolList[1]['id'], equals('job-123'));
      expect(poolList[1]['title'], equals('Installation Request'));
    });
  });
}
