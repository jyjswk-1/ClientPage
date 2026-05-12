// 文件路径: lib/pages/blog/blog_push.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';

class WritePostPage extends StatefulWidget {
  final int? cid;
  final String? initialTitle;
  final String? initialText;

  const WritePostPage({
    super.key,
    this.cid,
    this.initialTitle,
    this.initialText,
  });

  @override
  State<WritePostPage> createState() => _WritePostPageState();
}

class _WritePostPageState extends State<WritePostPage> {
  final _titleCtrl = TextEditingController();
  final _textCtrl  = TextEditingController();
  bool _isPreview    = false;
  bool _isSaving     = false;
  bool _isPublishing = false;

  List<Map<String, dynamic>> _categories = [];
  int _selectedCategoryId = 1;
  // 修复 Bug 1：用标志位记录用户是否已手动选过分类，防止异步加载覆盖用户选择
  bool _userChangedCategory = false;

  final _tagsCtrl = TextEditingController();
  List<dynamic> _availableTags = [];

  // 当前草稿的 cid（新建后服务端返回）
  int? _draftCid;

  bool get _isEdit => widget.cid != null;
  bool get _isContributor => ApiClient.instance.userGroup == 'contributor';

  String get _prefKeyTitle =>
      'draft_title_${ApiClient.instance.currentUsername ?? 'guest'}';
  String get _prefKeyText =>
      'draft_text_${ApiClient.instance.currentUsername ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _draftCid = widget.cid;
    if (widget.initialTitle != null) _titleCtrl.text = widget.initialTitle!;
    if (widget.initialText  != null) _textCtrl.text  = widget.initialText!;
    _loadCategories();
    _loadAvailableTags();
    _restoreDraft();
  }

  @override
  void dispose() {
    _autoSaveDraftLocally();
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ── 本地草稿恢复（新建模式）────────────────────────────────────────────────
  Future<void> _restoreDraft() async {
    if (_isEdit) return;
    final prefs = await SharedPreferences.getInstance();
    final savedTitle = prefs.getString(_prefKeyTitle) ?? '';
    final savedText  = prefs.getString(_prefKeyText)  ?? '';
    if (savedTitle.isNotEmpty && _titleCtrl.text.isEmpty) {
      _titleCtrl.text = savedTitle;
    }
    if (savedText.isNotEmpty && _textCtrl.text.isEmpty) {
      _textCtrl.text = savedText;
    }
  }

  // ── 退出时保存到本地，防止内容丢失 ─────────────────────────────────────────
  Future<void> _autoSaveDraftLocally() async {
    if (_isEdit) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTitle, _titleCtrl.text);
    await prefs.setString(_prefKeyText,  _textCtrl.text);
  }

  // ── 清除本地草稿缓存 ────────────────────────────────────────────────────────
  Future<void> _clearLocalDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyTitle);
    await prefs.remove(_prefKeyText);
  }

  // 修复 Bug 1：_loadCategories 加载完成后，只在用户未手动选过分类时才设默认值
  Future<void> _loadCategories() async {
    final list = await ApiClient.instance.fetchCategories();
    if (mounted) {
      setState(() {
        _categories =
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (_categories.isNotEmpty && !_userChangedCategory) {
          _selectedCategoryId = _categories.first['mid'] as int;
        }
      });
    }
  }

  // 拉取现有标签，供写文章时快速选择
  Future<void> _loadAvailableTags() async {
    final tags = await ApiClient.instance.getHotTags();
    if (mounted) setState(() => _availableTags = tags);
  }

  // 点击标签 chip 时追加到标签输入框
  void _appendTag(String tagName) {
    final current = _tagsCtrl.text.trim();
    final existing = current.isEmpty
        ? <String>[]
        : current.split('#').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (existing.contains(tagName)) return;
    _tagsCtrl.text = existing.isEmpty
        ? '#$tagName'
        : '${_tagsCtrl.text.trimRight()} #$tagName';
    _tagsCtrl.selection = TextSelection.collapsed(offset: _tagsCtrl.text.length);
  }

  // ── 保存为草稿（不关闭页面）────────────────────────────────────────────────
  Future<void> _saveDraft() async {
    final title = _titleCtrl.text.trim();
    final text  = _textCtrl.text.trim();
    if (title.isEmpty) { _snack('标题不能为空'); return; }

    setState(() => _isSaving = true);
    try {
      final result = await _sendToServer(title, text, 'draft');
      if (result != null) {
        // 修复 Bug 2：保存草稿后确保 _draftCid 正确赋值，并打印警告
        final newCid = result['cid'] as int?;
        if (newCid == null) {
          debugPrint('⚠️ 保存草稿成功但服务端未返回 cid，后续提交将创建新文章！');
        }
        _draftCid = newCid ?? _draftCid; // 保留旧值兜底，防止被 null 覆盖
        await _clearLocalDraft();
        _snack('草稿已保存 ✓');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── 发布（contributor → 提交审核；admin/editor → 直接发布）────────────────
  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    final text  = _textCtrl.text.trim();
    if (title.isEmpty) { _snack('标题不能为空'); return; }
    if (text.isEmpty)  { _snack('正文不能为空'); return; }

    setState(() => _isPublishing = true);
    try {
      final result = await _sendToServer(title, text, 'publish');
      debugPrint('publish result: $result'); // 方便排查服务端返回内容
      if (result != null) {
        final actualStatus = result['status'] as String? ?? 'publish';
        await _clearLocalDraft();

        final msg = actualStatus == 'waiting'
            ? '已提交审核，请等待管理员审批'
            : '文章已发布 ✓';
        _snack(msg);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ── 统一发送请求 ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _sendToServer(
      String title, String text, String status) async {
    final token = ApiClient.instance.token;
    final tags  = _tagsCtrl.text
        .split('#')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final body = jsonEncode({
      'title': title,
      'text': text,
      'category_id': _selectedCategoryId,
      'tags': tags,
      'status': status,
    });

    try {
      final http.Response res;
      final cid = _draftCid ?? widget.cid;

      if (cid != null) {
        res = await http.put(
          Uri.parse('${ApiClient.baseUrl}/posts/$cid/update'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        );
      } else {
        res = await http.post(
          Uri.parse('${ApiClient.baseUrl}/posts/create'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        );
      }

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['code'] == 0) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      } else {
        _snack('操作失败: ${data['message'] ?? '未知错误'}');
        return null;
      }
    } catch (e) {
      _snack('网络错误: $e');
      return null;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(_isEdit ? '编辑文章' : '写文章'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          // 预览切换
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.preview),
            tooltip: _isPreview ? '编辑' : '预览',
            onPressed: () => setState(() => _isPreview = !_isPreview),
          ),

          // 保存草稿按钮
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _saveDraft,
                  child: const Text('保存',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.w500)),
                ),

          // 发布按钮
          _isPublishing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: _publish,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    child: Text(_isContributor ? '提交审核' : '发布'),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // 标题
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleCtrl,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '文章标题...',
                border: InputBorder.none,
              ),
              maxLines: 1,
            ),
          ),
          const Divider(height: 1),

          // 分类 + 标签
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _categories.any(
                            (c) => c['mid'] == _selectedCategoryId)
                        ? _selectedCategoryId
                        : null,
                    isDense: true,
                    items: _categories
                        .map((c) => DropdownMenuItem<int>(
                              value: c['mid'] as int,
                              child: Text(c['name'] as String,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedCategoryId = v;
                          // 修复 Bug 1：标记用户已手动选择，防止 _loadCategories 覆盖
                          _userChangedCategory = true;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.label_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _tagsCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '# 标签',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 现有标签快速选择
          if (_availableTags.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('标签', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _availableTags.map((tag) {
                        final name = tag['name'] as String;
                        return GestureDetector(
                          onTap: () => _appendTag(name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Text(
                              '# $name',
                              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

          // 正文
          Expanded(
            child: _isPreview ? _buildPreview() : _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _textCtrl,
        maxLines: null,
        expands: true,
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 14, height: 1.7),
        decoration: const InputDecoration(
          hintText: '用 Markdown 写下你的想法...',
          border: InputBorder.none,
        ),
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _textCtrl.text.isEmpty ? '（正文为空）' : _textCtrl.text,
        style: const TextStyle(fontSize: 15, height: 1.8),
      ),
    );
  }
}