// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatNode _$ChatNodeFromJson(Map<String, dynamic> json) => ChatNode(
  id: json['id'] as String?,
  parentId: json['parentId'] as String?,
  userInput: json['userInput'] as String,
  llmOutput: json['llmOutput'] as String? ?? '',
  childrenIds:
      (json['childrenIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
  timestamp:
      json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
  isCollapsed: json['isCollapsed'] as bool? ?? false,
  width: (json['width'] as num?)?.toDouble() ?? 300.0,
  height: (json['height'] as num?)?.toDouble() ?? 200.0,
);

Map<String, dynamic> _$ChatNodeToJson(ChatNode instance) => <String, dynamic>{
  'id': instance.id,
  'parentId': instance.parentId,
  'userInput': instance.userInput,
  'llmOutput': instance.llmOutput,
  'childrenIds': instance.childrenIds,
  'timestamp': instance.timestamp.toIso8601String(),
  'isCollapsed': instance.isCollapsed,
  'width': instance.width,
  'height': instance.height,
};
