import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore: camel_case_types
class Config_URL {
  static String get baseUrl {
    try {
      final url = dotenv.env['BASE_URL'];
      if (url == null || url.isEmpty) {
        return "http://10.0.2.2:5186/api/";
      }
      return url.endsWith('/') ? url : '$url/';
    } catch (_) {
      return "http://10.0.2.2:5186/api/";
    }
  }
}
