import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import '../config/config_url.dart';
import '../models/productPost.dart';
import '../services/api_client.dart';
import 'biometric_qr_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final ApiClient _apiClient = ApiClient(baseUrl: Config_URL.baseUrl);
  final TextEditingController _searchController = TextEditingController();
  late Future<List<productPost>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Gọi GET đến ${Config_URL.baseUrl}ProductApi (kèm query ?name=search nếu có)
  /// Có hỗ trợ fallback sang endpoint 'products' nếu backend dùng ProductsController
  Future<List<productPost>> fetchPosts({String? search}) async {
    String query = (search != null && search.trim().isNotEmpty)
        ? '?name=${Uri.encodeQueryComponent(search.trim())}'
        : '';

    http.Response response = await _apiClient.get('ProductApi$query');
    if (response.statusCode == 404) {
      response = await _apiClient.get('products$query');
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data
          .map((item) => productPost.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }

  void _reload({String? search}) {
    setState(() {
      _productsFuture = fetchPosts(search: search);
    });
  }

  void _onSearch(String value) {
    _reload(search: value);
  }

  // --- Chức năng: Tìm kiếm chi tiết theo ID ---
  Future<void> _searchByIdDialog() async {
    final idController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tìm sản phẩm theo ID'),
        content: TextField(
          controller: idController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nhập ID sản phẩm',
            hintText: 'Ví dụ: 1',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final idText = idController.text.trim();
              if (idText.isEmpty) return;
              final id = int.tryParse(idText);
              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID phải là số nguyên')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _fetchAndShowProductById(id);
            },
            child: const Text('Tìm'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAndShowProductById(int id) async {
    try {
      http.Response response = await _apiClient.get('ProductApi/$id');
      if (response.statusCode == 404) {
        response = await _apiClient.get('products/$id');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        final product = productPost.fromJson(data);
        if (mounted) {
          _showProductDetails(product);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không tìm thấy sản phẩm với ID $id'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải sản phẩm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Chức năng: Xem chi tiết sản phẩm ---
  void _showProductDetails(productPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          post.name ?? 'Chi tiết sản phẩm',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.image != null && post.image!.trim().startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post.image!.trim(),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Mã sản phẩm (ID): ${post.id ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Giá bán: ${post.price ?? 0} VND',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              if (post.categoryName != null || post.categoryId != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Danh mục: ${post.categoryName ?? 'Mã ${post.categoryId}'}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Mô tả chi tiết:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                post.description ?? 'Chưa có mô tả cho sản phẩm này.',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showProductQrCodeDialog(post);
            },
            icon: const Icon(Icons.qr_code, color: Colors.purple),
            label: const Text('Mã QR'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditProductDialog(post);
            },
            icon: const Icon(Icons.edit, color: Colors.blue),
            label: const Text('Sửa'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteProduct(post);
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // --- Chức năng: Xem mã QR nhận diện sản phẩm ---
  void _showProductQrCodeDialog(productPost post) {
    final qrData = 'PRODUCT:${post.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mã QR: ${post.name ?? "Sản phẩm"}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mã định danh: $qrData',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const SizedBox(height: 6),
            const Text(
              'Quét mã này bằng chức năng Nhận diện QR của ứng dụng để mở trực tiếp chi tiết sản phẩm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // --- Chức năng: Thêm sản phẩm mới (POST) ---
  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final imageController = TextEditingController();
    final descController = TextEditingController();
    final catController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm sản phẩm mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm (*)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Giá bán (VND) (*)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả sản phẩm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                  labelText: 'URL hình ảnh (tùy chọn)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mã danh mục (CategoryId - tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final priceText = priceController.text.trim();
              final desc = descController.text.trim();
              final img = imageController.text.trim();
              final catText = catController.text.trim();

              if (name.isEmpty || priceText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập tên và giá sản phẩm'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final price = double.tryParse(priceText);
              if (price == null || price < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Giá sản phẩm không hợp lệ'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final Map<String, dynamic> body = {
                'name': name,
                'price': price,
                'description': desc.isNotEmpty ? desc : 'Chưa có mô tả',
                'image': img.isNotEmpty
                    ? img
                    : 'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg',
              };
              if (catText.isNotEmpty && int.tryParse(catText) != null) {
                body['categoryId'] = int.parse(catText);
              }

              Navigator.pop(ctx);
              await _createProduct(body);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProduct(Map<String, dynamic> body) async {
    try {
      http.Response response = await _apiClient.post('ProductApi', body: body);
      if (response.statusCode == 404) {
        response = await _apiClient.post('products', body: body);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm sản phẩm thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _reload(search: _searchController.text);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi thêm sản phẩm: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể kết nối đến máy chủ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Chức năng: Sửa sản phẩm (PUT) ---
  void _showEditProductDialog(productPost post) {
    final nameController = TextEditingController(text: post.name ?? '');
    final priceController =
        TextEditingController(text: post.price != null ? '${post.price}' : '');
    final descController =
        TextEditingController(text: post.description ?? '');
    final imageController =
        TextEditingController(text: post.image ?? '');
    final catController = TextEditingController(
        text: post.categoryId != null ? '${post.categoryId}' : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa sản phẩm #${post.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm (*)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Giá bán (VND) (*)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                  labelText: 'URL hình ảnh',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mã danh mục (CategoryId)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final priceText = priceController.text.trim();
              final desc = descController.text.trim();
              final img = imageController.text.trim();
              final catText = catController.text.trim();

              if (name.isEmpty || priceText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập tên và giá sản phẩm'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final price = double.tryParse(priceText);
              if (price == null || price < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Giá sản phẩm không hợp lệ'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final Map<String, dynamic> body = {
                'id': post.id,
                'name': name,
                'price': price,
                'description': desc,
                'image': img,
              };
              if (catText.isNotEmpty && int.tryParse(catText) != null) {
                body['categoryId'] = int.parse(catText);
              }

              Navigator.pop(ctx);
              await _updateProduct(post.id ?? 0, body);
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProduct(int id, Map<String, dynamic> body) async {
    try {
      http.Response response =
          await _apiClient.put('ProductApi/$id', body: body);
      if (response.statusCode == 404) {
        response = await _apiClient.put('products/$id', body: body);
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật sản phẩm thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _reload(search: _searchController.text);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật sản phẩm: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối máy chủ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Chức năng: Xóa sản phẩm (DELETE) ---
  void _confirmDeleteProduct(productPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa sản phẩm "${post.name ?? 'N/A'}" (ID: ${post.id}) không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteProduct(post.id ?? 0);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(int id) async {
    try {
      http.Response response = await _apiClient.delete('ProductApi/$id');
      if (response.statusCode == 404) {
        response = await _apiClient.delete('products/$id');
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa sản phẩm thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _reload(search: _searchController.text);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa sản phẩm: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối máy chủ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Quét nhận diện mã QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BiometricQrScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.pin),
            tooltip: 'Tìm theo ID',
            onPressed: _searchByIdDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => _reload(search: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm theo tên sản phẩm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm theo tên...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _onSearch,
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _onSearch(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Tìm'),
                ),
              ],
            ),
          ),
          // FutureBuilder hiển thị danh sách sản phẩm theo đúng mẫu tài liệu
          Expanded(
            child: FutureBuilder<List<productPost>>(
              future: _productsFuture, // Fetch data from the API
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _reload(search: _searchController.text),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No products available.'));
                } else {
                  List<productPost> posts = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async =>
                        _reload(search: _searchController.text),
                    child: ListView.separated(
                      itemCount: posts.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        productPost post = posts[index];
                        return ListTile(
                          onTap: () => _showProductDetails(post),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: (post.image != null &&
                                      post.image!.trim().startsWith('http'))
                                  ? Image.network(
                                      post.image!.trim(),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image,
                                      color: Colors.blueGrey,
                                      size: 32,
                                    ),
                            ),
                          ),
                          title: Text(
                            post.name ?? 'No name',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            post.description ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${post.price ?? 0} VND',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (val) {
                                  if (val == 'details') {
                                    _showProductDetails(post);
                                  } else if (val == 'edit') {
                                    _showEditProductDialog(post);
                                  } else if (val == 'delete') {
                                    _confirmDeleteProduct(post);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: Colors.blueGrey, size: 20),
                                        SizedBox(width: 8),
                                        Text('Chi tiết'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit,
                                            color: Colors.blue, size: 20),
                                        SizedBox(width: 8),
                                        Text('Sửa'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Xóa'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Thêm sản phẩm mới',
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
