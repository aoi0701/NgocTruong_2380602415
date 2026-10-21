import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/attendance_service.dart';

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key});

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  // Tọa độ chuẩn của Trường Đại học HUTECH (Cơ sở Khu Công Nghệ Cao)
  static const double companyLat = 10.8550;
  static const double companyLng = 106.7854;
  static const String companyName = 'Trường ĐH HUTECH (Trụ sở / Điểm chấm công)';

  final MapController _mapController = MapController();
  Position? _currentPosition;
  String _address = 'Đang chờ lấy vị trí GPS thực tế...';
  String? _errorMessage;
  double? _distanceToCompany;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentPosition = null;
            _errorMessage = 'Dịch vụ định vị GPS trên máy đang tắt. Vui lòng bật định vị GPS để tiếp tục.';
            _address = 'Chưa thể xác định vị trí';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentPosition = null;
              _errorMessage = 'Quyền truy cập vị trí bị từ chối. Vui lòng cấp quyền để thực hiện chấm công.';
              _address = 'Chưa thể xác định vị trí';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentPosition = null;
            _errorMessage = 'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng mở Cài đặt ứng dụng để cấp quyền GPS.';
            _address = 'Chưa thể xác định vị trí';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        companyLat,
        companyLng,
      );

      String detailedAddress = 'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final List<String> addressParts = [];
          if (p.street != null && p.street!.isNotEmpty) addressParts.add(p.street!);
          if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) addressParts.add(p.subAdministrativeArea!);
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) addressParts.add(p.administrativeArea!);
          if (addressParts.isNotEmpty) {
            detailedAddress = addressParts.join(', ');
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _distanceToCompany = distance;
          _address = detailedAddress;
          _isLoading = false;
          _errorMessage = null;
        });
        _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _distanceToCompany = null;
          _errorMessage = 'Lỗi lấy tọa độ GPS thực tế: $e\nVui lòng kiểm tra kết nối mạng và thiết bị GPS.';
          _address = 'Lỗi định vị';
          _isLoading = false;
        });
      }
    }
  }

  void _shareLocation() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có tọa độ GPS để chia sẻ. Vui lòng lấy vị trí trước.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final url = 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết vị trí Google Maps vào bộ nhớ tạm!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Future<void> _handleGpsAttendance({required bool isCheckIn}) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có tọa độ GPS hợp lệ. Vui lòng bấm làm mới vị trí trước khi chấm công.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final AttendanceResult result;
      if (isCheckIn) {
        result = await AttendanceService.instance.checkIn(
          method: 'GPS',
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          locationName: _address,
          notes: _distanceToCompany != null
              ? 'GPS cách trụ sở ${_distanceToCompany!.toStringAsFixed(1)}m'
              : 'GPS thực tế',
        );
      } else {
        result = await AttendanceService.instance.checkOut(
          method: 'GPS',
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          locationName: _address,
          notes: _distanceToCompany != null
              ? 'GPS cách trụ sở ${_distanceToCompany!.toStringAsFixed(1)}m'
              : 'GPS thực tế',
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(result.success
                  ? (isCheckIn ? 'Vào ca thành công' : 'Ra ca thành công')
                  : 'Chấm công thất bại'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('📍 Tọa độ thực: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'),
              if (_distanceToCompany != null)
                Text('📏 Khoảng cách đến cơ sở: ${_distanceToCompany!.toStringAsFixed(1)} mét'),
              const SizedBox(height: 6),
              Text(
                result.success
                    ? '✅ Đã lưu bản ghi chấm công vào máy chủ SQL Server.'
                    : '⚠️ Máy chủ từ chối bản ghi chấm công. Vui lòng kiểm tra lại.',
                style: TextStyle(
                  color: result.success ? Colors.green[800] : Colors.red[800],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi dữ liệu chấm công: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAttendanceOptions() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có tọa độ GPS hợp lệ. Vui lòng thử lại.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Xác nhận chấm công bằng GPS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tọa độ: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}\n'
                '${_distanceToCompany != null ? 'Khoảng cách: ${_distanceToCompany!.toStringAsFixed(1)}m tới trụ sở' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleGpsAttendance(isCheckIn: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Chấm công VÀO CA (Check-in)', style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleGpsAttendance(isCheckIn: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Chấm công RA CA (Check-out)', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(companyLat, companyLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh & Chia sẻ GPS'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Lấy lại vị trí GPS',
            onPressed: (_isLoading || _isSubmitting) ? null : _fetchLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Bản đồ OpenStreetMap
              Expanded(
                flex: 3,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: currentLatLng,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tuan',
                    ),
                    MarkerLayer(
                      markers: [
                        // Ghim vị trí Trụ sở
                        const Marker(
                          point: LatLng(companyLat, companyLng),
                          width: 50,
                          height: 50,
                          child: Tooltip(
                            message: companyName,
                            child: Icon(Icons.business_rounded, color: Colors.blue, size: 40),
                          ),
                        ),
                        // Ghim vị trí người dùng (chỉ khi có tọa độ thật)
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 50,
                            height: 50,
                            child: const Tooltip(
                              message: 'Vị trí GPS thực tế của bạn',
                              child: Icon(Icons.location_on, color: Colors.red, size: 45),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Khung thông tin tọa độ & các nút hành động
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red[900], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          children: [
                            Icon(Icons.pin_drop_rounded, color: Colors.teal[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _address,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_distanceToCompany != null)
                          Text(
                            'Khoảng cách đến cơ sở: ${_distanceToCompany!.toStringAsFixed(1)} m',
                            style: TextStyle(
                              color: _distanceToCompany! <= 300 ? Colors.green[800] : Colors.orange[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_isLoading || _currentPosition == null) ? null : _shareLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.share_location_rounded),
                                label: const Text('Chia sẻ vị trí'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_isLoading || _currentPosition == null || _isSubmitting)
                                    ? null
                                    : _showAttendanceOptions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.fingerprint_rounded),
                                label: const Text('Điểm danh GPS'),
                              ),
                            ),
                          ],
                        ),
                        if (_currentPosition == null && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextButton.icon(
                              onPressed: _fetchLocation,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại việc lấy vị trí GPS'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isLoading || _isSubmitting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _isLoading
                              ? 'Đang kết nối vệ tinh GPS...'
                              : 'Đang gửi dữ liệu chấm công tới máy chủ...',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
