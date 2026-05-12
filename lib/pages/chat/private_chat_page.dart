// 文件路径: lib/pages/chat/private_chat_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/chat_service.dart';
import '../../services/local_db_service.dart';
import '../../services/api_client.dart';
import '../blog/blog_detail_page.dart';

class PrivateChatPage extends StatefulWidget {
  final String peer;
  final String? peerNickname;
  final String? peerAvatarUrl;
  final String? myAvatarUrl;

  const PrivateChatPage({
    super.key,
    required this.peer,
    this.peerNickname,
    this.peerAvatarUrl,
    this.myAvatarUrl,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final _input = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatBubble> _messages = [];
  
  String? _replyingToText;
  bool _isUploadingImage = false;

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<({int msgId, bool delivered})>? _ackSub;

  @override
  void initState() {
    super.initState();
    _msgSub = ChatService.I.onMessage.listen((m) {
      if (m.from == widget.peer || m.to == widget.peer) {
        if (mounted) {
          setState(() {
            _messages.add(_buildBubble(m.msgId, m.from, m.to, m.text, m.time, m.delivered));
          });
          _scrollToBottom();
        }
      }
    });

    _ackSub = ChatService.I.onAck.listen((ack) {
      final i = _messages.indexWhere((m) => m.msgId == ack.msgId);
      if (i >= 0 && mounted) {
        setState(() {
          _messages[i] = _buildBubble(_messages[i].msgId, _messages[i].from, _messages[i].to, _messages[i].text, _messages[i].time, ack.delivered);
        });
      }
    });

    ChatService.I.onlineUsers.addListener(_onChange);
    final me = ChatService.I.me ?? '';
    LocalDbService.I.markAsRead(me, widget.peer);
    _loadHistory();
  }

  ChatBubble _buildBubble(int? msgId, String from, String to, String text, DateTime time, bool delivered) {
    return ChatBubble(
      msgId: msgId,
      from: from,
      to: to,
      text: text,
      time: time,
      delivered: delivered,
      peerAvatarUrl: widget.peerAvatarUrl,
      myAvatarUrl: widget.myAvatarUrl,
      onQuote: (quoteText) {
        setState(() => _replyingToText = quoteText);
      },
    );
  }

  Future<void> _loadHistory() async {
    final me = ChatService.I.me ?? '';
    final history = await LocalDbService.I.getChatHistory(me, widget.peer);

    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (var row in history) {
        final isMine = row['is_mine'] == 1;
        _messages.add(_buildBubble(
          null, 
          isMine ? me : widget.peer, 
          isMine ? widget.peer : me, 
          row['content'] as String, 
          DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int), 
          true
        ));
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _ackSub?.cancel();
    ChatService.I.onlineUsers.removeListener(_onChange);
    _input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final token = ApiClient.instance.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未登录无法发图')));
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://jyjswk.online/api/v1/upload/avatar'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path, contentType: MediaType('image', 'jpeg')));

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data']['avatar_url'] != null) {
          final imageUrl = data['data']['avatar_url'];
          _input.text = '[Image]$imageUrl';
          _send(); 
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('图片发送失败')));
      }
    } catch (e) {
      debugPrint('上传图片异常: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _send() async {
    final rawText = _input.text.trim();
    if (rawText.isEmpty) return;

    final me = ChatService.I.me;
    if (me == null) return;

    String finalMsg = rawText;
    if (_replyingToText != null) {
      String cleanQuote = _replyingToText!.replaceAll('\n', ' ').trim();
      String snippet = cleanQuote.length > 20 ? '${cleanQuote.substring(0, 20)}...' : cleanQuote;
      finalMsg = '[Quote]$snippet|$rawText';
    }

    _input.clear();
    setState(() => _replyingToText = null); 
    final nowTime = DateTime.now();
    
    final localMsgId = await LocalDbService.I.insertMessage(
      owner: me, peer: widget.peer, isMine: true, content: finalMsg, timestamp: nowTime.millisecondsSinceEpoch, status: 0,
    );

    setState(() => _messages.add(_buildBubble(localMsgId, me, widget.peer, finalMsg, nowTime, false)));
    _scrollToBottom();

    final ok = ChatService.I.send(widget.peer, finalMsg);
    if (!ok) {
       await LocalDbService.I.updateMessageStatus(localMsgId, 2);
       _updateUiMsgStatus(localMsgId, 2);
    }
  }

  void _updateUiMsgStatus(int msgId, int status) {
     if (!mounted) return;
     final i = _messages.indexWhere((m) => m.msgId == msgId);
     if (i >= 0) {
        setState(() {
           _messages[i] = _buildBubble(_messages[i].msgId, _messages[i].from, _messages[i].to, _messages[i].text, _messages[i].time, status == 1);
        });
     }
  }

  @override
  Widget build(BuildContext context) {
    final isPeerOnline = ChatService.I.onlineUsers.value.contains(widget.peer);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerNickname ?? widget.peer, style: const TextStyle(fontSize: 18)),
            Text(isPeerOnline ? '● 在线' : '○ 离线', style: TextStyle(fontSize: 12, color: isPeerOnline ? Colors.greenAccent : Colors.grey[400])),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollCtrl,
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _messages[index],
              ),
            ),
          ),
          
          if (_replyingToText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blueAccent.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_replyingToText!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blueAccent))),
                  GestureDetector(
                    onTap: () => setState(() => _replyingToText = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploadingImage 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate, color: Colors.blueAccent),
                    onPressed: _isUploadingImage ? null : _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: '发送消息...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true, fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final int? msgId;
  final String from;
  final String to;
  final String text;
  final DateTime time;
  final bool delivered;
  final String? myAvatarUrl;
  final String? peerAvatarUrl;
  final Function(String)? onQuote;

  const ChatBubble({
    super.key,
    this.msgId,
    required this.from,
    required this.to,
    required this.text,
    required this.time,
    required this.delivered,
    this.myAvatarUrl,
    this.peerAvatarUrl,
    this.onQuote,
  });

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bool isMine = (from == ChatService.I.me);
    final bool isArticleCard = text.startsWith('[ArticleCard]');
    final bool isQuote = text.startsWith('[Quote]');
    final bool isImage = text.startsWith('[Image]');

    String quoteText = '';
    String realText = text;
    if (isQuote) {
      final splitIndex = text.indexOf('|');
      if (splitIndex != -1) {
        quoteText = text.substring(7, splitIndex);
        realText = text.substring(splitIndex + 1);
      } else {
        realText = text.substring(7); 
      }
    }

    Widget buildImageBubble() {
      final url = text.substring(7); 
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(child: Image.network(url)), 
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, width: 200, fit: BoxFit.cover),
        ),
      );
    }

    Widget buildAvatar(String? url) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
        backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
        child: (url == null || url.isEmpty)
            ? const Icon(Icons.person, size: 20, color: Colors.blueAccent)
            : null,
      );
    }

    Widget buildArticleCard() {
      final parts = text.substring(13).split('|');
      if (parts.length < 3) return const Text('文章解析失败');
      final cid = int.tryParse(parts[0]) ?? 0;
      final title = parts[1];
      final author = parts[2];

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlogDetailPage(cid: cid),
            ),
          );
        },
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.article, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 4),
                  Text('文章推荐', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              const Divider(),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('作者: $author', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    Widget buildTextAndQuote() {
      return Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMine ? Colors.blueAccent : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Text(
              realText,
              style: TextStyle(color: isMine ? Colors.white : Colors.black87, fontSize: 15),
            ),
          ),
          if (isQuote)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 2,
                        color: Colors.grey[400],
                        margin: const EdgeInsets.symmetric(vertical: 2)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        quoteText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            buildAvatar(peerAvatarUrl),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                if (onQuote != null && !isArticleCard && !isImage) onQuote!(realText);
              },
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isArticleCard) buildArticleCard()
                  else if (isImage) buildImageBubble()
                  else buildTextAndQuote(),
                  
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMine)
                        Icon(
                          delivered ? Icons.done_all : Icons.access_time,
                          size: 14,
                          color: delivered ? Colors.blue : Colors.grey,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(time),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            buildAvatar(myAvatarUrl),
          ],
        ],
      ),
    );
  }
}