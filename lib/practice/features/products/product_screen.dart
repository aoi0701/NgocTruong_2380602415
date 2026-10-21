import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'product.dart';
import 'product_provider.dart';

/// Body for the products tab; the application owns the surrounding Scaffold.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _search = TextEditingController();
  final _id = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _id.dispose();
    super.dispose();
  }

  void _searchProducts(ProductProvider provider) {
    final endpoint = provider.endpoint;
    if (endpoint != null) provider.load(endpoint, name: _search.text);
  }

  Future<void> _find(ProductProvider provider) async {
    final id = int.tryParse(_id.text.trim());
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập ID là số nguyên dương.')),
      );
      return;
    }
    final result = await provider.findById(id);
    if (!mounted || result == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết sản phẩm #${result.id}'),
        content: SingleChildScrollView(
          child: Text(
            '${result.name}\n${result.description}\nGiá: ${result.price}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(ProductProvider provider, [Product? product]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ProductEditor(provider: provider, product: product),
      ),
    );
  }

  Future<void> _delete(ProductProvider provider, Product product) async {
    final endpoint = provider.endpoint;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sản phẩm?'),
        content: Text('Xóa “${product.name}” khỏi máy chủ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && provider.endpoint == endpoint) {
      await provider.delete(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    if (provider.endpoint == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chọn Backend máy ảo hoặc URL Conveyor trong Cài đặt để quản lý sản phẩm. Nguồn JSONPlaceholder không có API sản phẩm.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final busy = provider.isSaving || provider.isFinding;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('product-add'),
              onPressed: busy || provider.isLoading
                  ? null
                  : () => _edit(provider),
              icon: const Icon(Icons.add),
              label: const Text('Thêm sản phẩm'),
            ),
            OutlinedButton.icon(
              onPressed: busy || provider.isLoading
                  ? null
                  : () => provider.load(
                      provider.endpoint!,
                      name: provider.nameQuery,
                    ),
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('product-search'),
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Tìm theo tên trên máy chủ',
            border: OutlineInputBorder(),
          ),
          onSubmitted: busy ? null : (_) => _searchProducts(provider),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('product-search-submit'),
            onPressed: busy ? null : () => _searchProducts(provider),
            icon: const Icon(Icons.search),
            label: const Text('Tìm tên'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('product-id'),
                controller: _id,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID sản phẩm',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: busy ? null : (_) => _find(provider),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('product-id-submit'),
              tooltip: 'Tìm theo ID',
              onPressed: busy ? null : () => _find(provider),
              icon: const Icon(Icons.manage_search),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.isLoading || busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (provider.error != null) ...[
          Text(
            provider.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => provider.load(
                    provider.endpoint!,
                    name: provider.nameQuery,
                  ),
            child: const Text('Thử lại'),
          ),
        ],
        if (provider.mutationError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              provider.mutationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!provider.isLoading &&
            provider.error == null &&
            provider.products.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Không có sản phẩm phù hợp.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final product in provider.products)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('#${product.id} · Giá: ${product.price}'),
                  if (product.description.isNotEmpty) Text(product.description),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        key: Key('product-edit-${product.id}'),
                        tooltip: 'Sửa sản phẩm',
                        onPressed: busy || provider.isLoading
                            ? null
                            : () => _edit(provider, product),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        key: Key('product-delete-${product.id}'),
                        tooltip: 'Xóa sản phẩm',
                        onPressed: busy || provider.isLoading
                            ? null
                            : () => _delete(provider, product),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.provider, this.product});
  final ProductProvider provider;
  final Product? product;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product?.price.toString() ?? '',
  );
  late final _endpoint = widget.provider.endpoint;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting || !_form.currentState!.validate()) return;
    if (widget.provider.endpoint != _endpoint) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final price = double.parse(_price.text.trim());
    final product = widget.product;
    final success = product == null
        ? await widget.provider.create(
            name: _name.text,
            description: _description.text,
            price: price,
          )
        : await widget.provider.update(
            Product(
              id: product.id,
              name: _name.text.trim(),
              description: _description.text.trim(),
              price: price,
            ),
          );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _submitting = false;
        _error =
            widget.provider.mutationError ??
            'Nguồn dữ liệu đã thay đổi hoặc đang bận. Hãy thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.provider,
    builder: (context, _) {
      final sourceChanged = widget.provider.endpoint != _endpoint;
      return PopScope(
        canPop: !_submitting,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
            ),
          ),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  key: const Key('product-name'),
                  controller: _name,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
                  validator: (value) =>
                      value == null ||
                          value.trim().isEmpty ||
                          value.trim().length > 200
                      ? 'Tên từ 1 đến 200 ký tự.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('product-description'),
                  controller: _description,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  validator: (value) => (value?.trim().length ?? 0) > 2000
                      ? 'Mô tả tối đa 2000 ký tự.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('product-price'),
                  controller: _price,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Giá'),
                  validator: (value) {
                    final price = double.tryParse(value?.trim() ?? '');
                    return price == null || !price.isFinite || price < 0
                        ? 'Giá phải là số không âm (ví dụ 12.5).'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                if (sourceChanged)
                  const Text(
                    'Nguồn dữ liệu đã đổi. Quay lại để mở biểu mẫu mới.',
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  key: const Key('product-save'),
                  onPressed: _submitting || sourceChanged ? null : _save,
                  child: Text(_submitting ? 'Đang lưu…' : 'Lưu'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
