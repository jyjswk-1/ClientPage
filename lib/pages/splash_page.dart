// 文件路径: lib/pages/splash_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
// ⚠️ 这里引入你原本的首页，比如 main.dart 里的 MainWrapper 或者 BlogListPage
// import '../main.dart'; 

class SplashPage extends StatefulWidget {
  final Widget nextScreen; // 动画结束后跳转的页面

  const SplashPage({super.key, required this.nextScreen});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  bool _startAnimation = false;

  @override
  void initState() {
    super.initState();
    // 延迟一丁点时间后触发动画，让视觉有个缓冲
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _startAnimation = true);
    });

    // 假设开屏动画持续 2.5 秒，之后跳转到主页
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
            // 使用渐变过渡动画切换到主页
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent, // 炫酷的科技蓝底色
      body: Center(
        child: AnimatedOpacity(
          opacity: _startAnimation ? 1.0 : 0.0, // 渐现效果
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeIn,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.5, end: 1.0), // 从 0.5 倍放大到 1.0 倍
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutBack, // 带有轻微回弹的弹性动画
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 中心图标 (可以用你设计好的 assets 图片，这里用 Icon 演示)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: const Icon(Icons.menu_book_rounded, size: 64, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 24),
                    // App 名称
                    const Text(
                      'PageClient', 
                      style: TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Slogan
                    Text(
                      "Family of Chipmunk' s Blogs", 
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 4.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}