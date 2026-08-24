/// Un message du fil, tel que le serveur l'envoie.
///
/// Contrat : docs/LOGIQUE.md § Contrat des Edge Functions.
/// Le client ne fabrique jamais de message narratif — il ne fait qu'afficher.
library;

enum MessageSender { contact, player }

enum ContentType {
  text,
  image,
  audio,

  /// Ellipse narrative. `body` est le libellé horaire exact (« 23h31 »),
  /// affiché tel quel : jamais reformaté, jamais recalculé côté client.
  separator,

  /// Carte d'enregistrement de contact, posée dans le fil. Ce n'est ni une
  /// bulle ni une modale : elle reste consultable, et son état suit celui du
  /// contact. Voir DESIGN.md § Carte d'enregistrement.
  contactCard,

  /// Jamais une bulle. Deux usages selon le nœud :
  ///  • présence      -> `body` est le libellé du sous-titre d'en-tête
  ///  • chapter_end   -> texte de l'écran de fin, sorti du fil
  system,

  /// Écran noir narratif. `body` porte les lignes et leurs décalages en JSON.
  ///
  /// Jamais une bulle : le client quitte le fil et bascule en plein écran tant
  /// que le message suivant n'est pas arrivé. La DURÉE n'est pas ici — c'est le
  /// délai du message suivant qui la donne, donc les deux ne peuvent pas se
  /// désynchroniser. Voir docs/LOGIQUE.md § Écran noir narratif.
  narration,

  /// Transition vidéo plein écran (addendum transition N20-N9 §2). Même
  /// mécanisme que `narration` — jamais une bulle, la durée à l'écran vient du
  /// délai du message suivant — mais `media_url` porte le fichier au lieu d'un
  /// `body` : le texte incrusté vit dans la vidéo elle-même, rien à afficher
  /// par-dessus côté client.
  video,
}

class ClientMessage {
  const ClientMessage({
    required this.seq,
    required this.contactId,
    required this.sender,
    required this.contentType,
    required this.body,
    required this.mediaUrl,
    required this.delaySeconds,
    required this.typingSeconds,
    required this.pushNotification,
    required this.pushText,
    this.phantomTypingAt,
    this.hapticAt,
    this.tension = false,
    this.ambienceSoundUrl,
    this.isLocalDecorative = false,
  });

  /// Ordinal serveur croissant. ⚠️ `bigserial` **global**, partagé entre tous
  /// les joueurs : c'est une clé de tri opaque, jamais un index de position.
  final int seq;

  /// Fil de conversation, pas locuteur — voir `sender` pour savoir qui parle.
  final String contactId;
  final MessageSender sender;
  final ContentType contentType;
  final String? body;
  final String? mediaUrl;

  /// Attente avant affichage. Jouée par le client (timers locaux).
  /// Vaut 0 dans l'historique : le déjà-vu se rejoue d'un bloc.
  final int delaySeconds;
  final int typingSeconds;

  final bool pushNotification;
  final String? pushText;

  /// Battements de mise en scène pendant l'attente de CE message : offsets en
  /// secondes **depuis le début de [delaySeconds]**. Un faux « en train
  /// d'écrire » de 2 s qui s'éteint sans message, et une vibration discrète.
  /// Voir docs/LOGIQUE.md § Mise en scène d'une attente.
  final int? phantomTypingAt;
  final int? hapticAt;

  /// Ce message porte le renforcement sensoriel du N19 : bulle bordée de
  /// rouge. **Le client ne sait pas de quel nœud vient la bulle** — il n'a
  /// que ce drapeau, et c'est suffisant. Persiste en relecture, contrairement
  /// aux autres directives de mise en scène.
  final bool tension;

  /// Son d'ambiance à jouer en boucle à partir de ce message. Chemin signé
  /// relatif, comme [mediaUrl]. Renseigné sur le message déclencheur seul, et
  /// jamais en relecture.
  final String? ambienceSoundUrl;

  /// Message décoratif saisi par le joueur : local, jamais envoyé, jamais
  /// délivré. Voir DESIGN.md § Champ de saisie.
  final bool isLocalDecorative;

  /// Le média n'a pas encore été produit (`placeholder://…` en base).
  bool get isPlaceholderMedia => mediaUrl?.startsWith('placeholder://') ?? false;

  /// URL téléchargeable du média.
  ///
  /// Le serveur renvoie un **chemin signé relatif** (`/storage/v1/object/sign/…`)
  /// plutôt qu'une URL absolue : il se signerait lui-même sur son hôte interne,
  /// que l'appareil ne sait pas résoudre. Le client préfixe avec sa propre base,
  /// ce qui règle du même coup le 10.0.2.2 de l'émulateur Android.
  String? urlAbsolue(String base) {
    final u = mediaUrl;
    if (u == null || isPlaceholderMedia) return null;
    if (u.startsWith('http')) return u;
    return '$base$u';
  }

  /// Marque de contenu d'une hésitation visible (N2, N13) : le typing doit
  /// être joué en rafales et non en continu. Convention documentée dans
  /// docs/LOGIQUE.md § Convention de contenu : typing intermittent.
  bool get hasIntermittentTyping => typingSeconds >= intermittentTypingThreshold;
  static const int intermittentTypingThreshold = 15;

  factory ClientMessage.fromJson(Map<String, dynamic> json) => ClientMessage(
        seq: (json['seq'] as num).toInt(),
        contactId: json['contact_id'] as String,
        sender: json['sender'] == 'player' ? MessageSender.player : MessageSender.contact,
        contentType: _contentType(json['content_type'] as String?),
        body: json['body'] as String?,
        mediaUrl: json['media_url'] as String?,
        delaySeconds: (json['delay_seconds'] as num?)?.toInt() ?? 0,
        typingSeconds: (json['typing_seconds'] as num?)?.toInt() ?? 0,
        pushNotification: json['push_notification'] as bool? ?? false,
        pushText: json['push_text'] as String?,
        phantomTypingAt: (json['phantom_typing_at'] as num?)?.toInt(),
        hapticAt: (json['haptic_at'] as num?)?.toInt(),
        tension: json['tension'] as bool? ?? false,
        ambienceSoundUrl: json['ambience_sound_url'] as String?,
      );

  static ContentType _contentType(String? brut) => switch (brut) {
        'image' => ContentType.image,
        'audio' => ContentType.audio,
        'separator' => ContentType.separator,
        'system' => ContentType.system,
        'contact_card' => ContentType.contactCard,
        'narration' => ContentType.narration,
        'video' => ContentType.video,
        // Un type inconnu (chapitre futur) se dégrade en texte plutôt que de
        // faire tomber tout le fil.
        _ => ContentType.text,
      };

  /// Construit un message décoratif local. Il n'a pas de `seq` serveur : on
  /// l'ancre juste après le dernier message serveur connu pour qu'il garde sa
  /// place dans le fil au rechargement.
  factory ClientMessage.decorative({
    required String contactId,
    required String texte,
    required int ancreSeq,
  }) =>
      ClientMessage(
        seq: ancreSeq,
        contactId: contactId,
        sender: MessageSender.player,
        contentType: ContentType.text,
        body: texte,
        mediaUrl: null,
        delaySeconds: 0,
        typingSeconds: 0,
        pushNotification: false,
        pushText: null,
        isLocalDecorative: true,
      );

  Map<String, dynamic> toLocalJson() => {
        'seq': seq,
        'contact_id': contactId,
        'body': body,
      };
}
