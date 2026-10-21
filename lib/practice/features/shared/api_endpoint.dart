/// Android Emulator dùng 10.0.2.2 để truy cập localhost của máy phát triển.
const emulatorPostsEndpoint = 'http://10.0.2.2:5186/api/posts';

Uri collectionUri(String endpoint) {
  final value = endpoint.trim();
  final uri = Uri.tryParse(value);
  final isLocalHttp =
      uri?.scheme == 'http' &&
      const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri?.host);
  if (value.isEmpty ||
      RegExp(r'\s').hasMatch(value) ||
      uri == null ||
      !uri.isAbsolute ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && !isLocalHttp) ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.path.isEmpty ||
      uri.path == '/') {
    throw const FormatException(
      'Nhập URL HTTPS đầy đủ có đường dẫn; HTTP chỉ dành cho '
      'localhost, 127.0.0.1 hoặc 10.0.2.2. Không dùng tài khoản hoặc dấu #.',
    );
  }
  return uri;
}

Uri itemUri(String endpoint, int id) {
  if (id <= 0) throw const FormatException('ID phải là số nguyên dương.');
  final collection = collectionUri(endpoint);
  final path = collection.path.replaceFirst(RegExp(r'/+$'), '');
  return collection.replace(path: '$path/$id');
}

String productsEndpoint(String postsEndpoint) {
  final uri = collectionUri(postsEndpoint);
  final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList();
  if (segments.isEmpty || segments.last.toLowerCase() != 'posts') {
    throw const FormatException(
      'Nguồn bài viết phải kết thúc bằng /posts để tìm API sản phẩm.',
    );
  }
  segments[segments.length - 1] = 'products';
  return uri
      .replace(pathSegments: segments, query: '')
      .toString()
      .replaceFirst(RegExp(r'\?$'), '');
}

String serverBase(String postsEndpoint) {
  final uri = collectionUri(postsEndpoint);
  final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList();
  if (segments.isNotEmpty && segments.last.toLowerCase() == 'posts') {
    segments.removeLast();
  }
  return uri
      .replace(pathSegments: segments, query: '')
      .toString()
      .replaceFirst(RegExp(r'\?$'), '');
}

bool isReadOnlyDemoEndpoint(String endpoint) {
  final host = Uri.tryParse(endpoint)?.host.toLowerCase();
  return host == 'jsonplaceholder.typicode.com';
}
