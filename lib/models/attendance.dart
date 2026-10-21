class AttendanceRecord {
  final dynamic id;
  final String? userId;
  final String? userName;
  final String? email;
  final String? initials;
  final String? deviceInfo;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? method; // 'GPS', 'QR', 'FACE', 'MANUAL', 'DASHBOARD'
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? status; // 'VALID', 'ON_TIME', 'LATE', 'Pending', 'Approved', etc.
  final String? notes;

  AttendanceRecord({
    this.id,
    this.userId,
    this.userName,
    this.email,
    this.initials,
    this.deviceInfo,
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
      userName: (json['userName'] ?? json['UserName'] ?? json['user']?['userName'] ?? json['User']?['UserName'])?.toString(),
      email: (json['email'] ?? json['Email'] ?? json['user']?['email'] ?? json['User']?['Email'])?.toString(),
      initials: (json['initials'] ?? json['Initials'] ?? json['user']?['initials'] ?? json['User']?['Initials'])?.toString(),
      deviceInfo: (json['deviceInfo'] ?? json['DeviceInfo'])?.toString(),
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
      'userName': userName,
      'email': email,
      'initials': initials,
      'deviceInfo': deviceInfo,
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

  AttendanceRecord copyWith({
    dynamic id,
    String? userId,
    String? userName,
    String? email,
    String? initials,
    String? deviceInfo,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? method,
    double? latitude,
    double? longitude,
    String? locationName,
    String? status,
    String? notes,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      initials: initials ?? this.initials,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      method: method ?? this.method,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
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

  bool get isOpenShift => checkInTime != null && checkOutTime == null;

  bool get isToday {
    if (checkInTime == null) return false;
    final now = DateTime.now();
    return checkInTime!.year == now.year &&
        checkInTime!.month == now.month &&
        checkInTime!.day == now.day;
  }
}

class Employee {
  final String id;
  final String userName;
  final String? email;
  final String role;
  final String? initials;

  Employee({
    required this.id,
    required this.userName,
    this.email,
    required this.role,
    this.initials,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Role could be in 'role', 'Role', 'roles' array, etc.
    String parsedRole = 'User';
    if (json['role'] != null) {
      parsedRole = json['role'].toString();
    } else if (json['Role'] != null) {
      parsedRole = json['Role'].toString();
    } else if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      parsedRole = (json['roles'] as List).first.toString();
    } else if (json['Roles'] is List && (json['Roles'] as List).isNotEmpty) {
      parsedRole = (json['Roles'] as List).first.toString();
    }

    return Employee(
      id: (json['id'] ?? json['Id'] ?? json['userId'] ?? json['UserId'] ?? '').toString(),
      userName: (json['userName'] ?? json['UserName'] ?? json['username'] ?? 'Nhân viên').toString(),
      email: (json['email'] ?? json['Email'])?.toString(),
      role: parsedRole,
      initials: (json['initials'] ?? json['Initials'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'email': email,
      'role': role,
      'initials': initials,
    };
  }
}
