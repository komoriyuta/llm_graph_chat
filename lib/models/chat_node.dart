import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_node.g.dart';

@JsonSerializable()
class ChatNode {
  final String id;
  final String? parentId;
  final String userInput;
  String llmOutput;
  final List<String> childrenIds;
  final DateTime timestamp;
  bool isCollapsed;
  double width;
  double height;

  ChatNode({
    String? id,
    this.parentId,
    required this.userInput,
    this.llmOutput = '',
    List<String>? childrenIds,
    DateTime? timestamp,
    this.isCollapsed = false,
    this.width = 300.0,
    this.height = 200.0,
  }) : id = id ?? const Uuid().v4(),
       childrenIds = childrenIds ?? [],
       timestamp = timestamp ?? DateTime.now();

  factory ChatNode.fromJson(Map<String, dynamic> json) =>
      _$ChatNodeFromJson(json);
  Map<String, dynamic> toJson() => _$ChatNodeToJson(this);
}
