import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/api_client.dart';
import '../services/attendance_service.dart';
import '../utils/auth.dart';
import 'login_screen.dart';

class CategoryItem {
  final int id;
  final String name;

  CategoryItem({required this.id, required this.name});

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['categoryId'] ?? json['Id'] ?? 0;
    final int parsedId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
    final String parsedName =
        (json['name'] ?? json['categoryName'] ?? json['Name'] ?? json['title'] ?? '').toString();
    return CategoryItem(id: parsedId, name: parsedName);
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ApiClient _apiClient = ApiClient();

  // Tab 1: Quản lý danh mục
  List<CategoryItem> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoryErrorMessage;

  // Tab 2: Quản lý chấm công nhân viên
  List<AttendanceRecord> _attendances = [];
  bool _isLoadingAttendances = false;
  String? _attendanceErrorMessage;
  DateTime? _selectedDateFilter;
  String _selectedStatusFilter = 'ALL'; // ALL, IN_PROGRESS, COMPLETED, GPS, QR
  final TextEditingController _searchStaffController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchCategories();
    _fetchAttendances();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchStaffController.dispose();
    super.dispose();
  }

  // ============================================================================
  // TAB 1: DANH MỤC SẢN PHẨM (CRUD)
  // ============================================================================

  // Lấy danh sách danh mục từ API: GET /api/Categories
  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryErrorMessage = null;
    });

    try {
      final response = await _apiClient.get('Categories');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded['categories'] is List) {
            list = decoded['categories'];
          }
        }

        final items = list
            .whereType<Map<String, dynamic>>()
            .map((item) => CategoryItem.fromJson(item))
            .toList();

        if (mounted) {
          setState(() {
            _categories = items;
            _isLoadingCategories = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _categoryErrorMessage = 'Lỗi tải danh mục: mã ${response.statusCode}';
            _isLoadingCategories = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoryErrorMessage = 'Lỗi kết nối máy chủ: $e';
          _isLoadingCategories = false;
        });
      }
    }
  }

  // Thêm danh mục mới: POST /api/Categories
  Future<void> _createCategory(String name) async {
    if (name.trim().isEmpty) return;
    try {
      final response = await _apiClient.post(
        'Categories',
        body: {
          'name': name.trim(),
          'categoryName': name.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm danh mục mới thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchCategories();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thêm thất bại (mã ${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Sửa tên danh mục: PUT /api/Categories/{id}
  Future<void> _updateCategory(int id, String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      final response = await _apiClient.put(
        'Categories/$id',
        body: {
          'id': id,
          'name': newName.trim(),
          'categoryName': newName.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật tên danh mục thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchCategories();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cập nhật thất bại (mã ${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Xóa danh mục: DELETE /api/Categories/{id}
  Future<void> _deleteCategory(int id, String name) async {
    try {
      final response = await _apiClient.delete('Categories/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa danh mục "$name"! Các sản phẩm đã được tách khỏi danh mục.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchCategories();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xóa thất bại (mã ${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDeleteCategory(CategoryItem category) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa danh mục "${category.name}"?\n\n'
          'Lưu ý: Các sản phẩm thuộc danh mục này sẽ KHÔNG bị xóa mà sẽ chuyển thành không thuộc danh mục nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCategory(category.id, category.name);
            },
            child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm danh mục mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            hintText: 'Nhập tên danh mục (VD: Đồ điện tử, Sách...)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _createCategory(text);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(CategoryItem category) {
    final controller = TextEditingController(text: category.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa danh mục #${category.id}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục mới',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _updateCategory(category.id, text);
              }
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: QUẢN LÝ CHẤM CÔNG TOÀN BỘ NHÂN VIÊN (GET /api/Attendance/all)
  // ============================================================================

  Future<void> _fetchAttendances() async {
    setState(() {
      _isLoadingAttendances = true;
      _attendanceErrorMessage = null;
    });

    try {
      final list = await AttendanceService.instance.getAllAttendances();
      if (!mounted) return;

      list.sort((a, b) {
        final aTime = a.checkInTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.checkInTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _attendances = list;
        _isLoadingAttendances = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attendanceErrorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingAttendances = false;
      });
    }
  }

  List<AttendanceRecord> get _filteredAttendances {
    return _attendances.where((record) {
      // 1. Lọc theo ngày
      if (_selectedDateFilter != null && record.checkInTime != null) {
        final date = record.checkInTime!;
        if (date.year != _selectedDateFilter!.year ||
            date.month != _selectedDateFilter!.month ||
            date.day != _selectedDateFilter!.day) {
          return false;
        }
      }

      // 2. Lọc theo trạng thái / phương thức
      if (_selectedStatusFilter == 'IN_PROGRESS' && record.isCompleted) {
        return false;
      }
      if (_selectedStatusFilter == 'COMPLETED' && !record.isCompleted) {
        return false;
      }
      if (_selectedStatusFilter == 'GPS' && !(record.method ?? '').toUpperCase().contains('GPS')) {
        return false;
      }
      if (_selectedStatusFilter == 'QR' && !(record.method ?? '').toUpperCase().contains('QR')) {
        return false;
      }

      // 3. Lọc theo tên hoặc mã nhân viên
      final query = _searchStaffController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final userId = (record.userId ?? '').toLowerCase();
        final notes = (record.notes ?? '').toLowerCase();
        final loc = (record.locationName ?? '').toLowerCase();
        if (!userId.contains(query) && !notes.contains(query) && !loc.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _selectFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'CHỌN NGÀY CẦN XEM CHẤM CÔNG',
    );
    if (picked != null) {
      setState(() => _selectedDateFilter = picked);
    }
  }

  // Đăng xuất khỏi hệ thống
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản Quản trị viên?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Auth.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () {
              if (_tabController.index == 0) {
                _fetchCategories();
              } else {
                _fetchAttendances();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(icon: Icon(Icons.category_rounded), text: 'Danh mục Sản phẩm'),
            Tab(icon: Icon(Icons.assignment_turned_in_rounded), text: 'Chấm công Nhân viên'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(),
          _buildAttendancesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddCategoryDialog,
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Thêm danh mục', style: TextStyle(color: Colors.white)),
            )
          : FloatingActionButton.extended(
              onPressed: _fetchAttendances,
              backgroundColor: Colors.blue[800],
              icon: const Icon(Icons.sync, color: Colors.white),
              label: const Text('Tải lại chấm công', style: TextStyle(color: Colors.white)),
            ),
    );
  }

  // ============================================================================
  // GIAO DIỆN TAB 1: DANH MỤC SẢN PHẨM
  // ============================================================================
  Widget _buildCategoriesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue[50],
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[800],
                child: const Icon(Icons.admin_panel_settings, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quản lý Danh mục sản phẩm (CRUD)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Quyền Quản trị viên (Admin) • Tổng: ${_categories.length} danh mục',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : _categoryErrorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              _categoryErrorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchCategories,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có danh mục nào.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _showAddCategoryDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Thêm danh mục ngay'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _categories.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  '#${cat.id}',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              subtitle: Text('Mã danh mục: ${cat.id}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Sửa tên',
                                    onPressed: () => _showEditCategoryDialog(cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Xóa danh mục',
                                    onPressed: () => _confirmDeleteCategory(cat),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  // ============================================================================
  // GIAO DIỆN TAB 2: QUẢN LÝ CHẤM CÔNG TOÀN BỘ NHÂN VIÊN
  // ============================================================================
  Widget _buildAttendancesTab() {
    final filtered = _filteredAttendances;
    final totalCount = filtered.length;
    final inProgressCount = filtered.where((r) => !r.isCompleted).length;
    final completedCount = filtered.where((r) => r.isCompleted).length;

    return Column(
      children: [
        // Khung điều khiển Bộ lọc (Filter by date & status & search)
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue[50],
          child: Column(
            children: [
              // Ô tìm kiếm nhân viên
              TextField(
                controller: _searchStaffController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên nhân viên, vị trí hoặc ghi chú...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchStaffController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchStaffController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              // Dòng chọn ngày và chip trạng thái
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _selectFilterDate,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedDateFilter != null ? Colors.blue[100] : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _selectedDateFilter != null ? Colors.blue[800] : Colors.black87,
                    ),
                    label: Text(
                      _selectedDateFilter != null
                          ? '${_selectedDateFilter!.day}/${_selectedDateFilter!.month}/${_selectedDateFilter!.year}'
                          : 'Tất cả các ngày',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedDateFilter != null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedDateFilter != null ? Colors.blue[900] : Colors.black87,
                      ),
                    ),
                  ),
                  if (_selectedDateFilter != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      tooltip: 'Xóa lọc ngày',
                      onPressed: () => setState(() => _selectedDateFilter = null),
                    ),
                  ],
                  const Spacer(),
                  // Dropdown lọc trạng thái
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Đang trong ca', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Đã ra ca', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'GPS', child: Text('Điểm danh GPS', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'QR', child: Text('Điểm danh QR', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatusFilter = val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Thanh tóm tắt số liệu
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge('Tổng cộng', '$totalCount lượt', Colors.blue),
              _buildStatBadge('Đang trực', '$inProgressCount ca', Colors.orange),
              _buildStatBadge('Đã hoàn thành', '$completedCount ca', Colors.green),
            ],
          ),
        ),
        const Divider(height: 1),

        // Danh sách chấm công
        Expanded(
          child: _isLoadingAttendances
              ? const Center(child: CircularProgressIndicator())
              : _attendanceErrorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              'Không thể tải dữ liệu chấm công từ SQL Server:\n$_attendanceErrorMessage',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchAttendances,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tải lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Không tìm thấy lượt chấm công nào phù hợp bộ lọc.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchAttendances,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final record = filtered[index];
                              return _buildAttendanceCard(record);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, String value, MaterialColor color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color[800], fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final method = (record.method ?? 'MANUAL').toUpperCase();
    IconData methodIcon = Icons.badge;
    Color methodColor = Colors.teal;
    if (method.contains('GPS')) {
      methodIcon = Icons.location_on;
      methodColor = Colors.green;
    } else if (method.contains('QR')) {
      methodIcon = Icons.qr_code;
      methodColor = Colors.purple;
    }

    final staffName = record.userId ?? 'Nhân viên';
    final isDone = record.isCompleted;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: methodColor.withValues(alpha: 0.15),
                  child: Icon(methodIcon, color: methodColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Phương thức: $method',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDone ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDone ? Colors.blue : Colors.orange),
                  ),
                  child: Text(
                    isDone ? 'Hoàn thành' : 'Đang trong ca',
                    style: TextStyle(
                      color: isDone ? Colors.blue[900] : Colors.orange[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giờ vào ca (Check-in):', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(record.formattedCheckIn, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giờ ra ca (Check-out):', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(record.formattedCheckOut, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: Colors.blue[700]),
                const SizedBox(width: 4),
                Text(
                  'Tổng giờ làm: ${record.durationText}',
                  style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            if (record.locationName != null && record.locationName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.pin_drop_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Địa điểm: ${record.locationName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (record.latitude != null && record.longitude != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.my_location, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Tọa độ: ${record.latitude!.toStringAsFixed(4)}, ${record.longitude!.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ghi chú: ${record.notes}',
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
