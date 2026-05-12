// 文件路径: lib/pages/chat/contact_select_page.dart
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/api_client.dart'; // 引入 API Client

class ContactSelectPage extends StatefulWidget {
  final String title;
  const ContactSelectPage({super.key, this.title = '选择联系人'});

  @override
  State<ContactSelectPage> createState() => _ContactSelectPageState();
}

class _ContactSelectPageState extends State<ContactSelectPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  // 🌟 直接调用 API 拉取全站所有注册用户
  Future<void> _loadAllUsers() async {
    try {
      final users = await ApiClient.instance.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载用户失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 搜索过滤逻辑：同时匹配 username 或 nickname
    final displayList = _searchQuery.isEmpty 
        ? _allUsers 
        : _allUsers.where((u) {
            final un = (u['username'] as String).toLowerCase();
            final nn = ((u['nickname'] as String?) ?? '').toLowerCase();
            final sq = _searchQuery.toLowerCase();
            return un.contains(sq) || nn.contains(sq);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // 顶部搜索栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: '搜索账号或昵称...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ) 
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
          
          // 列表部分
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : displayList.isEmpty
                ? const Center(child: Text('没有找到该用户', style: TextStyle(color: Colors.grey)))
                : Scrollbar(
                    child: ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        final peer = item['username'] as String;
                        final nickname = item['nickname'] as String? ?? peer;
                        final isOnline = ChatService.I.onlineUsers.value.contains(peer);

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                            backgroundImage: (item['avatar_url'] != null && (item['avatar_url'] as String).isNotEmpty)
                                ? NetworkImage(item['avatar_url'] as String)
                                : null,
                            child: (item['avatar_url'] == null || (item['avatar_url'] as String).isEmpty)
                                ? Text(
                                    nickname.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            isOnline ? '[在线]' : '[离线]',
                            style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12),
                          ),
                          onTap: () => Navigator.pop(context, peer),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}