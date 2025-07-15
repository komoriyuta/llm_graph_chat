import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'providers/theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // MaterialAppの引数として、title, theme, homeなどと同じ階層に
        // localizationsDelegatesとsupportedLocalesを配置します。
        return MaterialApp(
          title: 'LLM Graph Chat',
          theme: themeProvider.theme,
          home: const ChatScreen(),
          // localizationsDelegatesとsupportedLocalesをここへ移動
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale("ja", "JP"),
          ],
        );
      },
    );
  }
}
