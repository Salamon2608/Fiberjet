class LeadModel {
  final String id;
  final String salesPersonId;
  final String customerName;
  final String phone;
  final String? address;
  final String stage; // 'new', 'contacted', 'kyc_pending', 'converted', 'rejected'
  final DateTime createdAt;

  LeadModel({
    required this.id,
    required this.salesPersonId,
    required this.customerName,
    required this.phone,
    this.address,
    required this.stage,
    required this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id'] as String,
      salesPersonId: json['sales_person_id'] as String,
      customerName: json['customer_name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String?,
      stage: json['stage'] as String? ?? 'new',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sales_person_id': salesPersonId,
      'customer_name': customerName,
      'phone': phone,
      'address': address,
      'stage': stage,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
