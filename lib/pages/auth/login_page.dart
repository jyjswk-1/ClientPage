// 文件路径: lib/pages/auth/login_page.dart
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoginMode = true; // 控制当前是登录还是注册模式
  bool _isLoading = false;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('账号和密码不能为空')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        final success = await ApiClient.instance.login(username, password);
        
        // 🌟 护身符：检查页面是否还在，完美消除所有的蓝色波浪线警告！
        if (!mounted) return; 
        
        if (success) {
          final token = ApiClient.instance.token;
          if (token != null) ChatService.I.connect(token);

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录成功！')));
          // 登录成功后，关闭当前页面，并携带 true 通知个人中心刷新！
          Navigator.pop(context, true); 
        }
      } else {
        final success = await ApiClient.instance.register(username, password);
        
        if (!mounted) return; 
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
          setState(() => _isLoginMode = true);
        }
      }
    } catch (e) {
      if (!mounted) return; 
      // 遇到报错，漂亮地弹窗显示
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginMode ? '欢迎回来' : '加入我们'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_person, size: 80, color: Colors.blueAccent.withValues(alpha: 0.8)),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '账号',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_isLoginMode ? '登 录' : '注 册', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoginMode = !_isLoginMode; // 切换模式
                });
              },
              child: Text(_isLoginMode ? '没有账号？点击注册' : '已有账号？点击登录'),
            )
          ],
        ),
      ),
    );
  }
}