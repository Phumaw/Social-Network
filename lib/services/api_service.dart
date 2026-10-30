import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static const _storage = FlutterSecureStorage();
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final http.Client _client = http.Client();

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty)
      return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
    if (kIsWeb) return 'http://127.0.0.1:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:3000/api';
    return 'http://127.0.0.1:3000/api';
  }

  static Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);
  static Future<String?> readToken() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) return token;
    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString('jwt_token');
    if (legacyToken != null) {
      await saveToken(legacyToken);
      await preferences.remove('jwt_token');
    }
    return legacyToken;
  }

  static Future<void> clearToken() => _storage.delete(key: 'jwt_token');

  static String resolveImageUrl(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) return path;
    return Uri.parse(
      baseUrl,
    ).replace(path: path.startsWith('/') ? path : '/$path').toString();
  }

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Future<Map<String, String>> _headers({
    required bool authenticated,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    String? token;
    if (authenticated) {
      token = await readToken();
      if (token != null && token.isNotEmpty)
        headers['Authorization'] = 'Bearer $token';
    }
    if (token != null && token.isNotEmpty) {
      headers.remove('Authorization');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _decode(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = response.body;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : decoded?.toString();
      throw ApiException(
        message?.isNotEmpty == true
            ? message!
            : 'เซิร์ฟเวอร์ตอบกลับด้วยสถานะ ${response.statusCode}',
      );
    }
    return decoded;
  }

  static Future<dynamic> get(String path) async {
    final response = await _client
        .get(_uri(path), headers: await _headers(authenticated: true))
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final headers = await _headers(authenticated: authenticated);
    headers['Content-Type'] = 'application/json';
    final response = await _client
        .post(_uri(path), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final headers = await _headers(authenticated: true);
    headers['Content-Type'] = 'application/json';
    final response = await _client
        .put(_uri(path), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  static Future<dynamic> uploadProfile(
    Map<String, dynamic> fields, {
    XFile? profileImage,
    XFile? bannerImage,
  }) async {
    final request = http.MultipartRequest('PUT', _uri('/auth/profile'));
    request.headers.addAll(await _headers(authenticated: true));
    fields.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    for (final entry in {
      'profileImage': profileImage,
      'bannerImage': bannerImage,
    }.entries) {
      final image = entry.value;
      if (image == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes(
          entry.key,
          await image.readAsBytes(),
          filename: image.name,
          contentType: http.MediaType.parse(_imageContentType(image)),
        ),
      );
    }
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    return _decode(await http.Response.fromStream(streamed));
  }

  static Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers(authenticated: true);
    if (body != null) headers['Content-Type'] = 'application/json';
    final response = await _client
        .delete(
          _uri(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  static Future<dynamic> uploadPost({
    required String caption,
    required String location,
    required XFile media,
    required String mediaType,
    String? postId,
    String? communityId,
  }) async {
    final request = http.MultipartRequest(
      postId == null ? 'POST' : 'PUT',
      _uri(postId == null ? '/posts' : '/posts/$postId'),
    );
    request.headers.addAll(await _headers(authenticated: true));
    request.fields['caption'] = caption;
    request.fields['location'] = location;
    request.fields['mediaType'] = mediaType;
    if (communityId != null) request.fields['communityId'] = communityId;
    final contentType = _postMediaContentType(media);
    request.files.add(
      http.MultipartFile.fromBytes(
        'media',
        await media.readAsBytes(),
        filename: media.name,
        contentType: http.MediaType.parse(contentType),
      ),
    );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    return _decode(await http.Response.fromStream(streamed));
  }

  static Future<dynamic> uploadChatMessage({
    required String userId,
    required String text,
    XFile? media,
    required String mediaType,
    String? sharedPostId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/chat/conversations/${Uri.encodeComponent(userId)}/messages'),
    );
    request.headers.addAll(await _headers(authenticated: true));
    request.fields['text'] = text;
    if (sharedPostId != null) request.fields['sharedPostId'] = sharedPostId;
    if (media != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'media',
          await media.readAsBytes(),
          filename: media.name,
          contentType: http.MediaType.parse(_postMediaContentType(media)),
        ),
      );
      request.fields['mediaType'] = mediaType;
    }
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 120));
    return _decode(await http.Response.fromStream(streamed));
  }

  static String _imageContentType(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    const supportedTypes = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
    };
    if (mimeType != null && supportedTypes.contains(mimeType)) return mimeType;

    final extension = image.name.split('.').last.toLowerCase();
    const extensionTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final resolvedType = extensionTypes[extension];
    if (resolvedType == null) {
      throw const ApiException(
        'รองรับไฟล์รูปภาพ JPG, PNG, WEBP หรือ GIF เท่านั้น',
      );
    }
    return resolvedType;
  }

  static String _postMediaContentType(XFile media) {
    final extension = media.name.split('.').last.toLowerCase();
    const contentTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
    };
    final contentType = contentTypes[extension];
    if (contentType == null) {
      throw const ApiException(
        'รองรับรูป JPG, PNG, WEBP, GIF และวิดีโอ MP4, MOV, WEBM',
      );
    }
    return contentType;
  }
}
