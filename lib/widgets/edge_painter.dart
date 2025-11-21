import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_node.dart';

/// CustomPainter for drawing edges (lines) between nodes
class EdgePainter extends CustomPainter {
  final List<ChatNode> nodes;
  final Map<String, ChatNode> chatNodeMap;
  final ChatNode? selectedNode;
  final bool isDarkMode;
  final int graphVersion;
  final Set<String> visibleNodeIds;

  EdgePainter({
    required this.nodes,
    required this.chatNodeMap,
    required this.selectedNode,
    required this.isDarkMode,
    required this.graphVersion,
    required this.visibleNodeIds,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      if (!visibleNodeIds.contains(node.id)) continue;
      if (node.parentId != null && chatNodeMap.containsKey(node.parentId)) {
        final parentNode = chatNodeMap[node.parentId]!;
        if (!visibleNodeIds.contains(parentNode.id)) continue;
        final isSelected =
            selectedNode?.id == node.id || selectedNode?.id == parentNode.id;

        final paint = Paint()
          ..color = isSelected
              ? (isDarkMode ? Colors.purple : Colors.blue)
              : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400)
          ..strokeWidth = isSelected ? 2.5 : 1.0
          ..style = PaintingStyle.stroke;

        // Access position property directly
        final start = parentNode.position;
        final end = node.position;

        final startPoint = Offset(start.dx + 100, start.dy + 100);
        final endPoint = Offset(end.dx + 100, end.dy);

        final dx = (endPoint.dx - startPoint.dx).abs();
        final dy = endPoint.dy - startPoint.dy;

        final controlPoint1 = Offset(
          startPoint.dx + dx * 0.1,
          startPoint.dy + dy * 0.2,
        );
        final controlPoint2 = Offset(
          endPoint.dx - dx * 0.1,
          startPoint.dy + dy * 0.8,
        );

        final path = Path()
          ..moveTo(startPoint.dx, startPoint.dy)
          ..cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx,
              controlPoint2.dy, endPoint.dx, endPoint.dy);

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.graphVersion != graphVersion ||
        oldDelegate.selectedNode?.id != selectedNode?.id ||
        oldDelegate.isDarkMode != isDarkMode ||
        !setEquals(oldDelegate.visibleNodeIds, visibleNodeIds);
  }
}
