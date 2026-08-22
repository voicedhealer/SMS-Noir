import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'services/audio_session_config.dart';
import 'screens/root_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/sound_indicator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(AppTheme.orientations);

  // Ambiance par défaut : sons de message et musique d'intro respectent le
  // mode silencieux. Seule la note vocale, tapée explicitement, bascule en
  // `playback` — voir AudioSessionConfig.
  await AudioSessionConfig.ambiance();

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
      home: const RootScreen(),
      // Un seul indicateur sonore, monté au-dessus de tout : l'écran change
      // (carte d'entrée, intro, conversation, écran noir), la source du son
      // aussi, mais l'endroit où le signaler ne doit pas être réécrit à
      // chaque fois. Voir docs/DESIGN.md § Le système sonore.
      builder: (context, child) => Stack(
        children: [
          ?child,
          const SoundIndicatorOverlay(),
        ],
      ),
    );
  }
}
