# LLM Graph Chat Overview
- Flutter app that connects to an LLM (Gemini by default) and visualizes each conversation as a graph of nodes.
- Built with Flutter 3.7, Provider for state, json_serializable + build_runner, graphview for visualization, secure storage + shared preferences for persistence.
- Key dirs: `lib/screens` (UI), `lib/widgets` (graph UI components), `lib/models` (chat/session data + generated *.g.dart), `lib/services` (LLM + storage), `lib/providers` (theme/session state), `lib/utils` (platform helpers), `test/` (widget smoke test).
- Targets multiple platforms (web, desktop, mobile); assets and platform configs under standard Flutter platform folders.