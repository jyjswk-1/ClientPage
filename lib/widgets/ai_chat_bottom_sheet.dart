// 文件路径: lib/widgets/ai_chat_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../services/api_client.dart';

class AiChatBottomSheet extends StatefulWidget {
  final int currentContextIndex; // 0:文章列表, 1:用户交流, 2:个人中心

  const AiChatBottomSheet({super.key, required this.currentContextIndex});

  @override
  State<AiChatBottomSheet> createState() => _AiChatBottomSheetState();
}

class _AiChatBottomSheetState extends State<AiChatBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 根据唤醒 AI 时的页面，给出不同的开场白！
    String greeting = '你好！';
    if (widget.currentContextIndex == 0) greeting = '我在帮你看着文章列表呢，想找哪类文章？';
    if (widget.currentContextIndex == 1) greeting = '这里是交流区，需要我帮你总结大家的讨论吗？';
    if (widget.currentContextIndex == 2) greeting = '这里是你的个人中心，有什么账号设置的问题可以问我。';
    
    _messages.add({'role': 'ai', 'content': greeting});
  }

  // ... (保留你原来的 _sendMessage 和 _scrollToBottom 逻辑，完全不用改)
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      // 进阶玩法：你以后甚至可以把 widget.currentContextIndex 发给后端，让 AI 结合页面回答
      final result = await ApiClient.instance.askAi(text); 
      setState(() {
        _messages.add({'role': 'ai', 'content': result['answer'] as String});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'content': '网络异常：$e'});
      });
    } finally {
      setState(() { _isLoading = false; });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 这是一个高度占屏幕 80% 的底部面板
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 弹窗顶部的一个小把手，提示用户可以下拉关闭
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('智能领航员', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          
          // --- 下面直接复用你原来 AI 聊天的 Expanded 消息列表和底部输入框 ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[500] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                      ),
                    ),
                    child: MarkdownBody(
                      data: msg['content'] ?? '',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: isUser ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          
          // 输入框
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8, // 适配键盘高度
              left: 12, right: 12, top: 8
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '输入指令...',
                      filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}