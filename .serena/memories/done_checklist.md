# Before Submitting Changes
- Ensure `flutter analyze` reports no issues.
- Run `dart format lib test` (or `flutter format`) so the diff stays formatted.
- Regenerate json_serializable outputs with build_runner if model/service annotations changed and commit updated *.g.dart files.
- Execute `flutter test` and confirm passing.
- Launch the app on at least one target (`flutter run -d chrome` or similar) when UI changes might break runtime behavior.
- Update docs or README when changing setup steps, commands, or UX flows.