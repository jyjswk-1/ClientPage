import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  LocalDbService._internal();
  static final LocalDbService instance = LocalDbService._internal();
  static LocalDbService get I => instance;

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'chat_local.db');

    _db = await openDatabase(
      path,
      version: 2,                        // ← version 升到 2
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  // ── 首次创建：建所有表 ──────────────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        owner     TEXT    NOT NULL,
        peer      TEXT    NOT NULL,
        is_mine   INTEGER NOT NULL,
        content   TEXT    NOT NULL,
        timestamp INTEGER NOT NULL,
        status    INTEGER NOT NULL DEFAULT 1,
        is_read   INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_owner_peer ON messages (owner, peer)');

    await db.execute('''
      CREATE TABLE favorites (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        cid       INTEGER UNIQUE,
        title     TEXT,
        author    TEXT,
        content   TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE local_notifications (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        type       TEXT    NOT NULL,
        title      TEXT    NOT NULL,
        cid        INTEGER,
        is_read    INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // ── 版本升级：安全地补新表/新字段 ──────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 补 local_notifications 表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_notifications (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          type       TEXT    NOT NULL,
          title      TEXT    NOT NULL,
          cid        INTEGER,
          is_read    INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
    }
  }

  // ── 打开时补丁：兼容已存在的旧数据库 ──────────────────────────────────────
  Future<void> _onOpen(Database db) async {
    // 补 is_read 字段（旧版没有）
    try {
      await db.execute('ALTER TABLE messages ADD COLUMN is_read INTEGER DEFAULT 0');
    } catch (_) {}

    // 补 favorites 表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        cid       INTEGER UNIQUE,
        title     TEXT,
        author    TEXT,
        content   TEXT,
        timestamp INTEGER
      )
    ''');

    // 补 local_notifications 表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_notifications (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        type       TEXT    NOT NULL,
        title      TEXT    NOT NULL,
        cid        INTEGER,
        is_read    INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // ═══════════════════════════════════════════════════════════
  // 消息相关
  // ═══════════════════════════════════════════════════════════

  Future<int> insertMessage({
    required String owner,
    required String peer,
    required bool   isMine,
    required String content,
    int? timestamp,
    int status = 1,
  }) async {
    return await _db?.insert('messages', {
      'owner':     owner,
      'peer':      peer,
      'is_mine':   isMine ? 1 : 0,
      'content':   content,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'status':    status,
    }) ?? 0;
  }

  Future<void> updateMessageStatus(int id, int status) async {
    await _db?.update('messages', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String owner, String peer) async {
    if (_db == null) return [];
    return _db!.query('messages', where: 'owner = ? AND peer = ?', whereArgs: [owner, peer], orderBy: 'timestamp ASC');
  }

  Future<int> getUnreadCount(String owner, String peer) async {
    if (_db == null) return 0;
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE owner = ? AND peer = ? AND is_mine = 0 AND is_read = 0',
      [owner, peer],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAsRead(String owner, String peer) async {
    await _db?.update('messages', {'is_read': 1},
        where: 'owner = ? AND peer = ? AND is_mine = 0 AND is_read = 0',
        whereArgs: [owner, peer]);
  }

  // ═══════════════════════════════════════════════════════════
  // 收藏相关
  // ═══════════════════════════════════════════════════════════

  Future<bool> isFavorited(int cid) async {
    if (_db == null) return false;
    final maps = await _db!.query('favorites', where: 'cid = ?', whereArgs: [cid]);
    return maps.isNotEmpty;
  }

  Future<bool> toggleFavorite(int cid, {String? title, String? author, String? content}) async {
    if (_db == null) return false;
    final isFav = await isFavorited(cid);
    if (isFav) {
      await _db!.delete('favorites', where: 'cid = ?', whereArgs: [cid]);
      return false;
    } else {
      await _db!.insert('favorites', {
        'cid':       cid,
        'title':     title  ?? '无标题',
        'author':    author ?? '未知作者',
        'content':   content ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> getFavoriteList() async {
    if (_db == null) return [];
    return _db!.query('favorites', orderBy: 'timestamp DESC');
  }

  // ═══════════════════════════════════════════════════════════
  // 本地通知相关
  // ═══════════════════════════════════════════════════════════

  Future<void> insertNotification({
    required String type,
    required String title,
    int? cid,
  }) async {
    await _db?.insert('local_notifications', {
      'type':       type,
      'title':      title,
      'cid':        cid,
      'is_read':    0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getLocalNotifications() async {
    if (_db == null) return [];
    return _db!.query('local_notifications', orderBy: 'created_at DESC', limit: 50);
  }

  Future<int> getUnreadNotificationCount() async {
    if (_db == null) return 0;
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM local_notifications WHERE is_read = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markLocalNotificationRead({int? id}) async {
    if (_db == null) return;
    if (id != null) {
      await _db!.update('local_notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
    } else {
      await _db!.update('local_notifications', {'is_read': 1});
    }
  }
}