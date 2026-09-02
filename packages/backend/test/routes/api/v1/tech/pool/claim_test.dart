import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import '../../../../../../routes/api/v1/tech/pool/claim.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockPostgresService extends Mock implements PostgresService {}
class _MockUserModel extends Mock implements UserModel {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('POST /api/v1/tech/pool/claim', () {
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
      when(() => user.name).thenReturn('Tech Guy');
    });

    test('responds with methodNotAllowed if method is not POST', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns error if parameters are missing or invalid', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => <String, dynamic>{});

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], contains('task_type and task_id are required'));
    });

    test('returns error if task_type is invalid', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {
        'task_type': 'invalid',
        'task_id': 'some-uuid',
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], contains('task_type must be either "job" or "complaint"'));
    });

    test('returns conflict if job is already claimed or non-existent', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {
        'task_type': 'job',
        'task_id': 'job-uuid',
      });

      final mockEmptyResult = _MockResult();
      when(() => mockEmptyResult.isEmpty).thenReturn(true);

      when(() => db.query(
        any(that: contains('UPDATE jobs')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => mockEmptyResult);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.conflict));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], contains('already been claimed'));
    });

    test('claims job successfully and logs audit event', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {
        'task_type': 'job',
        'task_id': 'job-uuid',
      });

      final mockRow = _MockResultRow();
      when(() => mockRow.toColumnMap()).thenReturn({'id': 'job-uuid'});

      final mockSuccessResult = _MockResult();
      when(() => mockSuccessResult.isEmpty).thenReturn(false);
      when(() => mockSuccessResult.iterator).thenReturn([mockRow].iterator);

      // Setup mock query for the UPDATE jobs query
      when(() => db.query(
        any(that: contains('UPDATE jobs')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => mockSuccessResult);

      // Setup mock query for the audit log insert
      when(() => db.query(
        any(that: contains('INSERT INTO audit_logs')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => _MockResult());

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['message'], contains('Installation job claimed successfully'));
      expect(body['data']['id'], equals('job-uuid'));

      // Verify UPDATE was called with correct parameters
      verify(() => db.query(
        any(that: contains('UPDATE jobs')),
        substitutionValues: {
          'jobId': 'job-uuid',
          'techId': 'tech-789',
        },
      )).called(1);
    });

    test('claims complaint successfully and logs audit event', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {
        'task_type': 'complaint',
        'task_id': 'complaint-uuid',
      });

      final mockRow = _MockResultRow();
      when(() => mockRow.toColumnMap()).thenReturn({'id': 'complaint-uuid'});

      final mockSuccessResult = _MockResult();
      when(() => mockSuccessResult.isEmpty).thenReturn(false);
      when(() => mockSuccessResult.iterator).thenReturn([mockRow].iterator);

      // Setup mock query for the UPDATE complaints query
      when(() => db.query(
        any(that: contains('UPDATE complaints')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => mockSuccessResult);

      // Setup mock query for the audit log insert
      when(() => db.query(
        any(that: contains('INSERT INTO audit_logs')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => _MockResult());

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['message'], contains('Support ticket claimed successfully'));
      expect(body['data']['id'], equals('complaint-uuid'));

      // Verify UPDATE was called with correct parameters
      verify(() => db.query(
        any(that: contains('UPDATE complaints')),
        substitutionValues: {
          'complaintId': 'complaint-uuid',
          'techId': 'tech-789',
        },
      )).called(1);
    });
  });
}
