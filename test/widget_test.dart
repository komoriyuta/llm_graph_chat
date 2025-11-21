import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_graph_chat/main.dart';
import 'package:llm_graph_chat/providers/session_notifier.dart';
import 'package:llm_graph_chat/providers/session_state.dart';
import 'package:llm_graph_chat/models/graph_session.dart';

class MockSessionNotifier extends SessionNotifier {
  @override
  SessionState build() {
    final session = GraphSession(title: 'Test Chat');
    return SessionState(
      sessions: [session],
      currentSession: session,
      isLoading: false,
    );
  }
}

void main() {
  testWidgets('App launches and shows ChatScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => MockSessionNotifier()),
        ],
        child: const MyApp(),
      ),
    );

    // await tester.pumpAndSettle();
    await tester.pump(); 
    await tester.pump(const Duration(seconds: 1)); 
    
    // Verify that ChatScreen is shown with the session title
    expect(find.text('Test Chat'), findsOneWidget);
    
    // Check for settings icon
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
