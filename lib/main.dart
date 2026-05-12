import 'package:flutter/material.dart';
import 'package:page_client/pages/main_page.dart';
// import 'pages/main_page.dart';
import 'pages/splash_page.dart';
import 'services/api_client.dart';
import 'services/chat_service.dart';
import 'services/local_db_service.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() async {
  // 等 ApiClient 初始化完成(它构造时会异步读 token)
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; // 替换默认的数据库工厂
  }
  // 初始化本地数据库
  await LocalDbService.I.init();
  
  // 监听登录状态:已登录就连 WS,登出就断
  // 这样无论是启动时已登录,还是后续登录/登出,都自动处理
  ApiClient.instance.isLoggedInStatus.addListener(() {
    if (ApiClient.instance.isLoggedInStatus.value) {
      final token = ApiClient.instance.token;
      if (token != null) ChatService.I.connect(token);
    } else {
      ChatService.I.disconnect();
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Blog App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50], 
      ),
      home: const SplashPage(
        nextScreen: MainPage(), // 开机页面
      ),
    );
  }
}