import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils;
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import '../providers/theme_notifier.dart';
import 'edge_painter.dart';
import 'chat_node_widget.dart';

// Callback function type definitions
typedef GenerateChildCallback = void Function(
    ChatNode parentNode, String userInput);
typedef NodeSelectedCallback = void Function(ChatNode node);
typedef RegenerateCallback = void Function(ChatNode node);
typedef ToggleCollapseCallback = void Function(ChatNode node);
typedef SessionSaveCallback = void Function(); 

/// Main widget for displaying the chat graph
class ChatGraphWidget extends ConsumerStatefulWidget {
  final GraphSession session;
  final int graphVersion;
  final GenerateChildCallback onGenerateChild;
  final NodeSelectedCallback onNodeSelected;
  final ToggleCollapseCallback onToggleCollapse;
  final RegenerateCallback onRegenerate;
  final SessionSaveCallback onSessionSave;
  final ChatNode? selectedNode;

  const ChatGraphWidget({
    super.key,
    required this.session,
    required this.graphVersion,
    required this.onGenerateChild,
    required this.onNodeSelected,
    required this.onToggleCollapse,
    required this.onRegenerate,
    required this.onSessionSave,
    this.selectedNode,
  });

  @override
  ConsumerState<ChatGraphWidget> createState() => _ChatGraphWidgetState();
}

class _ChatGraphWidgetState extends ConsumerState<ChatGraphWidget> {
  String? _focusedNodeId;
  late Map<String, ChatNode> _chatNodeMap;
  bool _isNodeHovered = false;
  final TransformationController _transformationController =
      TransformationController();

  bool _isDragMode = false;
  String? _dragTargetNodeId;
  bool _enableGridSnap = false;
  final ValueNotifier<int> _edgeRepaint = ValueNotifier<int>(0);
  Set<String>? _visibleIds;

  @override
  void initState() {
    super.initState();
    _buildChatNodeMap();
    // Calculate layout after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLayoutNeeded()) {
        _calculateLayout();
      }
    });
  }

  bool _isLayoutNeeded() {
    if (widget.session.nodes.isEmpty) return false;
    final rootNodes = _getRootNodes();
    if (rootNodes.isEmpty) return true;
    return rootNodes.every((node) => node.position == Offset.zero);
  }

  bool _isHiddenByCollapsedAncestor(ChatNode node) {
    var current = node;
    while (current.parentId != null) {
      final parent = _chatNodeMap[current.parentId];
      if (parent == null) return false;
      if (parent.isCollapsed) return true;
      current = parent;
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant ChatGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.nodes.length != oldWidget.session.nodes.length ||
        widget.graphVersion != oldWidget.graphVersion) {
      _buildChatNodeMap();
      if (_isLayoutNeeded()) {
        _calculateLayout();
      }
    }

    if (widget.selectedNode != null &&
        widget.selectedNode!.id != _focusedNodeId) {
      _focusedNodeId = widget.selectedNode!.id;
    } else if (widget.selectedNode == null && _focusedNodeId != null) {
      _focusedNodeId = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _edgeRepaint.dispose();
    super.dispose();
  }

  Set<String> _computeVisibleIds() {
    final nodeSettings = ref.read(nodeSettingsProvider);
    final nodeW = nodeSettings.width;
    final nodeH = nodeSettings.height;
    final screenSize = MediaQuery.of(context).size;
    final inv = Matrix4.inverted(_transformationController.value);
    final topLeft = MatrixUtils.transformPoint(inv, Offset.zero);
    final bottomRight = MatrixUtils.transformPoint(
        inv, Offset(screenSize.width, screenSize.height));
    final viewport = Rect.fromPoints(topLeft, bottomRight).inflate(400);
    bool isVisible(ChatNode n) {
      final r = Rect.fromLTWH(n.position.dx, n.position.dy, nodeW, nodeH);
      return r.overlaps(viewport);
    }
    return {
      for (final n in widget.session.nodes)
        if (!_isHiddenByCollapsedAncestor(n) && isVisible(n)) n.id
    };
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
    final nodeSettings = ref.read(nodeSettingsProvider);
    final nodeWidth = nodeSettings.width;
    final nodeHeight = nodeSettings.height;
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
    setState(() {});
  }

  int _calculateSubtreeWidth(ChatNode node) {
    if (node.isCollapsed || node.childrenIds.isEmpty) {
      return 1;
    }
    int width = 0;
    for (final childId in node.childrenIds) {
      if (_chatNodeMap.containsKey(childId)) {
        final child = _chatNodeMap[childId]!;
        width += child.isCollapsed ? 1 : _calculateSubtreeWidth(child);
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
    node.position = Offset(x, y);
    placedNodes.add(node.id);

    if (!node.isCollapsed) {
      double childX = x;
      double childY = y + verticalSpacing;

      for (final childId in node.childrenIds) {
        if (_chatNodeMap.containsKey(childId)) {
          final child = _chatNodeMap[childId]!;
          if (child.isCollapsed) {
            child.position = Offset(childX, childY);
            childX += horizontalSpacing;
            continue;
          }
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

  @override
  Widget build(BuildContext context) {
    if (widget.session.nodes.isEmpty) {
      return const Center(child: Text("Graph is empty."));
    }

    final theme = ref.watch(themeProvider);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.01,
      maxScale: 2.0,
      transformationController: _transformationController,
      scaleEnabled: !_isNodeHovered,
      panEnabled: !_isNodeHovered,
      onInteractionEnd: (_) {
        setState(() {
          _visibleIds = _computeVisibleIds();
        });
      },
      child: SizedBox(
        width: 6000,
        height: 5000,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              size: const Size(6000, 5000),
              painter: EdgePainter(
                nodes: widget.session.nodes,
                chatNodeMap: _chatNodeMap,
                selectedNode: widget.selectedNode,
                isDarkMode: isDarkMode,
                graphVersion: widget.graphVersion,
                visibleNodeIds: _visibleIds ?? _computeVisibleIds(),
                repaint: _edgeRepaint,
              ),
            ),
            ...widget.session.nodes
                .where((n) => (_visibleIds ?? _computeVisibleIds()).contains(n.id))
                .map((node) => _buildNodeWidget(node)),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeWidget(ChatNode node) {
    bool isSelected = widget.selectedNode?.id == node.id;
    bool canCollapse = node.childrenIds.isNotEmpty;
    bool isDragging = _isDragMode && _dragTargetNodeId == node.id;

    return StatefulBuilder(builder: (context, localSetState) {
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
                  localSetState(() {
                    final newPosition = node.position + details.delta;
                    if (_enableGridSnap) {
                      final snappedX = (newPosition.dx / 20).round() * 20.0;
                      final snappedY = (newPosition.dy / 20).round() * 20.0;
                      node.position = Offset(snappedX, snappedY);
                    } else {
                      node.position = newPosition;
                    }
                  });
                  _edgeRepaint.value++;
                }
              : null,
          child: RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: isDragging
                  ? (Matrix4.identity()..translate(0.0, -5.0))
                  : Matrix4.identity(),
              child: ChatNodeWidget(
                node: node,
                isSelected: isSelected,
                canCollapse: canCollapse,
                onNodeSelected: widget.onNodeSelected,
                onToggleCollapse: widget.onToggleCollapse,
                onRegenerate: widget.onRegenerate,
                onGenerateChild: widget.onGenerateChild,
              ),
            ),
          ),
        ),
      );
    });
  }
}
