# Style and Conventions
- Follow default `flutter_lints` rules; keep analyzer clean via `flutter analyze`.
- Null-safety enabled; prefer immutable models with `json_serializable`; regenerate *.g.dart via build_runner after model changes.
- Organize UI into screens/widgets; use Provider for shared state (e.g., `SessionProvider`, `ThemeProvider`).
- Store secrets via `SecureStorageService`; persist sessions via repository classes per platform.
- Keep platform-specific helpers split across `platform_io.dart`, `platform_web.dart`, and `platform_util.dart`; update all variants together.