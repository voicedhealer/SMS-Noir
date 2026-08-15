import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Thème unique, sombre. Aucun thème clair : l'histoire se passe la nuit, et
/// une bascule de thème est un élément d'application, pas de messagerie.
class AppTheme {
  const AppTheme._();

  static ThemeData get sombre {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fond,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.fond,
        primary: AppColors.bulleJoueur,
        onPrimary: AppColors.texteJoueur,
        secondary: AppColors.pastille,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.titreEnTete,
        foregroundColor: AppColors.textePrincipal,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      // fontFamily laissé nul : SF Pro sur iOS, Roboto sur Android. Voir tokens.
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textePrincipal,
        displayColor: AppColors.textePrincipal,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.separateurLigne,
        thickness: 0.5,
        space: 0.5,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  /// Portrait uniquement : une messagerie tenue à deux mains en paysage ne
  /// ressemble plus à une messagerie.
  static const orientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];
}
