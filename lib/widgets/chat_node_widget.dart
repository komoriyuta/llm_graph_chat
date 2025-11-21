import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/chat_node.dart';
import '../providers/theme_notifier.dart';

class ChatNodeWidget extends ConsumerStatefulWidget {
  final ChatNode node;
  final bool isSelected;
  final bool canCollapse;
  final Function(ChatNode) onNodeSelected;
  final Function(ChatNode) onToggleCollapse;
  final Function(ChatNode) onRegenerate;
  final Function(ChatNode, String) onGenerateChild;

  const ChatNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.canCollapse,
    required this.onNodeSelected,
    required this.onToggleCollapse,
    required this.onRegenerate,
    required this.onGenerateChild,
  });

  @override
  ConsumerState<ChatNodeWidget> createState() => _ChatNodeWidgetState();
}

class _ChatNodeWidgetState extends ConsumerState<ChatNodeWidget> {
  final TextEditingController _nodeInputController = TextEditingController();
  final FocusNode _nodeInputFocusNode = FocusNode();
  final ScrollController _llmOutputScrollController = ScrollController();
  bool _isHovered = false;
  bool _isOutputExpanded = false;

  @override
  void dispose() {
    _nodeInputController.dispose();
    _nodeInputFocusNode.dispose();
    _llmOutputScrollController.dispose();
    super.dispose();
  }

  void _generateChild(String userInput) {
    if (userInput.isNotEmpty) {
      widget.onGenerateChild(widget.node, userInput);
      _nodeInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isDarkMode = theme.brightness == Brightness.dark;
    final nodeSettings = ref.watch(nodeSettingsProvider);

    final backgroundColor = isDarkMode
        ? (widget.isSelected ? Colors.purple.shade900 : Colors.grey.shade900)
        : (widget.isSelected ? Colors.lightBlue[50] : Colors.grey[100]);
    final borderColor = isDarkMode
        ? (widget.isSelected ? Colors.purple : Colors.grey.shade700)
        : (widget.isSelected ? Colors.blue : Colors.grey.shade400);
    final textColor = isDarkMode ? Colors.grey[200] : Colors.grey[800];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onNodeSelected(widget.node),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 1.5 : 1,
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
                    if (widget.canCollapse)
                      InkWell(
                        onTap: () => widget.onToggleCollapse(widget.node),
                        child: Icon(
                          widget.node.isCollapsed
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
                          maxWidth: nodeSettings.width - 60,
                        ),
                        child: Text(
                          "You: ${widget.node.userInput}",
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
                        onPressed: () => widget.onRegenerate(widget.node),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.node.isCollapsed && widget.node.llmOutput.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(left: 24),
                  width: nodeSettings.width - 16,
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
                          maxHeight: nodeSettings.height - 100,
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            scrollbars: true,
                            overscroll: false,
                            physics: const ClampingScrollPhysics(),
                          ),
                          child: RawScrollbar(
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
                            controller: _llmOutputScrollController,
                            child: SingleChildScrollView(
                              controller: _llmOutputScrollController,
                              child: MarkdownBody(
                                data: widget.node.llmOutput.length > 500 && !_isOutputExpanded
                                    ? '${widget.node.llmOutput.substring(0, 500)}...'
                                    : widget.node.llmOutput,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    height: 1.5,
                                  ),
                                  code: TextStyle(
                                    fontFamily: 'monospace',
                                    backgroundColor: isDarkMode
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade100,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.node.llmOutput.length > 500)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isOutputExpanded = !_isOutputExpanded;
                            });
                          },
                          child: Text(
                            _isOutputExpanded ? 'Show less' : 'Show more',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (widget.isSelected && !widget.node.isCollapsed) ...[
                const SizedBox(height: 8),
                const Divider(height: 8, thickness: 0.5),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: nodeSettings.width - 16,
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
                            onSubmitted: _generateChild,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () =>
                              _generateChild(_nodeInputController.text),
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
}
