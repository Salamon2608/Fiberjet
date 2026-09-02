import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/websocket_service.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  if (request.method == HttpMethod.get) {
    // Fetch all complaints with customer and assigned technician names
    final result = await db.query(
      '''
      SELECT c.*, u.name as customer_name, t.name as technician_name
      FROM complaints c
      LEFT JOIN users u ON c.user_id = u.id
      LEFT JOIN users t ON c.assigned_to = t.id
      ORDER BY c.created_at DESC
      ''',
    );

    return Response.json(body: {'data': result.map((r) => r.toColumnMap()).toList()});
  }

  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final complaintId = body['complaint_id'] as String?;
    final assignedTo = body['assigned_to'] as String?; // technician user_id
    final status = body['status'] as String?;

    if (complaintId == null) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'message': 'complaint_id is required'},
      );
    }

    // Prepare update parameters
    final params = <String, dynamic>{'complaintId': complaintId};
    final updates = <String>['updated_at = NOW()'];

    if (assignedTo != null) {
      updates.add('assigned_to = @assignedTo');
      params['assignedTo'] = assignedTo;
    }
    if (status != null) {
      updates.add('status = @status');
      params['status'] = status;
    }

    if (updates.length == 1) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'message': 'At least assigned_to or status must be provided for update'},
      );
    }

    await db.query(
      '''
      UPDATE complaints 
      SET ${updates.join(', ')} 
      WHERE id = @complaintId
      ''',
      substitutionValues: params,
    );

    // Dispatch realtime event if assigned to a technician
    if (assignedTo != null) {
      final wsService = context.read<WebsocketService>();
      wsService.dispatchEvent(
        assignedTo,
        'job_assigned',
        {
          'message': 'You have been assigned a new job',
          'complaint_id': complaintId,
        },
      );
    }

    return Response.json(body: {'message': 'Complaint updated successfully'});
  }

  return Response.json(
    statusCode: HttpStatus.methodNotAllowed,
    body: {'message': 'Method not allowed'},
  );
}
