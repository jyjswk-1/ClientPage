// 文件路径: lib/widgets/rss_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../pages/utils/webviewer.dart';

class RssPage extends StatefulWidget {
  const RssPage({super.key});

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> {
  late Future<List<dynamic>> _rssFuture;

  @override
  void initState() {
    super.initState();
    _rssFuture = ApiClient.instance.getRssFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
              child: const Text('RSS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            const Text('订阅动态', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _rssFuture = ApiClient.instance.getRssFeed()),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _rssFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('加载失败', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _rssFuture = ApiClient.instance.getRssFeed()),
                  child: const Text('重试'),
                ),
              ]),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.rss_feed, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('暂无订阅内容', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 6),
                Text('请在博客后台配置 RssFeed 插件的 RSS 源',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ]),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final item   = items[index];
              final title  = item['title']       as String? ?? '';
              final link   = item['link']        as String? ?? '';
              final desc   = item['description'] as String? ?? '';
              final source = item['source']      as String? ?? '';
              final author = item['author']      as String? ?? '';
              final date   = item['pubDate']     as String? ?? '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      [if (source.isNotEmpty) '🚉 $source', if (author.isNotEmpty) '✍️ $author', date]
                          .join('  '),
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => openUrl(context, link, title: title),
              );
            },
          );
        },
      ),
    );
  }
}