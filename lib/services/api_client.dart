// 文件路径: lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  bool isAdmin = false;
  String userGroup = 'app';
  static const String baseUrl = 'https://jyjswk.online/api/v1';
  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  String? _token;
  String? get token => _token;
  String? currentUsername; // 登录后在 fetchMe 里赋值
  final ValueNotifier<bool> isLoggedInStatus = ValueNotifier<bool>(false);

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      validateStatus: (status) => true,
      // ✅ 修复一：全局设置 JSON Content-Type，解决 400 Invalid JSON body
      contentType: 'application/json',
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_token == null) {
          final prefs = await SharedPreferences.getInstance();
          _token = prefs.getString('auth_token');
        }
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
    ));
    _checkInitialLoginState();
  }

  Future<void> _checkInitialLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    isLoggedInStatus.value = _token != null;
    if (_token != null) await fetchMe();
  }

  Future<void> fetchMe() async {
    try {
      final response = await _dio.get('/me');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['code'] == 0) {
          userGroup = data['data']['group'] ?? 'app';
          isAdmin = data['data']['is_admin'] == true;
          currentUsername = data['data']['username'];
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // 1. 博客内容相关 API
  // ==========================================
  Future<Map<String, dynamic>> ping() async {
    final response = await _dio.get('/ping');
    return _unwrap(response.data);
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data']);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<List<dynamic>> getPosts({int page = 1, int perPage = 10, int? categoryId}) async {
    String url = '$baseUrl/posts?page=$page&per_page=$perPage';
    if (categoryId != null && categoryId > 0) {
      url += '&category_id=$categoryId';
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['code'] == 0) return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getMyPosts() async {
    final response = await _dio.get('/posts/mine');
    final raw = response.data;
    if (raw is Map && raw['code'] == 0 && raw['data'] is List) {
      return raw['data'] as List;
    }
    return [];
  }

  Future<void> createNotification({
    required String toUser,
    required String type,
    required String title,
    int? cid,
  }) async {
    await _dio.post('/notifications/create', data: {
      'to_user': toUser,
      'type': type,
      'title': title,
      if (cid != null) 'cid': cid,
    });
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await _dio.get('/notifications');
    final raw = response.data;
    if (raw is Map && raw['code'] == 0 && raw['data'] is List) {
      return raw['data'] as List;
    }
    return [];
  }

  Future<void> markNotificationRead({int? id}) async {
    await _dio.post('/notifications/read', data: id != null ? {'id': id} : {});
  }

  Future<Map<String, dynamic>> getPostDetail(int cid) async {
    final response = await _dio.get('/posts/$cid');
    return _unwrap(response.data);
  }

  Future<Map<String, dynamic>> askAi(String text) async {
    final response = await _dio.post('/ai/ask', data: {'question': text});
    return _unwrap(response.data);
  }

  Future<List<dynamic>> fetchCategories() async {
    final res = await http.get(Uri.parse('$baseUrl/categories'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['code'] == 0) return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getHotTags() async {
    final response = await _dio.get('/tags');
    final raw = response.data;
    if (raw is Map && raw['code'] == 0 && raw['data'] is List) {
      return raw['data'] as List;
    }
    return [];
  }

  Future<List<dynamic>> searchArticles(String keyword, {int page = 1}) async {
    final q = Uri.encodeComponent(keyword);
    final res = await http.get(Uri.parse('$baseUrl/search?q=$q&page=$page&per_page=10'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['code'] == 0) return data['data'] as List<dynamic>;
    }
    return [];
  }

  // ==========================================
  // 2. 用户账号与认证相关 API
  // ==========================================

  Future<bool> register(String username, String password) async {
    try {
      final response = await _dio.post('/user/register', data: {
        'username': username,
        'password': password,
      });
      if (response.statusCode == 409) throw Exception('该账号已被注册');
      if (response.statusCode == 400) throw Exception('账号或密码格式不符合要求');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('注册失败 (服务器状态码: ${response.statusCode})');
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post('/user/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 401) throw Exception('账号或密码错误');
      if (response.statusCode != 200) {
        throw Exception('登录失败 (服务器状态码: ${response.statusCode})');
      }

      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          int startIndex = rawData.indexOf('{');
          if (startIndex != -1) {
            rawData = jsonDecode(rawData.substring(startIndex));
          }
        } catch (_) {}
      }

      if (rawData == null || rawData is! Map) {
        throw Exception('解析服务器数据失败。原始返回:\n${response.data}');
      }

      String? extractedToken;
      if (rawData['data'] != null && rawData['data']['token'] != null) {
        extractedToken = rawData['data']['token'];
      } else if (rawData['token'] != null) {
        extractedToken = rawData['token'];
      }

      if (extractedToken == null) {
        throw Exception('未找到 Token 字段，服务器真实返回:\n$rawData');
      }

      _token = extractedToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      isLoggedInStatus.value = true;

      // ✅ 修复二：登录成功后立即拉取用户信息，更新 userGroup 和 isAdmin
      await fetchMe();

      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    userGroup = 'app';
    isAdmin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    isLoggedInStatus.value = false;
  }

  // ==========================================
  // 3. 聊天大厅相关 API
  // ==========================================
  String? myAvatarUrl;

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _dio.get('/users');
    final raw = response.data;
    final list = (raw is Map && raw['data'] is List)
        ? raw['data'] as List
        : (raw is List ? raw : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ==========================================
  // 4. RSS 订阅 API
  // ==========================================

  Future<List<dynamic>> getRssFeed() async {
    final response = await _dio.get('/rss/feed');
    final raw = response.data;
    if (raw is Map && raw['code'] == 0 && raw['data'] is List) {
      return raw['data'] as List;
    }
    return [];
  }
}