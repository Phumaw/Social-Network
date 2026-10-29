import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'api_service.dart';

class AuthService {
  static const _userKey = 'current_user';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response =
          await ApiService.post('/auth/login', {
                'email': email,
                'password': password,
              }, authenticated: false)
              as Map<String, dynamic>;
      await _saveSession(response);
      return {
        'success': true,
        'message': response['message'] ?? 'เข้าสู่ระบบสำเร็จ',
      };
    } on ApiException catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {'success': false, 'message': 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา'};
    } on http.ClientException {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'};
    } on PlatformException catch (error) {
      return {
        'success': false,
        'message': 'ไม่สามารถบันทึกข้อมูลเข้าสู่ระบบได้: ${error.message}',
      };
    } on FormatException catch (error) {
      return {'success': false, 'message': error.message};
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String address,
  }) async {
    try {
      final response =
          await ApiService.post('/auth/register', {
                'username': username,
                'email': email,
                'password': password,
                'address': address,
              }, authenticated: false)
              as Map<String, dynamic>;
      return {
        'success': true,
        'message': response['message'] ?? 'ลงทะเบียนสำเร็จ',
      };
    } on ApiException catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {'success': false, 'message': 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา'};
    } on http.ClientException {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'};
    } on PlatformException catch (error) {
      return {
        'success': false,
        'message': 'ไม่สามารถบันทึกข้อมูลเข้าสู่ระบบได้: ${error.message}',
      };
    } on FormatException catch (error) {
      return {'success': false, 'message': error.message};
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response =
          await ApiService.post('/auth/forgot-password', {
                'email': email,
              }, authenticated: false)
              as Map<String, dynamic>;
      return {
        'success': true,
        'message': response['message'] ?? 'ส่งรหัสยืนยันแล้ว',
      };
    } on ApiException catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {'success': false, 'message': 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา'};
    } on http.ClientException {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'};
    } on FormatException catch (error) {
      return {'success': false, 'message': error.message};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final response =
          await ApiService.post('/auth/reset-password', {
                'email': email,
                'code': code,
                'password': password,
              }, authenticated: false)
              as Map<String, dynamic>;
      return {
        'success': true,
        'message': response['message'] ?? 'เปลี่ยนรหัสผ่านสำเร็จ',
      };
    } on ApiException catch (error) {
      return {'success': false, 'message': error.message};
    } on TimeoutException {
      return {'success': false, 'message': 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา'};
    } on http.ClientException {
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'};
    } on FormatException catch (error) {
      return {'success': false, 'message': error.message};
    }
  }

  Future<AppUser?> cachedUser() async {
    final preferences = await SharedPreferences.getInstance();
    final data = preferences.getString(_userKey);
    if (data == null) return null;
    return AppUser.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<AppUser> refreshUser() async {
    final json = await ApiService.get('/auth/me') as Map<String, dynamic>;
    final user = AppUser.fromJson(json);
    await _saveUser(user);
    return user;
  }

  Future<Map<String, List<AppUser>>> getFollowStats() async {
    final response =
        await ApiService.get('/auth/follow-stats') as Map<String, dynamic>;
    List<AppUser> parseUsers(dynamic value) {
      if (value is! List) return [];
      return value
          .whereType<Map<String, dynamic>>()
          .map(AppUser.fromJson)
          .toList();
    }

    return {
      'followers': parseUsers(response['followers']),
      'following': parseUsers(response['following']),
    };
  }

  Future<List<AppUser>> searchUsers(String query) async {
    final response = await ApiService.get(
      '/auth/users?${Uri(queryParameters: {'q': query.trim()}).query}',
    );
    if (response is! List) {
      throw const ApiException('รูปแบบผลการค้นหาผู้ใช้ไม่ถูกต้อง');
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final response = await ApiService.get(
      '/auth/users/${Uri.encodeComponent(userId)}',
    );
    if (response is! Map<String, dynamic> ||
        response['user'] is! Map<String, dynamic>) {
      throw const ApiException('รูปแบบโปรไฟล์ไม่ถูกต้อง');
    }
    return {
      'user': AppUser.fromJson(response['user'] as Map<String, dynamic>),
      'isSelf': response['isSelf'] == true,
      'isFollowing': response['isFollowing'] == true,
      'followRequestPending': response['followRequestPending'] == true,
      'canViewPrivateContent': response['canViewPrivateContent'] == true,
      'followersCount': response['followersCount'],
      'followingCount': response['followingCount'],
    };
  }

  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await ApiService.put('/auth/follow/$userId', {});
    if (response is! Map<String, dynamic>) {
      throw const ApiException('เปลี่ยนสถานะติดตามไม่สำเร็จ');
    }
    return response;
  }

  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final response = await ApiService.delete('/auth/follow/$userId');
    if (response is! Map<String, dynamic>) {
      throw const ApiException('เลิกติดตามไม่สำเร็จ');
    }
    return response;
  }

  Future<List<Map<String, dynamic>>> getFollowRequests() async {
    final response = await ApiService.get('/auth/follow-requests');
    if (response is! List) {
      throw const ApiException('รูปแบบคำขอติดตามไม่ถูกต้อง');
    }
    return response.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> respondToFollowRequest(
    String requestId, {
    required bool accept,
  }) async {
    await ApiService.put('/auth/follow-requests/$requestId', {
      'action': accept ? 'accept' : 'decline',
    });
  }

  Future<AppUser> updateProfile({
    required String name,
    required String bio,
    required String address,
    required bool isPrivate,
    XFile? profileImage,
    XFile? bannerImage,
  }) async {
    final json =
        await ApiService.uploadProfile(
              {
                'name': name,
                'bio': bio,
                'address': address,
                'isPrivate': isPrivate,
              },
              profileImage: profileImage,
              bannerImage: bannerImage,
            )
            as Map<String, dynamic>;
    final user = AppUser.fromJson(json);
    await _saveUser(user);
    return user;
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userKey);
  }

  Future<void> deleteAccount(String password) async {
    await ApiService.delete('/auth/account', body: {'password': password});
    await logout();
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['token'];
    final user = response['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const FormatException('เซิร์ฟเวอร์ส่งข้อมูลเข้าสู่ระบบไม่ครบ');
    }
    await ApiService.saveToken(token);
    await _saveUser(AppUser.fromJson(user));
  }

  Future<void> _saveUser(AppUser user) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
  }
}
