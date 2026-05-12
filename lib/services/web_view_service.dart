// 文件路径: lib/services/web_view_page.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, this.title = ''});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  double _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onProgress: (progress) {
            setState(() => _loadingProgress = progress / 100);
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // 提取简洁的域名用于标题栏显示
  String get _displayTitle {
    if (widget.title.isNotEmpty) return widget.title;
    try {
      return Uri.parse(_currentUrl).host;
    } catch (_) {
      return _currentUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _displayTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _currentUrl,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              // 在系统浏览器中打开（备用）
              Navigator.pop(context);
            },
            tooltip: '在浏览器中打开',
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),

          // 底部导航栏
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () async {
                      if (await _controller.canGoBack()) {
                        await _controller.goBack();
                      } else {
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    onPressed: () async {
                      if (await _controller.canGoForward()) {
                        await _controller.goForward();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.home_outlined, size: 22),
                    onPressed: () => Navigator.pop(context),
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
