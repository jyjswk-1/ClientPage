import 'package:flutter/material.dart';
import '../../services/local_db_service.dart'; // 🌟 引入本地数据库
import '../blog/blog_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // 🌟 改为存储包含完整信息的 Map 列表
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // 🌟 从 SQLite 秒读数据
  Future<void> _loadFavorites() async {
    final list = await LocalDbService.I.getFavoriteList();
    if (mounted) {
      setState(() {
        _favorites = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('我的收藏'),
        elevation: 1,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _favorites.isEmpty
          ? const Center(child: Text('暂无收藏内容，快去看看文章吧', style: TextStyle(color: Colors.grey)))
          : Scrollbar(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  // 🌟 直接从本地变量读取渲染，丝滑流畅
                  final post = _favorites[index];
                  final cid = post['cid'] as int;
                  
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(post['title'] ?? '无标题', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('作者: ${post['author'] ?? '未知'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // 跳转详情，返回后刷新一下列表（因为有可能在详情页取消了收藏）
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => BlogDetailPage(cid: cid))
                        ).then((_) {
                          _loadFavorites();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}