import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_node.g.dart';

Map<String, dynamic> _offsetToJson(Offset offset) => {'dx': offset.dx, 'dy': offset.dy};

Offset _offsetFromJson(Map<String, dynamic> json) => Offset(json['dx'] as double, json['dy'] as double);

@JsonSerializable()
class ChatNode {
  final String id;
  final String? parentId;
  final String userInput;

  @JsonKey(fromJson: _offsetFromJson, toJson: _offsetToJson)
  Offset position;

  String llmOutput;
  final List<String> childrenIds;
  final DateTime timestamp;
  bool isCollapsed;

  ChatNode({
    String? id,
    this.parentId,
    required this.userInput,
    Offset? position,
    this.llmOutput = '',
    List<String>? childrenIds,
    DateTime? timestamp,
    this.isCollapsed = false,
  }) : id = id ?? const Uuid().v4(),
       position = position ?? Offset.zero,
       childrenIds = childrenIds ?? [],
       timestamp = timestamp ?? DateTime.now();

  factory ChatNode.fromJson(Map<String, dynamic> json) =>
      _$ChatNodeFromJson(json);
  Map<String, dynamic> toJson() => _$ChatNodeToJson(this);
}