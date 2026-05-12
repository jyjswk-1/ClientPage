import 'dart:async';
import '../../services/api_client.dart';
import '../../services/local_db_service.dart';

class PostStatusChecker {
  static final PostStatusChecker I = PostStatusChecker._();
  PostStatusChecker._();

  Timer? _timer;
  final Map<int, String> _lastStatus = {};
  void Function(String title, String oldStatus, String newStatus)? onStatusChanged;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
    _check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final posts = await ApiClient.instance.getMyPosts();
      for (final p in posts) {
        final cid    = p['cid'] as int;
        final title  = p['title'] as String;
        final status = p['status'] as String;

        if (_lastStatus.containsKey(cid) && _lastStatus[cid] != status) {
          onStatusChanged?.call(title, _lastStatus[cid]!, status);

          final msg = status == 'publish'
              ? '您的文章「$title」已通过审核并发布'
              : status == 'hidden'
                  ? '您的文章「$title」未通过审核'
                  : '您的文章「$title」状态变更为 $status';

          // ✅ 写入本地通知数据库
          await LocalDbService.I.insertNotification(
            type:  status == 'publish' ? 'approve' : 'reject',
            title: msg,
            cid:   cid,
          );

          // 同步服务端（有网时）
          try {
            await ApiClient.instance.createNotification(
              toUser: ApiClient.instance.currentUsername ?? '',
              type:   status == 'publish' ? 'approve' : 'reject',
              title:  msg,
              cid:    cid,
            );
          } catch (_) {}
        }
        _lastStatus[cid] = status;
      }
    } catch (_) {}
  }
}