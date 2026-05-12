// 文件路径: lib/widgets/draggable_ai_button.dart
import 'package:flutter/material.dart';
import 'ai_chat_bottom_sheet.dart'; // 我们马上要创建的半屏弹窗

class DraggableAiButton extends StatefulWidget {
  final int currentTabIndex; // 接收当前的 Tab 索引，用于告诉 AI 当前的上下文

  const DraggableAiButton({super.key, required this.currentTabIndex});

  @override
  State<DraggableAiButton> createState() => _DraggableAiButtonState();
}

class _DraggableAiButtonState extends State<DraggableAiButton> {
  // 悬浮球的初始位置 (右下角)
  double _left = 300;
  double _top = 500;
  final double _buttonSize = 56.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始化时自动定位到右下角
    final size = MediaQuery.of(context).size;
    _left = size.width - _buttonSize - 16;
    _top = size.height - _buttonSize - 150;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _left,
      top: _top,
      child: GestureDetector(
        // 拖拽更新位置
        onPanUpdate: (details) {
          setState(() {
            _left += details.delta.dx;
            _top += details.delta.dy;
          });
        },
        // 松手时触发边缘吸附逻辑
        onPanEnd: (details) {
          setState(() {
            // 限制上下边界
            if (_top < kToolbarHeight) _top = kToolbarHeight;
            if (_top > screenSize.height - 150) _top = screenSize.height - 150;
            // 左右吸附
            if (_left > screenSize.width / 2) {
              _left = screenSize.width - _buttonSize - 16; // 吸附到右边
            } else {
              _left = 16; // 吸附到左边
            }
          });
        },
        // 点击唤起半屏 AI 聊天
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // 允许弹窗高度超过一半
            backgroundColor: Colors.transparent,
            builder: (context) => AiChatBottomSheet(currentContextIndex: widget.currentTabIndex),
          );
        },
        // 圆形图标设计
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle, // 变成完美的圆形
            boxShadow: [
              BoxShadow(
                // 替换为最新的 .withValues(alpha: 透明度)
                color: Colors.black.withValues(alpha: 0.2), 
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}