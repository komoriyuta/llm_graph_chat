import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../providers/theme_provider.dart';

class EdgePainter extends CustomPainter {
  final List<ChatNode> nodes;
  final Map<String, Offset> nodePositions;
  final Map<String, ChatNode> chatNodeMap;

  EdgePainter({
    required this.nodes,
    required this.nodePositions,
    required this.chatNodeMap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      if (node.parentId != null && 
          nodePositions.containsKey(node.id) && 
          nodePositions.containsKey(node.parentId)) {
        final start = nodePositions[node.parentId]!;
        final end = nodePositions[node.id]!;
        
        final startPoint = Offset(start.dx + 100, start.dy + 100);
        final endPoint = Offset(end.dx + 100, end.dy);
        
        final controlPoint1 = Offset(startPoint.dx, startPoint.dy + (endPoint.dy - startPoint.dy) / 3);
        final controlPoint2 = Offset(endPoint.dx, startPoint.dy + (endPoint.dy - startPoint.dy) * 2 / 3);
        
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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

  @override
  void initState() {
    super.initState();
    _buildChatNodeMap();
  }

  @override
  void didUpdateWidget(covariant ChatGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.nodes.length != oldWidget.session.nodes.length) {
      _buildChatNodeMap();
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
    super.dispose();
  }

  void _buildChatNodeMap() {
    _chatNodeMap = {for (var node in widget.session.nodes) node.id: node};
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
    
    if (!_nodePositions.containsKey(node.id)) {
      _nodePositions[node.id] = const Offset(1000, 1000);
    }

    return Positioned(
      left: _nodePositions[node.id]!.dx,
      top: _nodePositions[node.id]!.dy,
      child: Draggable(
        feedback: Material(
          child: _buildNodeContent(node, isSelected, canCollapse),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: _buildNodeContent(node, isSelected, canCollapse),
        ),
        onDragEnd: (details) {
          setState(() {
            _nodePositions[node.id] = details.offset;
          });
        },
        child: _buildNodeContent(node, isSelected, canCollapse),
      ),
    );
  }

  Widget _buildNodeContent(ChatNode node, bool isSelected, bool canCollapse) {
    return GestureDetector(
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
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
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
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "LLM: ${node.llmOutput}",
                              style: TextStyle(fontSize: 13, color: textColor),
                              softWrap: true,
                            ),
                          ),
                        ),
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
    );
  }

  void _generateChild(ChatNode parentNode, String userInput) {
    if (userInput.isNotEmpty) {
      widget.onGenerateChild(parentNode, userInput);
      _nodeInputController.clear();
    }
  }
}