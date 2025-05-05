// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'graph_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GraphSession _$GraphSessionFromJson(Map<String, dynamic> json) => GraphSession(
  id: json['id'] as String?,
  title: json['title'] as String,
  nodes:
      (json['nodes'] as List<dynamic>?)
          ?.map((e) => ChatNode.fromJson(e as Map<String, dynamic>))
          .toList(),
  rootNodeId: json['rootNodeId'] as String?,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  updatedAt:
      json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$GraphSessionToJson(GraphSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'nodes': instance.nodes,
      'rootNodeId': instance.rootNodeId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
