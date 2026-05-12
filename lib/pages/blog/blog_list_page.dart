// 文件路径: lib/pages/blog/blog_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'blog_detail_page.dart';
import 'blog_push.dart';

class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});

  @override
  State<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends State<BlogListPage> {
  late Future<List<dynamic>> _postsFuture;
  List<dynamic> _categories = [];
  int _selectedCategoryId = 0;
  final ScrollController _scrollController = ScrollController();

  // ── 搜索状态 ──────────────────────────────────────────────────────────────
  bool _isSearching = false;
  String _searchQuery = '';
  List<dynamic> _searchResults = [];
  bool _isSearchLoading = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchPosts();
    ApiClient.instance.isLoggedInStatus.addListener(_onLoginStateChanged);
  }

  void _onLoginStateChanged() async {
    await ApiClient.instance.fetchMe();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ApiClient.instance.isLoggedInStatus.removeListener(_onLoginStateChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiClient.instance.fetchCategories();
    if (mounted) setState(() => _categories = cats);
  }

  void _fetchPosts() {
    setState(() {
      _postsFuture = ApiClient.instance.getPosts(
        page: 1,
        perPage: 15,
        categoryId: _selectedCategoryId == 0 ? null : _selectedCategoryId,
      );
    });
  }

  // ── 搜索逻辑 ──────────────────────────────────────────────────────────────
  void _openSearch() => setState(() => _isSearching = true);

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults = [];
      _isSearchLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    setState(() {
      _searchQuery = q;
      if (q.isEmpty) { _searchResults = []; _isSearchLoading = false; }
    });
    if (q.isEmpty) return;

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearchLoading = true);
      final results = await ApiClient.instance.searchArticles(q);
      if (!mounted) return;
      setState(() { _searchResults = results; _isSearchLoading = false; });
    });
  }

  // ── 搜索下拉面板 ──────────────────────────────────────────────────────────
  Widget _buildSearchDropdown() {
    if (!_isSearching || _searchQuery.isEmpty) return const SizedBox.shrink();

    Widget content;
    if (_isSearchLoading) {
      content = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_searchResults.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('没有找到相关文章', style: TextStyle(color: Colors.grey))),
      );
    } else {
      content = ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final article = _searchResults[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.article_outlined, color: Colors.blueAccent, size: 20),
            title: Text(
              article['title'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: (article['excerpt'] != null && article['excerpt'].toString().isNotEmpty)
                ? Text(article['excerpt'], maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))
                : null,
            onTap: () {
              _closeSearch();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => BlogDetailPage(cid: article['cid']),
              ));
            },
          );
        },
      );
    }

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = ['administrator', 'editor', 'contributor']
        .contains(ApiClient.instance.userGroup);

    return Scaffold(
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WritePostPage()),
              ).then((ok) { if (ok == true) _fetchPosts(); }),
              child: const Icon(Icons.edit),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20.0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文章...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                onChanged: _onSearchChanged,
              )
            : const Text(
                '文章',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: _closeSearch,
                )
              : IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  onPressed: _openSearch,
                ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.network_ping, color: Colors.black87),
              onPressed: () async {
                try {
                  final result = await ApiClient.instance.ping();
                  if (!context.mounted) return;
                  final status = result['data'] != null
                      ? result['data']['status']
                      : result['status'];
                  final posts = result['data'] != null
                      ? result['data']['posts']
                      : result['posts'];
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('API 状态: $status / 文章数: $posts')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('请求异常: $e'),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── 主内容：分类栏 + 文章列表 ──────────────────────────────────
          Column(
            children: [
              Container(
                color: Colors.white,
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    ChoiceChip(
                      label: const Text('最新文章'),
                      selected: _selectedCategoryId == 0,
                      onSelected: (val) {
                        if (val) { setState(() => _selectedCategoryId = 0); _fetchPosts(); }
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._categories.map((cat) {
                      final cid = cat['mid'] as int;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat['name']),
                          selected: _selectedCategoryId == cid,
                          onSelected: (val) {
                            if (val) { setState(() => _selectedCategoryId = cid); _fetchPosts(); }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async { _fetchPosts(); await _postsFuture; },
                  child: FutureBuilder<List<dynamic>>(
                    future: _postsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('加载出错: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('暂无文章'));
                      }
                      final posts = snapshot.data!;
                      return Scrollbar(
                        controller: _scrollController,
                        thickness: 6.0,
                        radius: const Radius.circular(3),
                        interactive: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                title: Text(
                                  post['title'] ?? '无标题',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '作者: ${post['author']} • ${post['created'].toString().substring(0, 10)}'),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlogDetailPage(cid: post['cid']),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // ── 搜索下拉覆盖层（叠在列表上方，不全屏遮挡）────────────────────
          _buildSearchDropdown(),
        ],
      ),
    );
  }
}