import 'package:flutter/widgets.dart';

/// Jetons de design. Valeurs de référence : docs/DESIGN.md.
///
/// Règle qui gouverne tout le reste : **ce n'est pas une app de jeu.**
/// Aucun score, aucune progression, aucun badge. On doit pouvoir jeter un œil
/// à l'écran dans le métro et croire à de vrais SMS.
class AppColors {
  const AppColors._();

  /// Fond général — noir légèrement bleuté, jamais un noir pur (qui « creuse »
  /// sur OLED et fait ressortir les bulles comme des vignettes).
  static const fond = Color(0xFF0B0D10);

  /// Barres d'en-tête et de saisie : un cran au-dessus du fond.
  static const surface = Color(0xFF101317);
  static const separateurLigne = Color(0xFF1B1F25);

  /// Bulle reçue.
  static const bulleContact = Color(0xFF1A1D22);
  static const texteContact = Color(0xFFE4E6EA);

  /// **Unique couleur d'accent du produit** : la bulle du joueur.
  /// Un bleu-vert profond, désaturé — assez présent pour distinguer les deux
  /// voix d'un coup d'œil, assez sourd pour ne pas égayer un thriller nocturne.
  static const bulleJoueur = Color(0xFF2B5566);
  static const texteJoueur = Color(0xFFEAF2F5);

  /// Message décoratif non délivré : même bulle, atténuée. Aucun autre signal —
  /// rien ne doit trahir qu'il ne partira jamais.
  static const bulleJoueurNonDelivre = Color(0xFF1F3C48);

  static const textePrincipal = Color(0xFFE4E6EA);
  static const texteSecondaire = Color(0xFF8A9199);
  static const texteTertiaire = Color(0xFF5E666E);

  /// Pastille de séparateur horaire.
  static const separateurFond = Color(0xFF14171B);
  static const separateurTexte = Color(0xFF6E767F);

  /// Pastille de non-lus dans la liste des conversations.
  static const pastille = Color(0xFF3E7A91);

  /// Pastilles de présence. **Seule entorse assumée à la couleur d'accent
  /// unique** : un point vert « en ligne » est une convention que tout le monde
  /// lit sans y penser depuis quinze ans. La réinventer coûterait plus cher que
  /// l'entorse — et elle est désaturée, elle n'égaie rien.
  static const presenceEnLigne = Color(0xFF4E8C6A);
  static const presenceHorsLigne = Color(0xFF4A5058);

  /// Media absent (`placeholder://`). Neutre, jamais alarmant : le joueur ne
  /// doit pas croire à une panne.
  static const mediaAbsentFond = Color(0xFF191D22);
  static const mediaAbsentBord = Color(0xFF262B32);
}

class AppText {
  const AppText._();

  /// ⚠️ Aucune police n'est embarquée, volontairement. `fontFamily: null`
  /// laisse Flutter prendre SF Pro sur iOS et Roboto sur Android : c'est
  /// précisément ce qui vend l'illusion. Une police custom, même belle,
  /// signalerait immédiatement « application ».
  static const corpsMessage = TextStyle(fontSize: 16, height: 1.35, letterSpacing: -0.1);
  static const titreEnTete = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.2);
  static const sousTitrePresence = TextStyle(fontSize: 12, height: 1.2);
  static const separateur =
      TextStyle(fontSize: 12, letterSpacing: 0.4, fontWeight: FontWeight.w500);
  static const libelleChoix = TextStyle(fontSize: 15, height: 1.25);
  static const titreConversation = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const apercuConversation = TextStyle(fontSize: 14, height: 1.25);
  static const horodatage = TextStyle(fontSize: 12);
  static const titreFinChapitre =
      TextStyle(fontSize: 26, fontWeight: FontWeight.w300, height: 1.3, letterSpacing: 0.2);
  static const compteARebours =
      TextStyle(fontSize: 32, fontWeight: FontWeight.w200, letterSpacing: 2);
}

/// Échelle d'espacement, base 4.
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Une bulle ne dépasse jamais cette fraction de la largeur.
  ///
  /// À 72 %, les bulles forment une colonne régulière de chaque côté et
  /// laissent en face un couloir vide qui ne se referme jamais : c'est ce
  /// couloir, plus que l'alignement, qui dit au lecteur que chaque
  /// interlocuteur a son côté de l'écran. Plus large, les deux colonnes se
  /// rejoignent au milieu et le fil cesse de ressembler à une conversation.
  static const double largeurMaxBulle = 0.72;
  static const double rayonBulle = 18;
  static const double interBulles = 3;

  /// Respiration entre deux prises de parole différentes.
  static const double interGroupes = 10;
}

/// Durées d'animation. Rien de gratuit : seuls comptent l'arrivée d'un message,
/// le typing, et la bascule d'identité.
class AppMotion {
  const AppMotion._();
  static const arriveeMessage = Duration(milliseconds: 220);
  static const apparitionTyping = Duration(milliseconds: 160);

  /// La bascule « Numéro inconnu » → « Léna » est un micro-événement narratif :
  /// elle est la seule animation à laquelle on accorde du temps.
  static const basculeIdentite = Duration(milliseconds: 900);
}
