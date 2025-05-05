import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'chat_node.dart';

part 'graph_session.g.dart';

@JsonSerializable()
class GraphSession {
  final String id;
  final String title;
  final List<ChatNode> nodes;
  final String rootNodeId;
  final DateTime createdAt;
  DateTime updatedAt;

  GraphSession({
    String? id,
    required this.title,
    List<ChatNode>? nodes,
    String? rootNodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       nodes = nodes ?? [],
       rootNodeId = rootNodeId ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory GraphSession.fromJson(Map<String, dynamic> json) => _$GraphSessionFromJson(json);
  Map<String, dynamic> toJson() => _$GraphSessionToJson(this);

  void addNode(ChatNode node) {
    nodes.add(node);
    updatedAt = DateTime.now();
  }
}