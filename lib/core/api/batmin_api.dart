import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class BatminApi {
  BatminApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> health() async {
    final response = await _client
        .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('API error: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
