import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_provider.dart';
import '../shared/api_endpoint.dart';

/// Scrollable body for the app's shared Scaffold.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _endpointController;
  bool _savingEndpoint = false;
  bool _savingTheme = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize once: a theme/provider rebuild must not discard pending edits.
    _endpointController ??= TextEditingController(
      text: context.read<SettingsProvider>().endpoint,
    );
  }

  @override
  void dispose() {
    _endpointController?.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveEndpoint() async {
    if (_savingEndpoint || !_formKey.currentState!.validate()) return;
    final settings = context.read<SettingsProvider>();
    final draft = _endpointController!.text;
    setState(() => _savingEndpoint = true);
    try {
      await settings.setEndpoint(draft);
      if (!mounted) return;
      _endpointController!.text = settings.endpoint;
      _showMessage('Đã lưu địa chỉ API.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _savingEndpoint = false);
    }
  }

  Future<void> _saveTheme(bool value) async {
    if (_savingTheme) return;
    final settings = context.read<SettingsProvider>();
    setState(() => _savingTheme = true);
    try {
      await settings.setDarkMode(value);
      _showMessage('Đã lưu giao diện.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Giao diện', style: textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Giao diện tối'),
          subtitle: Text(
            _savingTheme ? 'Đang lưu giao diện...' : 'Lưu trên thiết bị',
          ),
          value: settings.darkMode,
          onChanged: _savingTheme ? null : _saveTheme,
        ),
        const Divider(height: 32),
        Text('Nguồn bài viết', style: textTheme.titleLarge),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _endpointController,
            enabled: !_savingEndpoint,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ API bài viết',
              hintText: 'https://may-chu.example/api/posts',
              border: OutlineInputBorder(),
              errorMaxLines: 4,
            ),
            validator: SettingsProvider.validateEndpoint,
            onFieldSubmitted: (_) => _saveEndpoint(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _savingEndpoint ? null : _saveEndpoint,
              icon: _savingEndpoint
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_savingEndpoint ? 'Đang lưu...' : 'Lưu địa chỉ API'),
            ),
            OutlinedButton(
              onPressed: _savingEndpoint
                  ? null
                  : () {
                      _endpointController!.text = emulatorPostsEndpoint;
                      _saveEndpoint();
                    },
              child: const Text('Backend máy ảo'),
            ),
            OutlinedButton(
              onPressed: _savingEndpoint
                  ? null
                  : () {
                      _formKey.currentState?.reset();
                      _endpointController!.text =
                          SettingsProvider.defaultEndpoint;
                    },
              child: const Text('Dùng địa chỉ mặc định'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Dùng HTTPS cho URL Conveyor. Backend chạy trên máy tính có thể '
          'kết nối từ máy ảo bằng nút Backend máy ảo bên trên. '
          'Khi lưu, ứng dụng tải lại bài viết và sản phẩm từ cùng backend.',
        ),
        const SizedBox(height: 12),
        const Text(
          'API cần trả về một danh sách JSON; mỗi bài có id, userId, title và body. '
          'Địa chỉ Conveyor cần kèm đường dẫn API. '
          'Bài yêu thích được lưu đầy đủ để đọc khi không có mạng; '
          'mỗi nguồn API và dữ liệu mẫu có danh sách yêu thích riêng.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Backend máy ảo: http://10.0.2.2:5186/api/posts. '
          'Mở backend trong Visual Studio và chạy trước khi kết nối. '
          'Địa chỉ mặc định JSONPlaceholder chỉ dùng luyện đọc dữ liệu; '
          'chọn backend của bạn để thêm, sửa, xóa và tìm sản phẩm.',
        ),
      ],
    );
  }
}
