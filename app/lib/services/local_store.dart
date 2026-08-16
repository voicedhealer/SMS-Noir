import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/client_message.dart';

/// Mémoire locale de **présentation**.
///
/// Rien ici n'est de l'état de jeu : la vérité reste `get-state`. On n'y garde
/// que ce que le serveur ne peut pas savoir —
///
///  • **le curseur d'affichage** : jusqu'où le joueur a réellement vu le fil.
///    Le serveur écrit tous les messages d'un nœud dès son entrée, il ne peut
///    donc pas dire lesquels ont été joués.
///  • **la file en attente** : ce qui restait à dérouler quand l'app s'est
///    fermée, avec ses délais. Sans elle, la reprise afficherait tout d'un bloc.
///  • **les messages décoratifs** : ils n'existent que sur l'appareil et ne
///    partent jamais au serveur.
///
/// Perdre ce store ne perd aucun message et n'en duplique aucun : au pire le
/// nœud courant s'affiche d'un coup.
class LocalStore {
  LocalStore(this._prefs, this._joueur);
  final SharedPreferences _prefs;

  /// ⚠️ **Le store est cloisonné par joueur.** Les `seq` sont attribués par une
  /// séquence globale : ceux d'un joueur n'ont aucun sens pour un autre. Un
  /// store partagé ferait remonter les messages décoratifs d'une session
  /// précédente **en haut** du fil d'un nouveau joueur, ancrés à des `seq`
  /// inférieurs à tout son historique. Constaté à l'écran.
  final String _joueur;

  static Future<LocalStore> ouvrir(String joueur) async =>
      LocalStore(await SharedPreferences.getInstance(), joueur);

  String get _cleCurseur => 'curseur_affichage:$_joueur';
  String get _cleEnAttente => 'file_en_attente:$_joueur';
  String get _cleDecoratifs => 'messages_decoratifs:$_joueur';
  String get _cleIntroVue => 'intro_vue:$_joueur';

  // --- Séquence d'intronisation ---------------------------------------------

  /// L'intro n'est pas de l'état de jeu : un indicateur local suffit. Si le
  /// joueur réinstalle et la revoit, ce n'est pas grave.
  bool get introVue => _prefs.getBool(_cleIntroVue) ?? false;
  Future<void> marquerIntroVue() => _prefs.setBool(_cleIntroVue, true);

  // --- Curseur d'affichage --------------------------------------------------

  int get curseur => _prefs.getInt(_cleCurseur) ?? 0;

  Future<void> poserCurseur(int seq) async {
    if (seq <= curseur) return;
    await _prefs.setInt(_cleCurseur, seq);
  }

  // --- File en attente ------------------------------------------------------

  List<ClientMessage> get enAttente {
    final brut = _prefs.getString(_cleEnAttente);
    if (brut == null) return const [];
    try {
      return (jsonDecode(brut) as List<dynamic>)
          .map((j) => ClientMessage.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> poserEnAttente(List<ClientMessage> messages) async {
    if (messages.isEmpty) {
      await _prefs.remove(_cleEnAttente);
      return;
    }
    await _prefs.setString(_cleEnAttente, jsonEncode(messages.map(_serialiser).toList()));
  }

  Map<String, dynamic> _serialiser(ClientMessage m) => {
        'seq': m.seq,
        'contact_id': m.contactId,
        'sender': m.sender == MessageSender.player ? 'player' : 'contact',
        'content_type': m.contentType.name,
        'body': m.body,
        'media_url': m.mediaUrl,
        'delay_seconds': m.delaySeconds,
        'typing_seconds': m.typingSeconds,
        'push_notification': m.pushNotification,
        'push_text': m.pushText,
        'phantom_typing_at': m.phantomTypingAt,
        'haptic_at': m.hapticAt,
      };

  // --- Messages décoratifs --------------------------------------------------

  /// Ancrés au dernier `seq` serveur connu au moment de l'écriture : c'est ce
  /// qui leur rend leur place dans le fil au rechargement.
  List<ClientMessage> get decoratifs {
    final brut = _prefs.getStringList(_cleDecoratifs) ?? const [];
    return brut.map((s) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return ClientMessage.decorative(
        contactId: j['contact_id'] as String,
        texte: j['body'] as String,
        ancreSeq: (j['seq'] as num).toInt(),
      );
    }).toList();
  }

  Future<void> ajouterDecoratif(ClientMessage m) async {
    final liste = _prefs.getStringList(_cleDecoratifs) ?? <String>[];
    liste.add(jsonEncode(m.toLocalJson()));
    await _prefs.setStringList(_cleDecoratifs, liste);
  }

  /// Purge complète — « réinitialiser l'histoire » (RGPD, bible §9).
  Future<void> effacerTout() async {
    await _prefs.remove(_cleCurseur);
    await _prefs.remove(_cleEnAttente);
    await _prefs.remove(_cleDecoratifs);
    await _prefs.remove(_cleIntroVue);
  }
}
