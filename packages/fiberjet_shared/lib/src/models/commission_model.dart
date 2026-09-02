class CommissionModel {
  final String id;
  final String salesPersonId;
  final String? leadId;
  final double amount;
  final String status; // 'pending', 'paid'
  final DateTime createdAt;

  CommissionModel({
    required this.id,
    required this.salesPersonId,
    this.leadId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) {
    return CommissionModel(
      id: json['id'] as String,
      salesPersonId: json['sales_person_id'] as String,
      leadId: json['lead_id'] as String?,
      amount: json['amount'] is num 
          ? (json['amount'] as num).toDouble() 
          : (double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
      status: json['status'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sales_person_id': salesPersonId,
      'lead_id': leadId,
      'amount': amount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
