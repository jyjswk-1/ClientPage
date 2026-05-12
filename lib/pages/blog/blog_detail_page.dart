// 文件路径: lib/pages/blog/blog_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../../services/local_db_service.dart';
import '../chat/contact_select_page.dart';
import 'package:markdown/markdown.dart' as md;
import '../utils/codes_copy.dart';
import '../../pages/utils/webviewer.dart';


class CodeBlockBuilder extends MarkdownElementBuilder {
  final Color textColor;
  final double fontSize;
  CodeBlockBuilder({required this.textColor, required this.fontSize});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282C34),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('code', style: TextStyle(color: Color(0xFF5C6370), fontSize: 12)),
                CopyButton(code: code),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3E4451)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSize - 1,
                  color: const Color(0xFFABB2BF),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BlogDetailPage extends StatefulWidget {
  final int cid;
  const BlogDetailPage({super.key, required this.cid});

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  late Future<Map<String, dynamic>> _postDetailFuture;
  final ScrollController _scrollController = ScrollController();
  
  double _readProgress = 0.0;
  bool _isFavorited = false;
  
  // 评论相关变量
  List<dynamic> _comments = [];
  bool _isLoadingComments = true;
  
  // 阅读模式状态
  double _fontSize = 16.0;
  int _bgTheme = 0; 

  final List<Color> _bgColors = [Colors.white, const Color(0xFFF4ECD8), const Color(0xFF1E1E1E)];
  final List<Color> _textColors = [Colors.black87, Colors.black87, Colors.grey[300]!];

  @override
  void initState() {
    super.initState();
    _postDetailFuture = ApiClient.instance.getPostDetail(widget.cid);
    _loadUserHabits();
    _fetchComments();
    
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        setState(() {
          _readProgress = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
        });
      }
    });
  }

  Future<void> _fetchComments() async {
    try {
      final res = await http.get(Uri.parse('https://jyjswk.online/api/v1/posts/${widget.cid}/comments'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['code'] == 0 && mounted) {
          setState(() {
            _comments = data['data'] ?? [];
            _isLoadingComments = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  void _showCommentSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
          left: 20, 
          right: 20, 
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('发表评论', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(hintText: '写下你的想法...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  final text = ctrl.text.trim();
                  
                  final token = ApiClient.instance.token;
                  if (token == null || token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录后再发表评论')));
                    return;
                  }

                  Navigator.pop(ctx);
                  final username = ChatService.I.me ?? 'App用户'; 

                  try {
                    final res = await http.post(
                      Uri.parse('https://jyjswk.online/api/v1/posts/${widget.cid}/comments'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer f89bca003344e62df74348d875d1db225df55ea1bb02fbb3',
                        'Referer': 'https://jyjswk.online/',
                      },
                      body: jsonEncode({"author": username, "mail": "app@test.com", "text": text}),
                    );
                    
                    if (!context.mounted) return;
                    if (res.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论发表成功')));
                      _fetchComments();
                    } else {
                      final errData = jsonDecode(res.body);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('评论失败: ${errData['message'] ?? '未知错误'}'), 
                          backgroundColor: Colors.redAccent
                        )
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络请求失败: $e')));
                  }
                },
                child: const Text('提交'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final isFav = await LocalDbService.I.isFavorited(widget.cid);

    if (mounted) {
      setState(() {
        _fontSize = prefs.getDouble('read_font_size') ?? 16.0;
        _bgTheme = prefs.getInt('read_bg_theme') ?? 0;
        _isFavorited = isFav;
      });
    }
  }

  Future<void> _saveHabit({double? fontSize, int? bgTheme}) async {
    final prefs = await SharedPreferences.getInstance();
    if (fontSize != null) await prefs.setDouble('read_font_size', fontSize);
    if (bgTheme != null) await prefs.setInt('read_bg_theme', bgTheme);
  }

  Future<void> _toggleFavorite(Map<String, dynamic> post) async {
    final newStatus = await LocalDbService.I.toggleFavorite(
      widget.cid,
      title: post['title'],
      author: post['author'],
      content: post['text'],
    );
    
    if (mounted) {
      setState(() {
        _isFavorited = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorited ? '已加入本地收藏' : '已取消收藏'), 
          duration: const Duration(seconds: 1)
        )
      );
    }
  }

  void _showReadingSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('阅读设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 18, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: _fontSize, min: 14.0, max: 24.0, divisions: 5,
                          onChanged: (val) {
                            setModalState(() => _fontSize = val);
                            setState(() => _fontSize = val);
                            _saveHabit(fontSize: val);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 28, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildThemeBtn(0, Icons.wb_sunny, '极简白', setModalState),
                      _buildThemeBtn(1, Icons.spa, '护眼绿', setModalState),
                      _buildThemeBtn(2, Icons.nightlight_round, '暗黑', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildThemeBtn(int themeIndex, IconData icon, String label, StateSetter setModalState) {
    final isSelected = _bgTheme == themeIndex;
    return GestureDetector(
      onTap: () {
        setModalState(() => _bgTheme = themeIndex);
        setState(() => _bgTheme = themeIndex);
        _saveHabit(bgTheme: themeIndex);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgColors[themeIndex],
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey[300]!, width: isSelected ? 2 : 1),
              boxShadow: isSelected ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 8)] : [],
            ),
            child: Icon(icon, color: themeIndex == 2 ? Colors.amber : Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
        ],
      ),
    );
  }

  void _shareArticle(Map<String, dynamic> post) async {
    final selectedPeer = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactSelectPage(title: '转发给...'),
      ),
    );

    if (!mounted) return;

    if (selectedPeer != null && selectedPeer.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发送确认'),
          content: Text('确定要将文章推荐给 $selectedPeer 吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('发送')),
          ],
        )
      );

      if (!mounted) return;

      if (confirm == true) {
        _executeForward(selectedPeer, post, context);
      }
    }
  }

  void _executeForward(String peer, Map<String, dynamic> post, BuildContext dialogContext) async {
    if (peer.isEmpty) return;
    final me = ChatService.I.me;
    if (me == null) return;

    final shareMsg = '[ArticleCard]${post['cid']}|${post['title']}|${post['author']}';
    
    final localMsgId = await LocalDbService.I.insertMessage(
      owner: me, peer: peer, isMine: true, content: shareMsg, 
      timestamp: DateTime.now().millisecondsSinceEpoch, status: 0,
    );

    final ok = ChatService.I.send(peer, shareMsg);
    if (!ok) {
       await LocalDbService.I.updateMessageStatus(localMsgId, 2); 
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已成功投递给 $peer')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _bgColors[_bgTheme];
    final textColor = _textColors[_bgTheme];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('文章详情'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.tune), onPressed: _showReadingSettings)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: LinearProgressIndicator(value: _readProgress, backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent), minHeight: 2.0),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _postDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('加载出错', style: TextStyle(color: textColor)));
          if (!snapshot.hasData) return Center(child: Text('文章不存在', style: TextStyle(color: textColor)));

          final post = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thickness: 6.0,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post['title'] ?? '无标题', style: TextStyle(fontSize: _fontSize + 6, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 12),
                        Text('作者: ${post['author']}', style: const TextStyle(color: Colors.grey)),
                        const Divider(height: 30, thickness: 1),
                        MarkdownBody(
                          builders: {
                            'code': CodeBlockBuilder(textColor: textColor, fontSize: _fontSize),
                          },
                          onTapLink: (text, href, title) {
                            if (href == null || href.isEmpty) return;
                            openUrl(context, href, title: text);
                          },
                          data: post['text'] ?? '',
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            h1: TextStyle(fontSize: _fontSize + 8, fontWeight: FontWeight.bold, color: textColor, height: 2.0),
                            h2: TextStyle(fontSize: _fontSize + 5, fontWeight: FontWeight.bold, color: textColor, height: 1.8),
                            h3: TextStyle(fontSize: _fontSize + 3, fontWeight: FontWeight.bold, color: textColor, height: 1.8),
                            p: TextStyle(fontSize: _fontSize, height: 1.9, color: textColor),
                            code: TextStyle(
                              fontSize: _fontSize - 1,
                              fontFamily: 'monospace',
                              color: const Color(0xFFE06C75),
                              backgroundColor: const Color(0xFFF0F0F0),
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFF282C34),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            codeblockPadding: const EdgeInsets.all(16),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(left: BorderSide(color: Colors.blueAccent, width: 4)),
                              color: Colors.blueAccent.withOpacity(0.05),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            horizontalRuleDecoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
                            ),
                            tableHead: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: _fontSize),
                            tableBody: TextStyle(color: textColor, fontSize: _fontSize),
                            tableBorder: TableBorder.all(color: Colors.grey[300]!, width: 1),
                            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            tableColumnWidth: const FlexColumnWidth(),
                            listBullet: TextStyle(color: Colors.blueAccent, fontSize: _fontSize),
                            listIndent: 24,
                            a: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
                            strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                            em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
                          ),
                          imageBuilder: (uri, title, alt) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.black87,
                                  insetPadding: EdgeInsets.zero,
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: InteractiveViewer(
                                      child: Image.network(uri.toString(), fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(uri.toString(), fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text('文章评论 (${_comments.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                        if (_isLoadingComments) const CircularProgressIndicator()
                        else if (_comments.isEmpty) Text('暂无评论，快来抢沙发！', style: TextStyle(color: Colors.grey[500]))
                        else ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(child: Text((c['author'] as String)[0].toUpperCase())),
                              title: Text(c['author'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(c['text'], style: TextStyle(color: textColor)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 80), 
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(color: bgColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showCommentSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: _bgTheme == 2 ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                            child: const Text('写评论...', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(_isFavorited ? Icons.star : Icons.star_border, color: _isFavorited ? Colors.orange : Colors.grey), 
                        onPressed: () => _toggleFavorite(post),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.blueAccent), onPressed: () => _shareArticle(post)
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}