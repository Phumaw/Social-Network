import '../models/community.dart';
import 'api_service.dart';

class CommunityService {
  Future<List<Community>> getCommunities({String query = ''}) async {
    final parameters = query.trim().isEmpty
        ? ''
        : '?${Uri(queryParameters: {'q': query.trim()}).query}';
    final response = await ApiService.get('/communities$parameters');
    if (response is! List) {
      throw const ApiException('รูปแบบรายการกลุ่มและเพจไม่ถูกต้อง');
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(Community.fromJson)
        .toList();
  }

  Future<Community> getCommunity(String id) async {
    final response = await ApiService.get(
      '/communities/${Uri.encodeComponent(id)}',
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException('รูปแบบข้อมูลชุมชนไม่ถูกต้อง');
    }
    return Community.fromJson(response);
  }

  Future<Community> createCommunity({
    required String name,
    required String description,
    required String type,
  }) async {
    final response = await ApiService.post('/communities', {
      'name': name,
      'description': description,
      'type': type,
    });
    if (response is! Map<String, dynamic>) {
      throw const ApiException('สร้างชุมชนไม่สำเร็จ');
    }
    return Community.fromJson(response);
  }

  Future<Community> updateCommunity(
    String id, {
    required String name,
    required String description,
    required String type,
  }) async {
    final response = await ApiService.put('/communities/$id', {
      'name': name,
      'description': description,
      'type': type,
    });
    if (response is! Map<String, dynamic>) {
      throw const ApiException('แก้ไขชุมชนไม่สำเร็จ');
    }
    return Community.fromJson(response);
  }

  Future<Community> joinCommunity(String id) async {
    final response = await ApiService.post('/communities/$id/join', {});
    if (response is! Map<String, dynamic>) {
      throw const ApiException('เข้าร่วมชุมชนไม่สำเร็จ');
    }
    return Community.fromJson(response);
  }

  Future<void> leaveCommunity(String id) async {
    await ApiService.post('/communities/$id/leave', {});
  }

  Future<void> deleteCommunity(String id) async {
    await ApiService.delete('/communities/$id');
  }
}
