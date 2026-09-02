void main() {
  final startDate = DateTime.tryParse('2026-05-14T00:00:00.000Z');
  final expiryDate = DateTime.tryParse('2026-06-13T00:00:00.000Z');
  final now = DateTime.tryParse('2026-05-25T16:13:34+05:30') ?? DateTime.now();
  
  if (startDate != null && expiryDate != null) {
    final daysLeft = expiryDate.difference(now).inDays;
    final totalDays = expiryDate.difference(startDate).inDays;
    final timeProgress = totalDays > 0 ? (daysLeft / totalDays).clamp(0.0, 1.0) : 0.0;
    
    print('startDate: $startDate (isUtc: ${startDate.isUtc})');
    print('expiryDate: $expiryDate (isUtc: ${expiryDate.isUtc})');
    print('now: $now (isUtc: ${now.isUtc})');
    print('daysLeft: $daysLeft');
    print('totalDays: $totalDays');
    print('timeProgress: $timeProgress');
  }
}
