import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/attendance_service.dart';
import '../utils/auth.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 1: Quản lý chấm công nhân viên
  List<AttendanceRecord> _attendances = [];
  bool _isLoadingAttendances = false;
  String? _attendanceErrorMessage;
  DateTime? _selectedDateFilter;
  String _selectedStatusFilter = 'ALL'; // ALL, IN_PROGRESS, COMPLETED, GPS, QR
  final TextEditingController _searchStaffController = TextEditingController();

  // Tab 2: Quản lý nhân viên công ty
  List<Employee> _employees = [];
  bool _isLoadingEmployees = false;
  String? _employeeErrorMessage;
  final TextEditingController _searchEmployeeController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchAttendances();
    _fetchEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchStaffController.dispose();
    _searchEmployeeController.dispose();
    super.dispose();
  }

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
      if (_selectedStatusFilter == 'GPS' &&
          !(record.method ?? '').toUpperCase().contains('GPS')) {
        return false;
      }
      if (_selectedStatusFilter == 'QR' &&
          !(record.method ?? '').toUpperCase().contains('QR')) {
        return false;
      }

      // 3. Lọc theo tên hoặc mã nhân viên
      final query = _searchStaffController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final userId = (record.userId ?? '').toLowerCase();
        final userName = (record.userName ?? '').toLowerCase();
        final notes = (record.notes ?? '').toLowerCase();
        final loc = (record.locationName ?? '').toLowerCase();
        if (!userId.contains(query) &&
            !userName.contains(query) &&
            !notes.contains(query) &&
            !loc.contains(query)) {
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

  // --- ĐIỀU CHỈNH BẢN GHI CHẤM CÔNG (PUT /api/Attendance/{id}) ---
  void _showEditAttendanceDialog(AttendanceRecord record) {
    DateTime? checkIn = record.checkInTime;
    DateTime? checkOut = record.checkOutTime;
    String status = record.status ?? 'VALID';
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('Điều chỉnh Chấm công #${record.id}')),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhân viên: ${record.userName ?? record.userId ?? "Nhân viên"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Giờ Check-in
                    Row(
                      children: [
                        const Expanded(child: Text('Giờ vào ca (Check-in):')),
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: checkIn ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date == null) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                checkIn ?? DateTime.now(),
                              ),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              checkIn = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            checkIn != null
                                ? '${checkIn!.hour.toString().padLeft(2, '0')}:${checkIn!.minute.toString().padLeft(2, '0')} ${checkIn!.day}/${checkIn!.month}'
                                : 'Chọn giờ',
                          ),
                        ),
                      ],
                    ),

                    // Giờ Check-out
                    Row(
                      children: [
                        const Expanded(child: Text('Giờ ra ca (Check-out):')),
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: checkOut ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date == null) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                checkOut ?? DateTime.now(),
                              ),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              checkOut = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            checkOut != null
                                ? '${checkOut!.hour.toString().padLeft(2, '0')}:${checkOut!.minute.toString().padLeft(2, '0')} ${checkOut!.day}/${checkOut!.month}'
                                : 'Chưa ra ca (bấm để thêm)',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    // Dropdown Trạng thái
                    const Text('Trạng thái bản ghi:'),
                    DropdownButtonFormField<String>(
                      value:
                          [
                            'VALID',
                            'ON_TIME',
                            'LATE',
                            'MANUAL_EDIT',
                            'EXCUSED',
                          ].contains(status)
                          ? status
                          : 'VALID',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'VALID',
                          child: Text('Hợp lệ (VALID)'),
                        ),
                        DropdownMenuItem(
                          value: 'ON_TIME',
                          child: Text('Đúng giờ (ON_TIME)'),
                        ),
                        DropdownMenuItem(
                          value: 'LATE',
                          child: Text('Đi trễ (LATE)'),
                        ),
                        DropdownMenuItem(
                          value: 'MANUAL_EDIT',
                          child: Text('Điều chỉnh thủ công (MANUAL_EDIT)'),
                        ),
                        DropdownMenuItem(
                          value: 'EXCUSED',
                          child: Text('Có phép (EXCUSED)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),

                    const SizedBox(height: 14),
                    // BẮT BUỘC: Lý do điều chỉnh
                    TextFormField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Lý do điều chỉnh (BẮT BUỘC) *',
                        hintText:
                            'VD: Nhân viên quên bấm nút, sửa theo giấy xác nhận...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bắt buộc nhập lý do điều chỉnh để lưu vết kiểm toán!';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.pop(ctx);
                  await _executeUpdateAttendance(
                    record.id,
                    checkInTime: checkIn,
                    checkOutTime: checkOut,
                    status: status,
                    reason: reasonController.text.trim(),
                  );
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Lưu điều chỉnh'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeUpdateAttendance(
    dynamic id, {
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? status,
    required String reason,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await AttendanceService.instance.updateAttendance(
      id,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      status: status,
      reason: reason,
    );

    if (!mounted) return;
    Navigator.pop(context); // Tắt loading

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );
      await _fetchAttendances();
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Điều chỉnh thất bại'),
            ],
          ),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  // --- XÓA BẢN GHI CHẤM CÔNG (DELETE /api/Attendance/{id}) ---
  void _showDeleteAttendanceDialog(AttendanceRecord record) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa chấm công'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có chắc chắn muốn xóa bản ghi chấm công #${record.id} của nhân viên "${record.userName ?? record.userId}"?',
              ),
              const SizedBox(height: 6),
              Text(
                'Thời gian: ${record.formattedCheckIn} - ${record.formattedCheckOut}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Lý do xóa bản ghi (BẮT BUỘC) *',
                  hintText:
                      'VD: Bản ghi trùng lặp, ca làm bị hủy theo yêu cầu...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bắt buộc nhập lý do xóa bản ghi!';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx);
              await _executeDeleteAttendance(
                record.id,
                reasonController.text.trim(),
              );
            },
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAttendance(dynamic id, String reason) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await AttendanceService.instance.deleteAttendance(
      id,
      reason: reason,
    );

    if (!mounted) return;
    Navigator.pop(context); // Tắt loading

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );
      await _fetchAttendances();
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Xóa thất bại'),
            ],
          ),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  // ============================================================================
  // TAB 3: QUẢN LÝ NHÂN VIÊN & CẤP QUYỀN (GET /api/Admin/employees)
  // ============================================================================

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoadingEmployees = true;
      _employeeErrorMessage = null;
    });

    try {
      final list = await AttendanceService.instance.getEmployees();
      if (!mounted) return;

      setState(() {
        _employees = list;
        _isLoadingEmployees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _employeeErrorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingEmployees = false;
      });
    }
  }

  List<Employee> get _filteredEmployees {
    final q = _searchEmployeeController.text.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees.where((e) {
      return e.userName.toLowerCase().contains(q) ||
          (e.email ?? '').toLowerCase().contains(q) ||
          e.role.toLowerCase().contains(q);
    }).toList();
  }

  void _showChangeRoleDialog(Employee employee) {
    String selectedRole = employee.role;
    final roles = ['Admin', 'Staff', 'User'];
    if (!roles.contains(selectedRole)) {
      roles.add(selectedRole);
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('Đổi vai trò: ${employee.userName}')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tên đăng nhập: ${employee.userName}'),
                if (employee.email != null) Text('Email: ${employee.email}'),
                const SizedBox(height: 12),
                const Text('Chọn vai trò mới cho người dùng:'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Lưu ý: Quyền Admin có toàn quyền quản trị danh mục, nhân viên và dữ liệu chấm công. '
                  'Quyền Staff có quyền truy cập Dashboard nhân viên.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _executeUpdateRole(employee.id, selectedRole);
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Cập nhật vai trò'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeUpdateRole(String employeeId, String newRole) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await AttendanceService.instance.updateEmployeeRole(
      employeeId,
      newRole,
    );

    if (!mounted) return;
    Navigator.pop(context); // Tắt loading

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );
      await _fetchEmployees();
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Cập nhật vai trò thất bại'),
            ],
          ),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  // Đăng xuất khỏi hệ thống
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất tài khoản Quản trị viên?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.white),
            ),
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
                _fetchAttendances();
              } else {
                _fetchEmployees();
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
            Tab(
              icon: Icon(Icons.assignment_turned_in_rounded),
              text: 'Chấm công Nhân viên',
            ),
            Tab(
              icon: Icon(Icons.people_alt_rounded),
              text: 'Quản lý Nhân viên',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAttendancesTab(), _buildEmployeesTab()],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        onPressed: _fetchAttendances,
        backgroundColor: Colors.blue[800],
        icon: const Icon(Icons.sync, color: Colors.white),
        label: const Text(
          'Tải lại chấm công',
          style: TextStyle(color: Colors.white),
        ),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: _fetchEmployees,
        backgroundColor: Colors.blue[800],
        icon: const Icon(Icons.people, color: Colors.white),
        label: const Text(
          'Tải lại DS Nhân viên',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
  }

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
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
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
                      backgroundColor: _selectedDateFilter != null
                          ? Colors.blue[100]
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _selectedDateFilter != null
                          ? Colors.blue[800]
                          : Colors.black87,
                    ),
                    label: Text(
                      _selectedDateFilter != null
                          ? '${_selectedDateFilter!.day}/${_selectedDateFilter!.month}/${_selectedDateFilter!.year}'
                          : 'Tất cả các ngày',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedDateFilter != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedDateFilter != null
                            ? Colors.blue[900]
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (_selectedDateFilter != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: 'Xóa lọc ngày',
                      onPressed: () =>
                          setState(() => _selectedDateFilter = null),
                    ),
                  ],
                  const Spacer(),
                  // Dropdown lọc trạng thái
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Text(
                          'Tất cả trạng thái',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text(
                          'Đang trong ca',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('Đã ra ca', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'GPS',
                        child: Text(
                          'Điểm danh GPS',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'QR',
                        child: Text(
                          'Điểm danh QR',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatusFilter = val);
                      }
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
              _buildStatBadge(
                'Đang trực',
                '$inProgressCount ca',
                Colors.orange,
              ),
              _buildStatBadge(
                'Đã hoàn thành',
                '$completedCount ca',
                Colors.green,
              ),
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
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
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
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
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
        Text(
          value,
          style: TextStyle(
            color: color[800],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
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

    final staffName = record.userName ?? record.userId ?? 'Nhân viên';
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Phương thức: $method • Mã #${record.id}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isDone ? Colors.blue : Colors.orange).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDone ? Colors.blue : Colors.orange,
                    ),
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
                      const Text(
                        'Giờ vào ca (Check-in):',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      Text(
                        record.formattedCheckIn,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Giờ ra ca (Check-out):',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      Text(
                        record.formattedCheckOut,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (record.locationName != null &&
                record.locationName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.pin_drop_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Địa điểm: ${record.locationName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
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
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const Divider(height: 18),
            // Nút "Điều chỉnh" và "Xóa" (BẮT BUỘC NHẬP LÝ DO - reason)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditAttendanceDialog(record),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[800],
                    side: BorderSide(color: Colors.blue[300]!),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text(
                    'Điều chỉnh',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showDeleteAttendanceDialog(record),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[800],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Xóa', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // GIAO DIỆN TAB 3: QUẢN LÝ NHÂN VIÊN (GET /api/Admin/employees)
  // ============================================================================
  Widget _buildEmployeesTab() {
    final filtered = _filteredEmployees;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue[50],
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[800],
                    child: const Icon(Icons.people_alt, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quản lý Nhân viên & Phân quyền',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Cấp quyền và đổi vai trò người dùng (API: /api/Admin/employees)',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchEmployeeController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên nhân viên, email hoặc vai trò...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchEmployeeController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchEmployeeController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingEmployees
              ? const Center(child: CircularProgressIndicator())
              : _employeeErrorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không thể tải danh sách nhân viên:\n$_employeeErrorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchEmployees,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
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
                      Icon(Icons.person_off, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Chưa có nhân viên nào trong danh sách.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchEmployees,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final emp = filtered[index];
                      return _buildEmployeeCard(emp);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    Color roleColor = Colors.blue;
    if (emp.role.toUpperCase() == 'ADMIN') {
      roleColor = Colors.deepPurple;
    } else if (emp.role.toUpperCase() == 'STAFF') {
      roleColor = Colors.teal;
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          foregroundColor: roleColor,
          child: Text(
            emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : 'U',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(
              emp.userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: roleColor),
              ),
              child: Text(
                emp.role,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (emp.email != null && emp.email!.isNotEmpty)
              Text(
                'Email: ${emp.email}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            Text(
              'ID: ${emp.id}',
              style: const TextStyle(color: Colors.black38, fontSize: 11),
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _showChangeRoleDialog(emp),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            foregroundColor: Colors.blue[900],
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
          label: const Text('Đổi vai trò', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
