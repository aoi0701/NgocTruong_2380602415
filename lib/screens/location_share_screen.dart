import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key});

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  // Tọa độ mặc định khi chưa có GPS (TP.HCM)
  static const double defaultLat = 10.8231;
  static const double defaultLng = 106.6297;

  final MapController _mapController = MapController();
  Position? _currentPosition;
  String _address = 'Đang chờ lấy vị trí GPS thực tế...';
  String? _errorMessage;
  bool _isLoading = false;

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
              _errorMessage = 'Quyền truy cập vị trí bị từ chối. Vui lòng cấp quyền để sử dụng chức năng này.';
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
          _errorMessage = 'Lỗi lấy tọa độ GPS thực tế: $e\nVui lòng kiểm tra kết nối mạng và thiết bị GPS.';
          _address = 'Lỗi định vị';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng lấy vị trí hiện tại trước khi chia sẻ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final shareText = 'Vị trí hiện tại của tôi\n$mapUrl';

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Vị trí hiện tại của tôi',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // Người dùng đóng bảng chia sẻ hoặc huỷ mà không gửi -> không báo lỗi
    }
  }

  Future<void> _openGoogleMaps() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng lấy vị trí hiện tại trước khi mở bản đồ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(mapUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: mapUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở ứng dụng bản đồ, đã sao chép link')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: mapUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép liên kết Google Maps vào bộ nhớ tạm!')),
        );
      }
    }
  }

  void _copyMapLink() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng lấy vị trí hiện tại trước khi sao chép link'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    Clipboard.setData(ClipboardData(text: mapUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết Google Maps vào bộ nhớ tạm!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(defaultLat, defaultLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ vị trí'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Lấy lại vị trí GPS',
            onPressed: _isLoading ? null : _fetchLocation,
          ),
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn chia sẻ vị trí',
            onSelected: (value) {
              if (value == 'share') {
                _shareLocation();
              } else if (value == 'maps') {
                _openGoogleMaps();
              } else if (value == 'copy') {
                _copyMapLink();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share, color: Colors.teal),
                  title: Text('Chia sẻ vị trí (Hệ thống)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'maps',
                child: ListTile(
                  leading: Icon(Icons.map, color: Colors.blue),
                  title: Text('Mở trên Google Maps'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy, color: Colors.teal),
                  title: Text('Sao chép liên kết Google Maps'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
                        // Ghim vị trí người dùng (khi có tọa độ thật)
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 50,
                            height: 50,
                            child: const Tooltip(
                              message: 'Vị trí hiện tại của bạn',
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
                        const SizedBox(height: 16),

                        // Các tùy chọn mở bản đồ và sao chép link
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _openGoogleMaps,
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text('Mở Google Maps', style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _copyMapLink,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Sao chép link', style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _shareLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.share_location_rounded),
                          label: const Text(
                            'Chia sẻ vị trí',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),

                        if (_currentPosition == null && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
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

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Đang kết nối vệ tinh GPS...',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
