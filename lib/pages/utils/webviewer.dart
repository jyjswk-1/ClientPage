// lib/services/utils.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/web_view_service.dart';

Future<void> openUrl(BuildContext context, String url, {String title = ''}) async {
  if (url.isEmpty) return;
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    return;
  }
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => WebViewPage(url: url, title: title),
  ));
}