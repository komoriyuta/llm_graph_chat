import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/graph_session.dart';

part 'session_state.freezed.dart';

@freezed
abstract class SessionState with _$SessionState {
  const factory SessionState({
    @Default([]) List<GraphSession> sessions,
    GraphSession? currentSession,
    @Default(0) int graphVersion,
    @Default(false) bool isLoading,
  }) = _SessionState;
}
