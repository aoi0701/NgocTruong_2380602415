class AttendanceRecord {
  final dynamic id;
  final String? userId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? method; // 'GPS', 'QR', 'FACE', 'MANUAL'
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? status; // 'VALID', 'ON_TIME', 'LATE', 'Pending', 'Approved', etc.
  final String? notes;

  AttendanceRecord({
    this.id,
    this.userId,
    this.checkInTime,
    this.checkOutTime,
    this.method,
    this.latitude,
    this.longitude,
    this.locationName,
    this.status,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return AttendanceRecord(
      id: json['id'] ?? json['Id'] ?? json['attendanceId'] ?? json['AttendanceId'],
      userId: (json['userId'] ?? json['UserId'] ?? json['userName'] ?? json['UserName'])?.toString(),
      checkInTime: parseDate(json['checkInTime'] ?? json['CheckInTime'] ?? json['checkIn'] ?? json['CheckIn']),
      checkOutTime: parseDate(json['checkOutTime'] ?? json['CheckOutTime'] ?? json['checkOut'] ?? json['CheckOut']),
      method: (json['method'] ?? json['Method'] ?? json['checkInMethod'] ?? json['CheckInMethod'])?.toString(),
      latitude: parseDouble(json['latitude'] ?? json['Latitude']),
      longitude: parseDouble(json['longitude'] ?? json['Longitude']),
      locationName: (json['locationName'] ?? json['LocationName'] ?? json['location'] ?? json['Location'])?.toString(),
      status: (json['status'] ?? json['Status'] ?? 'VALID')?.toString(),
      notes: (json['notes'] ?? json['Notes'] ?? json['note'] ?? json['Note'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'checkInTime': checkInTime?.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'method': method,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'status': status,
      'notes': notes,
    };
  }

  String get formattedCheckIn {
    if (checkInTime == null) return '--:--';
    final dt = checkInTime!;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '$time - $date';
  }

  String get formattedCheckOut {
    if (checkOutTime == null) return 'Chưa ra ca';
    final dt = checkOutTime!;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '$time - $date';
  }

  Duration? get duration {
    if (checkInTime == null) return null;
    final end = checkOutTime ?? DateTime.now();
    return end.difference(checkInTime!);
  }

  String get durationText {
    final d = duration;
    if (d == null) return '--';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (checkOutTime == null) {
      return '$hours giờ $minutes phút (Đang trực)';
    }
    return '$hours giờ $minutes phút';
  }

  bool get isCompleted => checkOutTime != null;

  bool get isToday {
    if (checkInTime == null) return false;
    final now = DateTime.now();
    return checkInTime!.year == now.year &&
        checkInTime!.month == now.month &&
        checkInTime!.day == now.day;
  }
}
