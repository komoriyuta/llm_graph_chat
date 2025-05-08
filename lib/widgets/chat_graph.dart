import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../providers/theme_provider.dart';

class EdgePainter extends CustomPainter {
  final List<ChatNode> nodes;
  final Map<String, Offset> nodePositions;
  final Map<String, ChatNode> chatNodeMap;
  final ChatNode? selectedNode;
  final bool isDarkMode;

  EdgePainter({
    required this.nodes,
    required this.nodePositions,
    required this.chatNodeMap,
    required this.selectedNode,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      if (node.parentId != null &&
          nodePositions.containsKey(node.id) &&
          nodePositions.containsKey(node.parentId)) {
        final isSelected = selectedNode?.id == node.id || selectedNode?.id == node.parentId;
        
        final paint = Paint()
          ..color = isSelected
              ? (isDarkMode ? Colors.purple : Colors.blue)
              : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400)
          ..strokeWidth = isSelected ? 2.5 : 1.0
          ..style = PaintingStyle.stroke;

        final start = nodePositions[node.parentId]!;
        final end = nodePositions[node.id]!;
        
        final startPoint = Offset(start.dx + 100, start.dy + 100);
        final endPoint = Offset(end.dx + 100, end.dy);
        
        // ベジェ曲線の制御点を最適化
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
          ..cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            endPoint.dx, endPoint.dy
          );
        
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

typedef GenerateChildCallback = void Function(ChatNode parentNode, String userInput);
typedef NodeSelectedCallback = void Function(ChatNode node);
typedef ToggleCollapseCallback = void Function(ChatNode node);

class ChatGraphWidget extends StatefulWidget {
  final GraphSession session;
  final GenerateChildCallback onGenerateChild;
  final NodeSelectedCallback onNodeSelected;
  final ToggleCollapseCallback onToggleCollapse;
  final ChatNode? selectedNode;

  const ChatGraphWidget({
    super.key,
    required this.session,
    required this.onGenerateChild,
    required this.onNodeSelected,
    required this.onToggleCollapse,
    this.selectedNode,
  });

  @override
  State<ChatGraphWidget> createState() => _ChatGraphWidgetState();
}

class _ChatGraphWidgetState extends State<ChatGraphWidget> {
  final TextEditingController _nodeInputController = TextEditingController();
  final FocusNode _nodeInputFocusNode = FocusNode();
  String? _focusedNodeId;
  final Map<String, Offset> _nodePositions = {};
  late Map<String, ChatNode> _chatNodeMap;
  bool _isNodeHovered = false;
  final TransformationController _transformationController = TransformationController();
  
  // 操作モード管理
  bool _isDragMode = false;
  String? _dragTargetNodeId;
  
  // レイアウト管理
  bool _needsLayout = true;

  // スクロールコントローラー
  final Map<String, ScrollController> _userInputScrollControllers = {};
  final Map<String, ScrollController> _llmOutputScrollControllers = {};

  // ドラッグ操作設定
  bool _enableGridSnap = false;  // グリッドスナップを無効化

  @override
  void initState() {
    super.initState();
    _buildChatNodeMap();
    _calculateLayout();
  }

  @override
  void didUpdateWidget(covariant ChatGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.nodes.length != oldWidget.session.nodes.length) {
      _buildChatNodeMap();
      _calculateLayout();  // 新しいノードが追加された時に自動レイアウト
    }

    if (widget.selectedNode != null && widget.selectedNode!.id != _focusedNodeId) {
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
    // スクロールコントローラーの破棄
    _userInputScrollControllers.values.forEach((controller) => controller.dispose());
    _llmOutputScrollControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _buildChatNodeMap() {
    _chatNodeMap = {for (var node in widget.session.nodes) node.id: node};
  }

  List<ChatNode> _getRootNodes() {
    return widget.session.nodes.where((node) => node.parentId == null).toList();
  }

  void _calculateLayout() {
    // ルートノードを水平方向に配置
    final rootNodes = _getRootNodes();
    double x = 100;
    
    for (final node in rootNodes) {
      _layoutNode(node, x, 100);
      x += 250;
    }
    _needsLayout = false;
  }

  void _layoutNode(ChatNode node, double x, double y) {
    setState(() {
      _nodePositions[node.id] = Offset(x, y);
    });
    
    if (!node.isCollapsed) {
      double childY = y + 150;
      for (final childId in node.childrenIds) {
        if (_chatNodeMap.containsKey(childId)) {
          _layoutNode(_chatNodeMap[childId]!, x + 50, childY);
          childY += 150;
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
                nodePositions: _nodePositions,
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
    
    if (!_nodePositions.containsKey(node.id)) {
      _nodePositions[node.id] = const Offset(100, 100);
    }

    return Positioned(
      left: _nodePositions[node.id]!.dx,
      top: _nodePositions[node.id]!.dy,
      child: GestureDetector(
        onLongPressStart: (_) => _handleNodeLongPress(node),
        onLongPressEnd: (_) => _handleDragEnd(),
        onPanStart: (details) {
          if (isSelected) {
            _handleNodeLongPress(node);
          }
        },
        onPanEnd: (_) {
          if (isSelected) {
            _handleDragEnd();
          }
        },
        onPanUpdate: (isDragging || isSelected) ? (details) {
          setState(() {
            final newPosition = _nodePositions[node.id]! + details.delta;
            if (_enableGridSnap) {
              // グリッドスナップが有効な場合のみ適用
              final snappedX = (newPosition.dx / 20).round() * 20.0;
              final snappedY = (newPosition.dy / 20).round() * 20.0;
              _nodePositions[node.id] = Offset(snappedX, snappedY);
            } else {
              // 自由な移動
              _nodePositions[node.id] = newPosition;
            }
          });
        } : null,
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

  Widget _buildNodeContent(ChatNode node, bool isSelected, bool canCollapse) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isNodeHovered = true),
      onExit: (_) => setState(() => _isNodeHovered = false),
      child: GestureDetector(
      onTap: () {
        widget.onNodeSelected(node);
        setState(() { _focusedNodeId = node.id; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.selectedNode?.id == node.id) {
            FocusScope.of(context).requestFocus(_nodeInputFocusNode);
          }
        });
        _nodeInputController.clear();
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDarkMode = themeProvider.isDarkMode;
          final backgroundColor = isDarkMode
              ? (isSelected ? Colors.purple.shade900 : Colors.grey.shade900)
              : (isSelected ? Colors.lightBlue[50] : Colors.grey[100]);
          final borderColor = isDarkMode
              ? (isSelected ? Colors.purple : Colors.grey.shade700)
              : (isSelected ? Colors.blue : Colors.grey.shade400);
          final textColor = isDarkMode ? Colors.grey[200] : Colors.grey[800];
          final shadowColor = isDarkMode
              ? Colors.black.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2);

          return Container(
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
                  color: shadowColor,
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
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4.0,
                  children: [
                    if (canCollapse)
                      InkWell(
                        onTap: () => widget.onToggleCollapse(node),
                        child: Icon(
                          node.isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                          size: 20,
                          color: textColor,
                        ),
                      )
                    else
                      const SizedBox(width: 20),

                    Container(
                      constraints: BoxConstraints(
                        maxWidth: context.watch<ThemeProvider>().nodeWidth,
                        maxHeight: context.watch<ThemeProvider>().nodeHeight,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Builder(
                        builder: (context) {
                          if (!_userInputScrollControllers.containsKey(node.id)) {
                            _userInputScrollControllers[node.id] = ScrollController();
                          }
                          final scrollController = _userInputScrollControllers[node.id]!;
                          return Scrollbar(
                            thumbVisibility: true,
                            controller: scrollController,
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "You: ${node.userInput}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (!node.isCollapsed && node.llmOutput.isNotEmpty)
                Padding(
                   padding: const EdgeInsets.only(left: 24.0),
                   child: Container(
                     constraints: BoxConstraints(
                       maxWidth: context.watch<ThemeProvider>().nodeWidth,
                       maxHeight: context.watch<ThemeProvider>().nodeHeight,
                     ),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.withOpacity(0.2)),
                       borderRadius: BorderRadius.circular(4),
                     ),
                     child: Builder(
                        builder: (context) {
                          if (!_llmOutputScrollControllers.containsKey(node.id)) {
                            _llmOutputScrollControllers[node.id] = ScrollController();
                          }
                          final scrollController = _llmOutputScrollControllers[node.id]!;
                          return Scrollbar(
                            thumbVisibility: true,
                            controller: scrollController,
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    MarkdownBody(
                                      data: node.llmOutput,
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(fontSize: 13, color: textColor),
                                        code: TextStyle(
                                          fontSize: 12,
                                          color: textColor,
                                          backgroundColor: isDarkMode
                                              ? Colors.grey.shade900
                                              : Colors.grey.shade200,
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.grey.shade900
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                if (isSelected && !node.isCollapsed) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 8, thickness: 0.5),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 180,
                          height: 40,
                          child: TextField(
                            controller: _nodeInputController,
                            focusNode: _nodeInputFocusNode,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Generate child...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                                borderSide: BorderSide(width: 0.5),
                              ),
                            ),
                            onSubmitted: (value) => _generateChild(node, value),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed: () => _generateChild(node, _nodeInputController.text),
                          child: const Icon(Icons.send, size: 16),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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