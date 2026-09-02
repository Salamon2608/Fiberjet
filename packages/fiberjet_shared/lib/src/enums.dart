enum Role {
  customer,
  sales,
  technician,
  admin;

  factory Role.fromString(String value) {
    return Role.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Role.customer,
    );
  }
}

enum JobType {
  installation,
  repair,
  maintenance,
  siteSurvey;

  factory JobType.fromString(String value) {
    return JobType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () => JobType.installation,
    );
  }
}

enum JobStatus {
  pending,
  assigned,
  inProgress,
  completed,
  cancelled;

  factory JobStatus.fromString(String value) {
    return JobStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () => JobStatus.pending,
    );
  }
}

enum LeadStage {
  newLead,
  contacted,
  kycPending,
  qualified,
  lost,
  converted;

  factory LeadStage.fromString(String value) {
    return LeadStage.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () => LeadStage.newLead,
    );
  }
}

enum ComplaintStatus {
  pending,
  inProgress,
  resolved,
  closed;

  factory ComplaintStatus.fromString(String value) {
    return ComplaintStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () => ComplaintStatus.pending,
    );
  }
}

enum PayoutStatus {
  pending,
  approved,
  rejected,
  paid;

  factory PayoutStatus.fromString(String value) {
    return PayoutStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PayoutStatus.pending,
    );
  }
}

enum NotificationType {
  system,
  job,
  lead,
  payout,
  alert;

  factory NotificationType.fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NotificationType.system,
    );
  }
}
