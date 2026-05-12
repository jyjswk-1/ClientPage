// 文件路径: lib/pages/chat/user_chat_page.dart
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import 'private_chat_page.dart';
import '../../services/local_db_service.dart';

class UserChatPage extends StatefulWidget {
  const UserChatPage({super.key});

  @override
  State<UserChatPage> createState() => _UserChatPageState();
}

class _UserChatPageState extends State<UserChatPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = false;
  String? _loadError;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    ChatService.I.connected.addListener(_onChange);
    ChatService.I.onlineUsers.addListener(_onChange);
    ApiClient.instance.isLoggedInStatus.addListener(_onLoginStateChanged);

    if (ApiClient.instance.isLoggedInStatus.value) {
      // ignore: unawaited_futures
      _loadAllUsers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatService.I.connected.removeListener(_onChange);
    ChatService.I.onlineUsers.removeListener(_onChange);
    ApiClient.instance.isLoggedInStatus.removeListener(_onLoginStateChanged);
    super.dispose();
  }

  // 🌟 监听 App 切前台/后台
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App恢复前台，检查 WebSocket 状态...");
      if (!ChatService.I.connected.value && ApiClient.instance.isLoggedInStatus.value) {
         debugPrint("正在尝试自动重连 WebSocket...");
         
         // 🌟 1. 获取当前登录用户的 token
         final token = ApiClient.instance.token; 
         
         if (token != null) {
           // 🌟 2. 将 token 作为参数传给 connect 方法！
           // ignore: unawaited_futures
           ChatService.I.connect(token);
         }
         
         // ignore: unawaited_futures
         _loadAllUsers(); 
      }
    }
  }
  void _onChange() {
    if (mounted) setState(() {});
  }

  void _onLoginStateChanged() {
    if (!mounted) return;
    if (ApiClient.instance.isLoggedInStatus.value) {
      // ignore: unawaited_futures
      _loadAllUsers();
    } else {
      setState(() {
        _allUsers = [];
        _loadError = null;
      });
    }
  }

  Future<void> _loadAllUsers() async {
    if (_loadingUsers) return;
    setState(() {
      _loadingUsers = true;
      _loadError = null;
    });
    try {
      final list = await ApiClient.instance.getAllUsers();
      if (!mounted) return;
      setState(() {
        _allUsers = list;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineSet = ChatService.I.onlineUsers.value;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 22.0, 
        title: const Text('交流广场', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1.0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: ChatService.I.connected,
            builder: (context, isConnected, child) {
              return Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? '已连接' : '未连接',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnected ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: '搜索联系人...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ) 
                    : null,
              ),
            ),
          ),
          
          Expanded(
            child: _buildBody(onlineSet),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Set<String> onlineSet) {
    if (_loadingUsers && _allUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('加载失败: $_loadError', style: const TextStyle(color: Colors.grey)),
            OutlinedButton(onPressed: _loadAllUsers, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_allUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('还没有其他注册用户\n\n邀请朋友一起来吧', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final filteredUsers = _searchQuery.isEmpty 
        ? List<Map<String, dynamic>>.from(_allUsers)
        : _allUsers.where((u) {
            final un = (u['username'] as String).toLowerCase();
            final nn = ((u['nickname'] as String?) ?? '').toLowerCase();
            final sq = _searchQuery.toLowerCase();
            return un.contains(sq) || nn.contains(sq);
          }).toList();

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('没有匹配的用户', style: TextStyle(color: Colors.grey)));
    }

    filteredUsers.sort((a, b) {
      final ao = onlineSet.contains(a['username']);
      final bo = onlineSet.contains(b['username']);
      if (ao != bo) return ao ? -1 : 1; 
      return (a['nickname'] as String? ?? '').compareTo(b['nickname'] as String? ?? '');
    });

    return RefreshIndicator(
      onRefresh: _loadAllUsers,
      child: Scrollbar(
        child: ListView.separated(
          itemCount: filteredUsers.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) {
            final u = filteredUsers[i];
            final username = u['username'] as String;
            final nickname = (u['nickname'] as String?) ?? username;
            final avatarUrl = u['avatar_url'] as String?;
            final online = onlineSet.contains(username);

            return ListTile(
              leading: FutureBuilder<int>(
                future: LocalDbService.I.getUnreadCount(ChatService.I.me ?? '', username),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  return Badge(
                    isLabelVisible: unreadCount > 0, 
                    label: Text('$unreadCount'),
                    backgroundColor: Colors.redAccent,
                    child: _buildAvatar(nickname, avatarUrl, online), 
                  );
                },
              ),
              title: Text(nickname),
              subtitle: Text(
                online ? '在线' : '离线 · 留言对方上线后可见',
                style: TextStyle(fontSize: 12, color: online ? Colors.green : Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivateChatPage(
                      peer: username,
                      peerNickname: nickname,
                      peerAvatarUrl: avatarUrl,
                      myAvatarUrl: ApiClient.instance.myAvatarUrl,
                    ),
                  ),
                );
                if (mounted) setState(() {}); 
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(String nickname, String? avatarUrl, bool online) {
    final initial = nickname.isNotEmpty
        ? nickname.substring(0, 1).toUpperCase()
        : '?';
    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.7),
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(initial, style: const TextStyle(color: Colors.white))
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: online ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}