import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyButton extends StatefulWidget {
  final String code;
  const CopyButton({super.key, required this.code});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.code));
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _copied
            ? const Row(
                key: ValueKey('copied'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Color(0xFF98C379)),
                  SizedBox(width: 4),
                  Text('已复制', style: TextStyle(color: Color(0xFF98C379), fontSize: 12)),
                ],
              )
            : const Row(
                key: ValueKey('copy'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 14, color: Color(0xFF5C6370)),
                  SizedBox(width: 4),
                  Text('复制', style: TextStyle(color: Color(0xFF5C6370), fontSize: 12)),
                ],
              ),
      ),
    );
  }
}