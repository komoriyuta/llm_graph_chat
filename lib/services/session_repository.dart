import 'session_repository_base.dart';
import 'session_repository_web.dart'
    if (dart.library.io) 'session_repository_io.dart' as impl;

export 'session_repository_base.dart';

SessionRepository createDefaultSessionRepository() => impl.createRepository();
