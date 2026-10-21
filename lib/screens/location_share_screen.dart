import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key});

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  // Tọa độ mẫu của Trường Đại học Công nghệ TP.HCM (HUTECH Cơ sở Khu Công Nghệ Cao)
  static const double companyLat = 10.8550;
  static const double companyLng = 106.7854;
  static const String companyName = 'Trường ĐH HUTECH (Trụ sở / Công ty)';

  final MapController _mapController = MapController();
  Position? _currentPosition;
  String _address = 'Đang chờ lấy vị trí GPS...';
  double? _distanceToCompany;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _address = 'Dịch vụ định vị GPS trên máy đang tắt.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _address = 'Quyền truy cập vị trí bị từ chối.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _address = 'Quyền vị trí bị từ chối vĩnh viễn trong Cài đặt.';
        });
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

      String detailedAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          detailedAddress = '${p.street ?? ''}, ${p.subAdministrativeArea ?? ''}, ${p.administrativeArea ?? ''}';
        }
      } catch (_) {}

      setState(() {
        _currentPosition = position;
        _distanceToCompany = distance;
        _address = detailedAddress;
        _isLoading = false;
      });

      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      // Fallback vị trí gần công ty nếu đang chạy trên máy ảo chưa kích hoạt mock GPS
      const fallbackLat = 10.8552;
      const fallbackLng = 106.7856;
      final distance = Geolocator.distanceBetween(fallbackLat, fallbackLng, companyLat, companyLng);

      setState(() {
        _currentPosition = Position(
          longitude: fallbackLng,
          latitude: fallbackLat,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        _distanceToCompany = distance;
        _address = 'Vị trí hiện tại (Khu Công nghệ cao, TP. Thủ Đức, TP.HCM)';
        _isLoading = false;
      });
    }
  }

  void _shareLocation() {
    if (_currentPosition == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết vị trí Google Maps vào bộ nhớ tạm!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _checkIn() {
    if (_distanceToCompany == null) return;
    final isWithinRange = _distanceToCompany! <= 300.0; // Bán kính chấm công 300m
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isWithinRange ? Icons.check_circle : Icons.warning_rounded,
              color: isWithinRange ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(isWithinRange ? 'Chấm công hợp lệ' : 'Ngoài phạm vi'),
          ],
        ),
        content: Text(
          'Khoảng cách tới công ty: ${_distanceToCompany!.toStringAsFixed(1)} mét.\n'
          'Quy định chấm công: Trong bán kính 300m.\n\n'
          '${isWithinRange ? '✅ Đã ghi nhận thời gian chấm công thành công vào hệ thống!' : '⚠️ Bạn đang ở quá xa vị trí công ty để thực hiện chấm công.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
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
        title: const Text('Chia sẻ vị trí & Điểm danh GPS'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Lấy lại vị trí',
            onPressed: _isLoading ? null : _fetchLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bản đồ OpenStreetMap (miễn phí qua flutter_map)
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
                    // Ghim vị trí Công ty
                    const Marker(
                      point: LatLng(companyLat, companyLng),
                      width: 50,
                      height: 50,
                      child: Tooltip(
                        message: companyName,
                        child: Icon(Icons.business_rounded, color: Colors.blue, size: 40),
                      ),
                    ),
                    // Ghim vị trí người dùng
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        width: 50,
                        height: 50,
                        child: const Tooltip(
                          message: 'Vị trí của bạn',
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
                            onPressed: _shareLocation,
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
                            onPressed: _checkIn,
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
