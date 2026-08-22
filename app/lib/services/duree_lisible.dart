/// Formate un délai en minutes pour un texte joueur — « Me prévenir dans
/// Xh » ne doit jamais coder `unlock_delay_minutes` en dur : un futur
/// chapitre pourra choisir un délai différent (autre nombre d'heures, des
/// jours) sans qu'on retouche l'écran.
String dureeLisible(int minutes) {
  if (minutes < 60) return '$minutes min';

  final heures = minutes ~/ 60;
  final resteMinutes = minutes % 60;
  if (heures < 24) {
    return resteMinutes == 0 ? '${heures}h' : '${heures}h$resteMinutes';
  }

  final jours = heures ~/ 24;
  final resteHeures = heures % 24;
  final joursTexte = jours == 1 ? '1 jour' : '$jours jours';
  return resteHeures == 0 ? joursTexte : '$joursTexte $resteHeures h';
}
