import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/conversation_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(AppTheme.orientations);

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: NumeroInconnuApp()));
}

class NumeroInconnuApp extends StatelessWidget {
  const NumeroInconnuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Le titre système ne contient aucun contenu narratif.
      title: 'Messages',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.sombre,
      themeMode: ThemeMode.dark,
      home: const ConversationScreen(),
    );
  }
}
