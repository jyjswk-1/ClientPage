// 文件路径: lib/pages/main_page.dart
import 'package:flutter/material.dart';
import 'blog/blog_list_page.dart';
import 'blog/blog_push.dart';
import 'chat/user_chat_page.dart';
import 'profile/profile_page.dart';
import '../services/api_client.dart';
import '../widgets/draggable_ai_button.dart';
import 'utils/post_status_checker.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  final List<Widget> _pages = [
    const BlogListPage(),
    const UserChatPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    ApiClient.instance.isLoggedInStatus.addListener(_onLoginChanged);
    
    // 启动审核状态检查
    PostStatusChecker.I.onStatusChanged = (title, oldStatus, newStatus) {
      final msg = newStatus == 'publish'
          ? '「$title」已通过审核并发布 ✓'
          : newStatus == 'hidden'
              ? '「$title」未通过审核'
              : '「$title」状态变更：$newStatus';
      
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 4),
          backgroundColor: newStatus == 'publish'
              ? Colors.green
              : Colors.redAccent,
        ),
      );
    };
    
    if (ApiClient.instance.isLoggedInStatus.value) {
      PostStatusChecker.I.start();
    }
  }

  void _onLoginChanged() async {
    await ApiClient.instance.fetchMe();
    if (mounted) setState(() {});
    
    if (ApiClient.instance.isLoggedInStatus.value) {
      PostStatusChecker.I.start();
    } else {
      PostStatusChecker.I.stop();
    }
  }

  @override
  void dispose() {
    ApiClient.instance.isLoggedInStatus.removeListener(_onLoginChanged);
    PostStatusChecker.I.stop();
    super.dispose();
  }

  bool get _canWrite => ['administrator', 'editor', 'contributor']
      .contains(ApiClient.instance.userGroup);

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            DraggableAiButton(currentTabIndex: _currentIndex),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.article), label: '文章'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: '交流'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final group = ApiClient.instance.userGroup;
    final isLoggedIn = ApiClient.instance.isLoggedInStatus.value;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('创作中心',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (isLoggedIn)
                    Text(
                      _groupLabel(group),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 写文章（contributor 及以上）
            if (_canWrite) ...[
              _drawerItem(
                icon: Icons.edit_note,
                label: '写文章',
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WritePostPage()),
                  ).then((ok) {
                    if (ok == true) {
                      // 通知文章列表刷新
                      setState(() {});
                    }
                  });
                },
              ),
            ],

            // 管理文章（administrator / editor）
            if (['administrator', 'editor'].contains(group)) ...[
              _drawerItem(
                icon: Icons.manage_search,
                label: '管理文章',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 跳转管理页面
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('管理功能开发中...')),
                  );
                },
              ),
            ],

            // 未登录提示
            if (!isLoggedIn)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '登录后可使用创作功能',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),

            const Spacer(),

            // 底部权限说明
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _permissionHint(group),
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    );
  }

  String _groupLabel(String group) {
    const map = {
      'administrator': '管理员',
      'editor': '编辑',
      'contributor': '贡献者',
      'subscriber': '关注者',
      'visitor': '访问者',
      'app': '普通用户',
    };
    return map[group] ?? group;
  }

  String _permissionHint(String group) {
    switch (group) {
      case 'administrator':
      case 'editor':
        return '当前权限：可发布文章、管理所有内容';
      case 'contributor':
        return '当前权限：可写文章，需审核后发布';
      default:
        return '登录博客账号可解锁创作权限';
    }
  }
}