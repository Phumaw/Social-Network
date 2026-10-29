import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'public_profile_screen.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final _authService = AuthService();
  late Future<List<Map<String, dynamic>>> _requests;
  final Set<String> _busyRequests = {};

  @override
  void initState() {
    super.initState();
    _requests = _authService.getFollowRequests();
  }

  void _refresh() {
    setState(() => _requests = _authService.getFollowRequests());
  }

  Future<void> _respond(String id, {required bool accept}) async {
    setState(() => _busyRequests.add(id));
    try {
      await _authService.respondToFollowRequest(id, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'อนุมัติคำขอติดตามแล้ว' : 'ปฏิเสธคำขอติดตามแล้ว',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('จัดการคำขอไม่สำเร็จ: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRequests.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำขอติดตาม')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(child: Text('โหลดคำขอไม่สำเร็จ: ${snapshot.error}')),
                  Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ),
                ],
              );
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 150),
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 44,
                    color: AppTheme.mutedTextColor,
                  ),
                  SizedBox(height: 10),
                  Center(child: Text('ไม่มีคำขอติดตาม')),
                ],
              );
            }
            return ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final request = requests[index];
                final user = AppUser.fromJson(
                  request['user'] as Map<String, dynamic>,
                );
                final id = request['id'].toString();
                final busy = _busyRequests.contains(id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profileImage.isEmpty
                        ? null
                        : NetworkImage(
                            ApiService.resolveImageUrl(user.profileImage),
                          ),
                    child: user.profileImage.isEmpty
                        ? Text(
                            user.name.isEmpty
                                ? '?'
                                : user.name.characters.first,
                          )
                        : null,
                  ),
                  title: Text(user.name),
                  subtitle: user.username.isEmpty
                      ? null
                      : Text('@${user.username}'),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PublicProfileScreen(userId: user.id),
                    ),
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'ปฏิเสธ',
                              onPressed: () => _respond(id, accept: false),
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                            IconButton(
                              tooltip: 'อนุมัติ',
                              onPressed: () => _respond(id, accept: true),
                              icon: const Icon(
                                Icons.check,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
