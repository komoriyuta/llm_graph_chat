import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'graph_session.dart';

part 'session_list.g.dart';

@JsonSerializable()
class SessionList {
  final String id;
  final List<GraphSession> sessions;
  
  SessionList({
    String? id,
    List<GraphSession>? sessions,
  }) : id = id ?? const Uuid().v4(),
       sessions = sessions ?? [];

  factory SessionList.fromJson(Map<String, dynamic> json) => _$SessionListFromJson(json);
  Map<String, dynamic> toJson() => _$SessionListToJson(this);
}