import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'local_db_service.dart';

// ── 系统通知数据类 ────────────────────────────────────────────────────────────
class SystemNotification {
  final String type;   // submit / approve / reject / info
  final String title;
  final int?   cid;
  final String from;

  const SystemNotification({
    required this.type,
    required this.title,
    this.cid,
    required this.from,
  });
}

class ChatMessage {
  final int? msgId;
  final String from;
  final String to;
  final String text;
  final DateTime time;
  final bool delivered;

  ChatMessage({
    this.msgId,
    required this.from,
    required this.to,
    required this.text,
    required this.time,
    this.delivered = false,
  });
}

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService I = ChatService._();

  static const String wsUrl = 'wss://jyjswk.online/ws';

  final ValueNotifier<bool> connected = ValueNotifier(false);
  final ValueNotifier<Set<String>> onlineUsers = ValueNotifier({});

  final _msgController    = StreamController<ChatMessage>.broadcast();
  final _notifyController = StreamController<SystemNotification>.broadcast();

  Stream<ChatMessage>       get onMessage      => _msgController.stream;
  Stream<SystemNotification> get onNotification => _notifyController.stream;

  final _ackController = StreamController<({int msgId, bool delivered})>.broadcast();
  Stream<({int msgId, bool delivered})> get onAck => _ackController.stream;

  WebSocketChannel? _channel;
  String? _token;
  String? _me;
  Timer? _reconnectTimer;
  int _retrySeconds = 1;
  bool _shouldReconnect = false;

  String? get me => _me;

  Future<void> connect(String token) async {
    _token = token;
    _shouldReconnect = true;
    final url = '$wsUrl?token=${Uri.encodeQueryComponent(token)}';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        _onData,
        onError: (e) => _onClose(),
        onDone:  () => _onClose(),
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    connected.value = false;
    onlineUsers.value = {};
    _me = null;
  }

  void _onClose() {
    connected.value = false;
    onlineUsers.value = {};
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _token == null) return;
    _reconnectTimer?.cancel();
    final delay = _retrySeconds.clamp(1, 60);
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _retrySeconds = (_retrySeconds * 2).clamp(1, 60);
      connect(_token!);
    });
  }

  void _onData(dynamic raw) {
    final j = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (j['type']) {
      case 'hello':
        _me = j['you'] as String;
        onlineUsers.value = Set<String>.from(j['online_users'] as List? ?? []);
        connected.value = true;
        _retrySeconds = 1;
        notifyListeners();
        break;

      case 'msg':
        final from = j['from'] as String;
        final text = j['text'] as String;
        final ts   = j['ts'] as int? ?? 0;
        final time = DateTime.fromMillisecondsSinceEpoch(ts * 1000);

        // ── 系统通知消息：格式 [NOTIFY]type|title|cid ──────────────────────
        if (text.startsWith('[NOTIFY]')) {
          final content = text.substring('[NOTIFY]'.length);
          final parts   = content.split('|');
          _notifyController.add(SystemNotification(
            type:  parts.isNotEmpty ? parts[0] : 'info',
            title: parts.length > 1  ? parts[1] : content,
            cid:   parts.length > 2  ? int.tryParse(parts[2]) : null,
            from:  from,
          ));
          return; // 不进入聊天流
        }

        // ── 普通聊天消息 ────────────────────────────────────────────────────
        LocalDbService.I.insertMessage(
          owner: _me ?? '',
          peer: from,
          isMine: false,
          content: text,
          timestamp: time.millisecondsSinceEpoch,
        );
        _msgController.add(ChatMessage(
          msgId: j['msg_id'] as int?,
          from: from,
          to: _me ?? '',
          text: text,
          time: time,
        ));
        break;

      case 'ack':
        final id = j['msg_id'] as int?;
        if (id != null) {
          _ackController.add((msgId: id, delivered: j['delivered'] as bool? ?? false));
        }
        break;

      case 'presence':
        final user   = j['user'] as String;
        final online = j['online'] as bool? ?? false;
        final s = Set<String>.from(onlineUsers.value);
        if (online) {
          s.add(user);
        } else {
          s.remove(user);
        }
        onlineUsers.value = s;
        break;

      case 'error':
        debugPrint('WS Error: ${j['message']} (Code: ${j['code']})');
        break;
    }
  }

  bool send(String to, String text) {
    if (!connected.value || _channel == null) return false;
    _channel!.sink.add(jsonEncode({'type': 'send', 'to': to, 'text': text}));
    return true;
  }
}