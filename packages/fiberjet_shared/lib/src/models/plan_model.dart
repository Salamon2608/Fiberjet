class PlanModel {
  final String id;
  final String name;
  final String description;
  final int speedMbps;
  final double price;
  final int validityDays;
  final bool isActive;
  final List<String> features;

  // ── My-Jio-style fields ──────────────────────────────────
  final String category;
  final String? badge;
  final double? dataPerDayGb;
  final int? dataLimitGb;
  final int? fupSpeedMbps;
  final int priority;
  final int cloudStorageGb;
  final Map<String, dynamic>? ottBenefits;

  PlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.speedMbps,
    required this.price,
    this.validityDays = 30,
    this.isActive = true,
    this.features = const [],
    this.category = 'Popular',
    this.badge,
    this.dataPerDayGb,
    this.dataLimitGb,
    this.fupSpeedMbps,
    this.priority = 100,
    this.cloudStorageGb = 0,
    this.ottBenefits,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, [double fallback = 0.0]) {
      if (val is num) return val.toDouble();
      if (val != null) return double.tryParse(val.toString()) ?? fallback;
      return fallback;
    }

    int parseInt(dynamic val, [int fallback = 0]) {
      if (val is num) return val.toInt();
      if (val != null) return int.tryParse(val.toString()) ?? (double.tryParse(val.toString())?.toInt() ?? fallback);
      return fallback;
    }

    return PlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      speedMbps: parseInt(json['speed_mbps']),
      price: parseDouble(json['price']),
      validityDays: parseInt(json['validity_days'], 30),
      isActive: json['is_active'] as bool? ?? true,
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      category: json['category']?.toString() ?? 'Popular',
      badge: json['badge']?.toString(),
      dataPerDayGb: json['data_per_day_gb'] != null ? parseDouble(json['data_per_day_gb']) : null,
      dataLimitGb: json['data_limit_gb'] != null ? parseInt(json['data_limit_gb']) : null,
      fupSpeedMbps: json['fup_speed_mbps'] != null ? parseInt(json['fup_speed_mbps']) : null,
      priority: parseInt(json['priority'], 100),
      cloudStorageGb: parseInt(json['cloud_storage_gb'], 0),
      ottBenefits: json['ott_benefits'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'speed_mbps': speedMbps,
      'price': price,
      'validity_days': validityDays,
      'is_active': isActive,
      'features': features,
      'category': category,
      'badge': badge,
      'data_per_day_gb': dataPerDayGb,
      'data_limit_gb': dataLimitGb,
      'fup_speed_mbps': fupSpeedMbps,
      'priority': priority,
      'cloud_storage_gb': cloudStorageGb,
      'ott_benefits': ottBenefits,
    };
  }

  PlanModel copyWith({
    String? id,
    String? name,
    String? description,
    int? speedMbps,
    double? price,
    int? validityDays,
    bool? isActive,
    List<String>? features,
    String? category,
    String? badge,
    double? dataPerDayGb,
    int? dataLimitGb,
    int? fupSpeedMbps,
    int? priority,
    int? cloudStorageGb,
    Map<String, dynamic>? ottBenefits,
  }) {
    return PlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      speedMbps: speedMbps ?? this.speedMbps,
      price: price ?? this.price,
      validityDays: validityDays ?? this.validityDays,
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
      category: category ?? this.category,
      badge: badge ?? this.badge,
      dataPerDayGb: dataPerDayGb ?? this.dataPerDayGb,
      dataLimitGb: dataLimitGb ?? this.dataLimitGb,
      fupSpeedMbps: fupSpeedMbps ?? this.fupSpeedMbps,
      priority: priority ?? this.priority,
      cloudStorageGb: cloudStorageGb ?? this.cloudStorageGb,
      ottBenefits: ottBenefits ?? this.ottBenefits,
    );
  }
}
