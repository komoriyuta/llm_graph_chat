import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llm_graph_chat/providers/session_provider.dart';
import 'package:llm_graph_chat/providers/theme_provider.dart';
import 'package:llm_graph_chat/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        final key = methodCall.arguments['key'];
        if (key == 'llm_api_key') {
          return 'test-api-key';
        }
        if (key == 'selected_llm_model') {
          return null;
        }
        return null;
      }
      if (methodCall.method == 'write') {
        return null;
      }
      if (methodCall.method == 'readAll') {
        return {'llm_api_key': 'test-api-key'};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('ChatScreen shows loading and then initial input view',
      (WidgetTester tester) async {
    final sessionProvider = SessionProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
          ChangeNotifierProvider.value(value: sessionProvider),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );

    // After pumpWidget, the first frame is rendered, which should be the loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for all async initialization to complete.
    await tester.pumpAndSettle();

    // Now, the main view should be rendered.
    expect(find.text('Start a new chat'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}