// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionList _$SessionListFromJson(Map<String, dynamic> json) => SessionList(
  id: json['id'] as String?,
  sessions:
      (json['sessions'] as List<dynamic>?)
          ?.map((e) => GraphSession.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$SessionListToJson(SessionList instance) =>
    <String, dynamic>{'id': instance.id, 'sessions': instance.sessions};
