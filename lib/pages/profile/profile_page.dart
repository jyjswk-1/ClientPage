import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../auth/login_page.dart';
import 'favorites_page.dart';
import 'notifications_page.dart';
import '../../widgets/rss_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String  _nickname = '加载中...';
  String  _username = '';
  String? _avatarUrl;
  bool _isLoadingProfile  = false;
  bool _isUploadingAvatar = false;
  int  _unreadCount       = 0;

  StreamSubscription<SystemNotification>? _notifySub;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (ApiClient.instance.isLoggedInStatus.value) {
      _fetchProfile();
      _fetchUnreadCount();
    }
    ApiClient.instance.isLoggedInStatus.addListener(_onLoginStateChanged);

    // 监听 WebSocket 系统通知，实时更新未读数
    _notifySub = ChatService.I.onNotification.listen((_) {
      if (mounted) setState(() => _unreadCount++);
    });
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    ApiClient.instance.isLoggedInStatus.removeListener(_onLoginStateChanged);
    super.dispose();
  }

  void _onLoginStateChanged() {
    if (ApiClient.instance.isLoggedInStatus.value) {
      _fetchProfile();
      _fetchUnreadCount();
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final list = await ApiClient.instance.getNotifications();
      final unread = list.where((n) => n['is_read'] == false).length;
      if (mounted) setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    final token = ApiClient.instance.token;
    if (token == null) return;
    setState(() => _isLoadingProfile = true);
    try {
      final res = await http.get(
        Uri.parse('https://jyjswk.online/api/v1/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['code'] == 0 && data['data'] != null && mounted) {
          setState(() {
            _nickname  = data['data']['nickname'] ?? '无昵称';
            _username  = data['data']['username'] ?? '';
            _avatarUrl = data['data']['avatar_url'];
          });
          ApiClient.instance.myAvatarUrl = _avatarUrl;
        }
      }
    } catch (e) {
      debugPrint('获取个人资料失败: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _showEditNicknameDialog() async {
    final controller = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入新昵称',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != _nickname) {
      _updateNickname(result);
    }
  }

  Future<void> _updateNickname(String newNickname) async {
    final token = ApiClient.instance.token;
    if (token == null) return;
    try {
      final res = await http.post(
        Uri.parse('https://jyjswk.online/api/v1/profile'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'nickname': newNickname}),
      );
      if (res.statusCode == 200) {
        setState(() => _nickname = newNickname);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称修改成功')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改失败, 请重试')));
      }
    } catch (e) {
      debugPrint('修改昵称失败: $e');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (image == null) return;
    final token = ApiClient.instance.token;
    if (token == null) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://jyjswk.online/api/v1/upload/avatar'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path, contentType: MediaType('image', 'jpeg')));
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data']?['avatar_url'] != null) {
          setState(() { _avatarUrl = data['data']['avatar_url']; ApiClient.instance.myAvatarUrl = _avatarUrl; });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像上传成功')));
        }
      }
    } catch (e) {
      debugPrint('上传头像异常: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiClient.instance.isLoggedInStatus,
      builder: (context, isLoggedIn, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 20.0,
            title: const Text('个人中心', style: TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (isLoggedIn)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  tooltip: '退出登录',
                  onPressed: () {
                    ChatService.I.disconnect();
                    ApiClient.instance.logout();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已退出登录')));
                  },
                ),
            ],
          ),
          body: isLoggedIn ? _buildUserProfile() : _buildGuestProfile(),
        );
      },
    );
  }

  Widget _buildUserProfile() {
    if (_isLoadingProfile && _username.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final ScrollController scrollCtrl = ScrollController();
    return Scrollbar(
      controller: scrollCtrl,
      child: SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 个人信息卡片
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                          backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? NetworkImage('$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}')
                              : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.blueAccent)
                              : null,
                        ),
                        if (_isUploadingAvatar)
                          Container(
                            width: 80, height: 80,
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                          ),
                        if (!_isUploadingAvatar)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.blueAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nickname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('账号: $_username', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: _showEditNicknameDialog),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 我的收藏
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.yellow[700]!.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.star_rounded, color: Colors.yellow[700]),
              ),
              title: const Text('我的收藏'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
            ),
            const Divider(),

            // 消息通知（带未读角标）
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_none, color: Colors.orange),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -2, top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              title: const Text('消息通知'),
              subtitle: _unreadCount > 0 ? Text('$_unreadCount 条未读', style: const TextStyle(color: Colors.redAccent, fontSize: 12)) : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                // 返回后刷新未读数
                _fetchUnreadCount();
              },
            ),
            const Divider(),

            // RSS 订阅
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.rss_feed, color: Colors.orange),
              ),
              title: const Text('RSS 订阅'),
              subtitle: const Text('订阅博客最新内容', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RssPage())),
            ),
            const Divider(),

            // 隐私与安全
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.privacy_tip_outlined, color: Colors.purple),
              ),
              title: const Text('隐私与安全'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('登录体验完整功能', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('前往登录'),
          ),
        ],
      ),
    );
  }
}