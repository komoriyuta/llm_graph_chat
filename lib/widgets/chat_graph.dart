import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../providers/theme_provider.dart';

import 'package:markdown/markdown.dart' as md;

/// Markdownのインラインコードブロックのスタイルをカスタマイズするビルダー
class CodeBuilder extends MarkdownElementBuilder {
  final TextStyle? style;
  final bool isDarkMode;

  CodeBuilder(this.style, {this.isDarkMode = false});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: element.tag == 'code' ? BorderRadius.circular(4) : null,
      ),
      padding: element.tag == 'code'
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
          : null,
      child: Text(
        text,
        style: style?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}

/// ノード間のエッジ（線）を描画するCustomPainter
class EdgePainter extends CustomPainter {
  final List<ChatNode> nodes;
  final Map<String, ChatNode> chatNodeMap;
  final ChatNode? selectedNode;
  final bool isDarkMode;

  EdgePainter({
    required this.nodes,
    required this.chatNodeMap,
    required this.selectedNode,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      if (node.parentId != null && chatNodeMap.containsKey(node.parentId)) {
        final parentNode = chatNodeMap[node.parentId]!;
        final isSelected =
            selectedNode?.id == node.id || selectedNode?.id == parentNode.id;

        final paint = Paint()
          ..color = isSelected
              ? (isDarkMode ? Colors.purple : Colors.blue)
              : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400)
          ..strokeWidth = isSelected ? 2.5 : 1.0
          ..style = PaintingStyle.stroke;

        // 各ノードのpositionプロパティを直接参照する
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
    return oldDelegate.nodes != nodes ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

// コールバック関数の型定義
typedef GenerateChildCallback = void Function(
    ChatNode parentNode, String userInput);
typedef NodeSelectedCallback = void Function(ChatNode node);
typedef RegenerateCallback = void Function(ChatNode node);
typedef ToggleCollapseCallback = void Function(ChatNode node);
typedef SessionSaveCallback = void Function(); 

/// チャットグラフ全体を表示するメインウィジェット
class ChatGraphWidget extends StatefulWidget {
  final GraphSession session;
  final GenerateChildCallback onGenerateChild;
  final NodeSelectedCallback onNodeSelected;
  final ToggleCollapseCallback onToggleCollapse;
  final RegenerateCallback onRegenerate;
  final SessionSaveCallback onSessionSave;
  final ChatNode? selectedNode;

  const ChatGraphWidget({
    super.key,
    required this.session,
    required this.onGenerateChild,
    required this.onNodeSelected,
    required this.onToggleCollapse,
    required this.onRegenerate,
    required this.onSessionSave,
    this.selectedNode,
  });

  @override
  State<ChatGraphWidget> createState() => _ChatGraphWidgetState();
}

class _ChatGraphWidgetState extends State<ChatGraphWidget> {
  final TextEditingController _nodeInputController = TextEditingController();
  final FocusNode _nodeInputFocusNode = FocusNode();
  String? _focusedNodeId;
  late Map<String, ChatNode> _chatNodeMap;
  bool _isNodeHovered = false;
  final TransformationController _transformationController =
      TransformationController();

  bool _isDragMode = false;
  String? _dragTargetNodeId;
  final Map<String, ScrollController> _llmOutputScrollControllers = {};
  bool _enableGridSnap = false;

  @override
  void initState() {
    super.initState();
    _buildChatNodeMap();
    // レイアウト計算は最初のビルド後に行う
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateLayout());
  }

  @override
  void didUpdateWidget(covariant ChatGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.nodes.length != oldWidget.session.nodes.length) {
      _buildChatNodeMap();
      _calculateLayout();
    }

    if (widget.selectedNode != null &&
        widget.selectedNode!.id != _focusedNodeId) {
      _focusedNodeId = widget.selectedNode!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(_nodeInputFocusNode);
        }
      });
      _nodeInputController.clear();
    } else if (widget.selectedNode == null && _focusedNodeId != null) {
      _focusedNodeId = null;
      _nodeInputController.clear();
    }
  }

  @override
  void dispose() {
    _nodeInputController.dispose();
    _nodeInputFocusNode.dispose();
    _transformationController.dispose();
    _llmOutputScrollControllers.values
        .forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _buildChatNodeMap() {
    _chatNodeMap = {for (var node in widget.session.nodes) node.id: node};
  }

  List<ChatNode> _getRootNodes() {
    return widget.session.nodes.where((node) => node.parentId == null).toList();
  }

  void _calculateLayout() {
    if (!mounted) return;
    final rootNodes = _getRootNodes();
    final themeProvider = context.read<ThemeProvider>();
    final nodeWidth = themeProvider.nodeWidth;
    final nodeHeight = themeProvider.nodeHeight;
    final horizontalSpacing = nodeWidth + 100.0;
    final verticalSpacing = nodeHeight + 50.0;

    double startX = 100;
    for (final node in rootNodes) {
      _layoutNode(
        node,
        startX,
        100,
        horizontalSpacing,
        verticalSpacing,
        <String>{},
      );
      final subtreeWidth = _calculateSubtreeWidth(node);
      startX += subtreeWidth * horizontalSpacing;
    }
    // 全てのノードの位置更新が終わったらUIを再描画
    setState(() {});
  }

  int _calculateSubtreeWidth(ChatNode node) {
    if (node.isCollapsed || node.childrenIds.isEmpty) {
      return 1;
    }
    int width = 0;
    for (final childId in node.childrenIds) {
      if (_chatNodeMap.containsKey(childId)) {
        width += _calculateSubtreeWidth(_chatNodeMap[childId]!);
      }
    }
    return math.max(1, width);
  }

  void _layoutNode(
    ChatNode node,
    double x,
    double y,
    double horizontalSpacing,
    double verticalSpacing,
    Set<String> placedNodes,
  ) {
    if (placedNodes.contains(node.id)) {
      return;
    }
    // node.positionプロパティを直接更新する
    node.position = Offset(x, y);
    placedNodes.add(node.id);

    if (!node.isCollapsed) {
      double childX = x;
      double childY = y + verticalSpacing;

      for (final childId in node.childrenIds) {
        if (_chatNodeMap.containsKey(childId)) {
          final child = _chatNodeMap[childId]!;
          _layoutNode(
            child,
            childX,
            childY,
            horizontalSpacing,
            verticalSpacing,
            placedNodes,
          );
          childX += horizontalSpacing;
        }
      }
    }
  }

  void _handleNodeLongPress(ChatNode node) {
    setState(() {
      _isDragMode = true;
      _dragTargetNodeId = node.id;
    });
  }

  void _handleDragEnd() {
    setState(() {
      _isDragMode = false;
      _dragTargetNodeId = null;
    });
  }

  Widget _buildMarkdownContent(
      String content, TextStyle style, bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: style,
            code: style.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
            ),
            codeblockDecoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                  width: 4,
                ),
              ),
            ),
          ),
          builders: {
            'code': CodeBuilder(
              style.copyWith(
                fontSize: style.fontSize,
                height: 1.5,
              ),
              isDarkMode: isDarkMode,
            ),
          },
          extensionSet: md.ExtensionSet.gitHubFlavored,
          selectable: true,
          softLineBreak: true,
        ),
      ],
    );
  }

  Widget _buildNodeContent(ChatNode node, bool isSelected, bool canCollapse) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? (isSelected ? Colors.purple.shade900 : Colors.grey.shade900)
        : (isSelected ? Colors.lightBlue[50] : Colors.grey[100]);
    final borderColor = isDarkMode
        ? (isSelected ? Colors.purple : Colors.grey.shade700)
        : (isSelected ? Colors.blue : Colors.grey.shade400);
    final textColor = isDarkMode ? Colors.grey[200] : Colors.grey[800];

    return MouseRegion(
      onEnter: (_) => setState(() => _isNodeHovered = true),
      onExit: (_) => setState(() => _isNodeHovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onNodeSelected(node);
          setState(() {
            _focusedNodeId = node.id;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canCollapse)
                      InkWell(
                        onTap: () => widget.onToggleCollapse(node),
                        child: Icon(
                          node.isCollapsed
                              ? Icons.arrow_right
                              : Icons.arrow_drop_down,
                          size: 20,
                          color: textColor,
                        ),
                      )
                    else
                      const SizedBox(width: 20),
                    Flexible(
                      fit: FlexFit.loose,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              context.watch<ThemeProvider>().nodeWidth - 60,
                        ),
                        child: Text(
                          "You: ${node.userInput}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: () => widget.onRegenerate(node),
                      ),
                    ),
                  ],
                ),
              ),
              if (!node.isCollapsed && node.llmOutput.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(left: 24),
                  width: context.watch<ThemeProvider>().nodeWidth - 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "LLM:",
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              context.watch<ThemeProvider>().nodeHeight - 100,
                        ),
                        child: ScrollConfiguration(
                          behavior:
                              ScrollConfiguration.of(context).copyWith(
                            scrollbars: true,
                            overscroll: false,
                            physics: const ClampingScrollPhysics(),
                          ),
                          child: Builder(builder: (context) {
                            if (!_llmOutputScrollControllers
                                .containsKey(node.id)) {
                              _llmOutputScrollControllers[node.id] =
                                  ScrollController();
                            }
                            return RawScrollbar(
                              thumbVisibility: true,
                              trackVisibility: true,
                              thumbColor: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                              trackColor: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              thickness: 8,
                              radius: const Radius.circular(4),
                              controller: _llmOutputScrollControllers[node.id],
                              child: SingleChildScrollView(
                                controller: _llmOutputScrollControllers[node.id],
                                child: _buildMarkdownContent(
                                  node.llmOutput,
                                  TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    height: 1.5,
                                  ),
                                  isDarkMode,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isSelected && !node.isCollapsed) ...[
                const SizedBox(height: 8),
                const Divider(height: 8, thickness: 0.5),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: context.watch<ThemeProvider>().nodeWidth - 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _nodeInputController,
                            focusNode: _nodeInputFocusNode,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Generate child...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(4)),
                                borderSide: BorderSide(width: 0.5),
                              ),
                            ),
                            onSubmitted: (value) => _generateChild(node, value),
                          ),
                          ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () =>
                              _generateChild(node, _nodeInputController.text),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                          ),
                          child: const Icon(Icons.send, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.nodes.isEmpty) {
      return const Center(child: Text("Graph is empty."));
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.01,
      maxScale: 2.0,
      transformationController: _transformationController,
      scaleEnabled: !_isNodeHovered,
      panEnabled: !_isNodeHovered,
      child: SizedBox(
        width: 3000,
        height: 3000,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              size: const Size(3000, 3000),
              painter: EdgePainter(
                nodes: widget.session.nodes,
                chatNodeMap: _chatNodeMap,
                selectedNode: widget.selectedNode,
                isDarkMode: context.watch<ThemeProvider>().isDarkMode,
              ),
            ),
            ...widget.session.nodes.map((node) => _buildNodeWidget(node)),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeWidget(ChatNode node) {
    bool isSelected = widget.selectedNode?.id == node.id;
    bool canCollapse = node.childrenIds.isNotEmpty;
    bool isDragging = _isDragMode && _dragTargetNodeId == node.id;

    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: GestureDetector(
        onLongPressStart: (_) => _handleNodeLongPress(node),
        onLongPressEnd: (details) {
          _handleDragEnd();
          widget.onSessionSave(); 
        },
        onPanStart: (details) {
          if (isSelected) {
            _handleNodeLongPress(node);
          }
        },
        onPanEnd: (_) {
          if (isSelected) {
            _handleDragEnd();
            widget.onSessionSave(); 
          }
        },
        onPanUpdate: (isDragging || isSelected)
            ? (details) {
                setState(() {
                  // node.positionを直接更新する
                  final newPosition = node.position + details.delta;
                  if (_enableGridSnap) {
                    final snappedX = (newPosition.dx / 20).round() * 20.0;
                    final snappedY = (newPosition.dy / 20).round() * 20.0;
                    node.position = Offset(snappedX, snappedY);
                  } else {
                    node.position = newPosition;
                  }
                });
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isDragging
              ? (Matrix4.identity()..translate(0.0, -5.0))
              : Matrix4.identity(),
          child: _buildNodeContent(node, isSelected, canCollapse),
        ),
      ),
    );
  }

  void _generateChild(ChatNode parentNode, String userInput) {
    if (userInput.isNotEmpty) {
      widget.onGenerateChild(parentNode, userInput);
      _nodeInputController.clear();
    }
  }
}