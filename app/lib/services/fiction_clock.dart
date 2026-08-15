import '../models/client_message.dart';

/// Horloge de fiction.
///
/// **Aucun horodatage affiché ne vient de l'horloge système.** Un joueur qui
/// joue à 14 h ne doit jamais voir « vu 14h12 » deux lignes sous un séparateur
/// « 00h29 » : l'illusion tomberait.
///
/// Le temps de fiction se dérive du fil lui-même, sans donnée supplémentaire :
/// chaque `separator` porte une heure dans son `body` et **réancre** l'horloge,
/// puis chaque message suivant l'avance de son propre `delay_seconds`.
///
/// Déterministe par construction : le même fil donne toujours les mêmes heures,
/// au premier affichage comme après un rechargement.
///
/// Seule exception dans toute l'app : le compte à rebours de fin de chapitre,
/// qui est du temps réel. Voir docs/LOGIQUE.md § Le temps de fiction.
class FictionClock {
  const FictionClock._();

  /// « 23h31 », « jeudi — 22h47 », « 00h34 »…
  static final RegExp _heure = RegExp(r'(\d{1,2})\s*h\s*(\d{2})');

  /// Minutes depuis minuit portées par un séparateur, ou null s'il n'en porte pas.
  static int? ancre(String? libelleSeparateur) {
    if (libelleSeparateur == null) return null;
    final m = _heure.firstMatch(libelleSeparateur);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  /// Heure de fiction de chaque message du fil, indexée par `seq`.
  ///
  /// Les messages précédant le premier séparateur n'ont pas d'heure : on
  /// n'invente rien, ils n'apparaissent simplement pas dans la table.
  static Map<int, int> horaires(List<ClientMessage> fil) {
    final out = <int, int>{};
    int? minutes;
    var secondesAccumulees = 0;

    for (final m in fil) {
      if (m.contentType == ContentType.separator) {
        final a = ancre(m.body);
        if (a != null) {
          minutes = a;
          secondesAccumulees = 0;
        }
        if (minutes != null) out[m.seq] = minutes;
        continue;
      }

      if (minutes == null) continue;

      // Un message décoratif est saisi « maintenant » dans la fiction : il
      // n'ajoute pas de temps, il se contente de porter l'heure courante.
      if (!m.isLocalDecorative) {
        secondesAccumulees += m.delaySeconds;
        final minutesEcoulees = secondesAccumulees ~/ 60;
        if (minutesEcoulees > 0) {
          minutes = (minutes + minutesEcoulees) % (24 * 60);
          secondesAccumulees %= 60;
        }
      }
      out[m.seq] = minutes;
    }
    return out;
  }

  /// « 23h31 » — le format des séparateurs du contenu, repris tel quel.
  static String formater(int minutesDepuisMinuit) {
    final h = (minutesDepuisMinuit ~/ 60) % 24;
    final m = minutesDepuisMinuit % 60;
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  /// Heure de fiction courante à la fin d'un fil : ce qu'affiche le « vu ».
  static int? maintenant(List<ClientMessage> fil) {
    final table = horaires(fil);
    if (table.isEmpty) return null;
    return table[fil.lastWhere((m) => table.containsKey(m.seq)).seq];
  }
}
