import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../config/env.dart';
import '../services/audio_session_config.dart';
import '../models/client_message.dart';
import '../theme/tokens.dart';

/// Bulle de message. Reçue à gauche, envoyée à droite.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.vu = false,
  });

  final ClientMessage message;

  /// Ce message porte le marqueur « Vu. ». Voir ReadReceipts.
  final bool vu;


  bool get _duJoueur => message.sender == MessageSender.player;

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;

    return Align(
      alignment: _duJoueur ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: largeurMax),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.interBulles / 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s + 2),
        decoration: BoxDecoration(
          color: _duJoueur
              // Non délivré : même bulle, atténuée. Rien d'autre ne le signale.
              ? (message.isLocalDecorative
                  ? AppColors.bulleJoueurNonDelivre
                  : AppColors.bulleJoueur)
              : AppColors.bulleContact,
          borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
        ),
        // Plus rien sous le texte : l'heure vivait ici, et forçait la bulle à
        // s'élargir au-delà de ses mots. « Disparu comment ? » occupait deux
        // fois la place nécessaire, avec un vide en dessous. La bulle épouse
        // maintenant son texte, et l'heure est passée dans MessageFooter.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body ?? '',
              style: AppText.corpsMessage.copyWith(
                color: _duJoueur ? AppColors.texteJoueur : AppColors.texteContact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pied d'un GROUPE de messages : heure de fiction, nom, « Vu. ».
///
/// Sous le dernier message du groupe seulement. Trois « 22h47 » identiques
/// empilés ne sont pas trois informations, c'est du bruit — et l'heure répétée
/// sous chaque bulle rendait la colonne illisible.
///
/// Aligné du même côté que ses bulles : c'est ce qui rattache le pied à son
/// groupe sans avoir besoin d'un trait ni d'un cadre.
class MessageFooter extends StatelessWidget {
  const MessageFooter({
    super.key,
    required this.duJoueur,
    this.heure,
    this.nom,
    this.vu = false,
    this.nonDelivre = false,
  });

  final bool duJoueur;

  /// Heure **de fiction** (« 23h31 »). Jamais l'horloge système.
  final String? heure;

  /// Nom de l'émetteur — **conversation de groupe uniquement**.
  ///
  /// Nul en tête-à-tête : l'en-tête dit déjà à qui on parle, et « Léna » répété
  /// sous chaque groupe serait exactement le bruit qu'on vient d'enlever. Le
  /// mécanisme attend le chapitre 3 (Léna, Karim et le joueur).
  final String? nom;

  final bool vu;

  /// Envoyé, jamais délivré. Une seule coche, et rien ne le dit au joueur.
  final bool nonDelivre;

  @override
  Widget build(BuildContext context) {
    final morceaux = <Widget>[
      if (nom != null)
        Text(nom!, style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
      if (heure != null)
        Text(heure!, style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
      if (nonDelivre)
        Icon(Icons.check, size: 12, color: AppColors.texteTertiaire.withValues(alpha: 0.7)),
      if (vu) Text('Vu.', style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
    ];
    if (morceaux.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.l + AppSpacing.s, right: AppSpacing.l + AppSpacing.s, top: 2),
      child: Row(
        mainAxisAlignment: duJoueur ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          for (final m in morceaux) ...[m, const SizedBox(width: AppSpacing.s)],
        ],
      ),
    );
  }
}

/// Marqueur « Vu. », sous la bulle, aligné à droite.
///
/// Volontairement minuscule et sans icône : dans une messagerie il se remarque
/// à peine — sauf quand on l'attend, et c'est exactement ce que le N19 provoque.
class ReadReceiptMarker extends StatelessWidget {
  const ReadReceiptMarker({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            right: AppSpacing.l + AppSpacing.m, top: 1, bottom: AppSpacing.xs),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text('Vu.',
              style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
        ),
      );
}

/// Ligne de contexte avant la saisie libre du moment IA (N9).
///
/// Dans le flux de la conversation, sous la dernière bulle et avant la zone
/// de choix — jamais sous le champ de saisie lui-même, qui ne doit jamais
/// changer d'aspect selon le mode (voir `Composer`). Gris, plus petit que le
/// texte normal, centré : une ligne de narration discrète qui cadre
/// l'attente, pas une consigne ni un indice.
class ContexteSaisieLibre extends StatelessWidget {
  const ContexteSaisieLibre({super.key, this.texte = 'Léna attend une vraie réponse...'});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.m),
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire),
        ),
      );
}

/// Ellipse narrative. Le libellé vient du serveur et s'affiche **tel quel**.
class SeparatorPill extends StatelessWidget {
  const SeparatorPill({super.key, required this.libelle});
  final String libelle;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.separateurFond,
            borderRadius: BorderRadius.circular(AppSpacing.m),
          ),
          child: Text(libelle,
              style: AppText.separateur.copyWith(color: AppColors.separateurTexte)),
        ),
      );
}

/// Média pas encore produit (`placeholder://…`).
///
/// Neutre et jamais alarmant : le joueur ne doit pas croire à une panne réseau.
/// Reste **tapable** — le zoom est une mécanique de jeu, pas un confort.
class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({super.key, required this.type, this.hauteur = 180});
  final ContentType type;
  final double hauteur;

  @override
  Widget build(BuildContext context) => Container(
        height: hauteur,
        decoration: BoxDecoration(
          color: AppColors.mediaAbsentFond,
          border: Border.all(color: AppColors.mediaAbsentBord),
          borderRadius: BorderRadius.circular(AppSpacing.m),
        ),
        child: Center(
          child: Icon(
            switch (type) {
              ContentType.audio => Icons.graphic_eq,
              ContentType.video => Icons.videocam_outlined,
              _ => Icons.photo_outlined,
            },
            color: AppColors.texteTertiaire,
            size: 28,
          ),
        ),
      );
}

/// Photo du fil. Le tap ouvre la visionneuse zoomable.
class PhotoBubble extends StatelessWidget {
  const PhotoBubble({
    super.key,
    required this.message,
    required this.onOuvrir,
  });
  final ClientMessage message;
  final VoidCallback onOuvrir;

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: AppSpacing.interBulles / 2),
        // L'heure vivait ici, en surimpression sur la vignette — la même
        // incohérence que celle déjà corrigée pour les bulles de texte, restée
        // sur les médias parce qu'ils passent par un widget séparé. Elle vit
        // maintenant dans le pied de groupe commun, posé par `_Element` : la
        // photo n'a plus besoin d'un `Stack` pour elle seule.
        child: GestureDetector(
          onTap: onOuvrir,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
            child: ConstrainedBox(
              // Une capture d'écran est en portrait : sans plafond, la vignette
              // ferait deux fois la hauteur de l'écran. Une vraie messagerie
              // recadre l'aperçu — et ici c'est heureux : le détail ne se lit
              // qu'en ouvrant, donc le geste d'ouverture reste la mécanique.
              constraints: BoxConstraints(maxWidth: largeurMax, maxHeight: 300),
              child: SizedBox(
                width: largeurMax,
                child: message.isPlaceholderMedia
                    ? const MediaPlaceholder(type: ContentType.image)
                    : Image.network(
                        message.urlAbsolue(Env.supabaseUrl)!,
                        fit: BoxFit.cover,
                        // Recadrage par le haut : on montre le début du document,
                        // pas son milieu.
                        alignment: Alignment.topCenter,
                        // Un média illisible ne casse pas le fil : on retombe sur
                        // le cartouche, comme pour un placeholder.
                        errorBuilder: (_, _, _) =>
                            const MediaPlaceholder(type: ContentType.image),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visionneuse plein écran. Le zoom lui-même est la mécanique cachée : c'est
/// le geste, pas un bouton, qui déclenche l'interaction.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.message, this.onZoom});
  final ClientMessage message;

  /// Appelé au premier zoom réel (pas au simple affichage).
  final VoidCallback? onZoom;

  @override
  Widget build(BuildContext context) {
    final controleur = TransformationController();
    var signale = false;
    controleur.addListener(() {
      if (signale) return;
      if (controleur.value.getMaxScaleOnAxis() > 1.15) {
        signale = true;
        onZoom?.call();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      // L'image occupe tout l'écran AVANT le zoom, comme une visionneuse
      // standard (iMessage, WhatsApp) : `SizedBox.expand` + `BoxFit.contain`
      // la portent à la plus grande taille possible sans la recadrer, fond
      // noir uniforme autour si l'aspect ne correspond pas à l'écran. Avant ce
      // correctif, l'image se rendait à sa taille intrinsèque — d'où le cadre
      // visible autour d'elle une fois agrandie.
      body: InteractiveViewer(
        transformationController: controleur,
        minScale: 1,
        maxScale: 5,
        child: message.isPlaceholderMedia
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: MediaPlaceholder(type: ContentType.image, hauteur: 320),
                ),
              )
            : SizedBox.expand(
                child: Image.network(
                  message.urlAbsolue(Env.supabaseUrl)!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: MediaPlaceholder(type: ContentType.image, hauteur: 320),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Lecteur de note vocale.
///
/// Un vrai lecteur : le vocal du N17 porte un indice (le fond sonore urbain,
/// bible §7 n° 3), et un lecteur simulé le rendrait inatteignable.
///
/// La **réécoute** — toute lecture à partir de la deuxième — est l'interaction
/// cachée du N17. Ce n'est pas un confort de lecture.
class AudioBubble extends StatefulWidget {
  const AudioBubble({super.key, required this.message, this.onReecoute});
  final ClientMessage message;

  /// Appelé à partir de la DEUXIÈME lecture.
  final VoidCallback? onReecoute;

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  AudioPlayer? _lecteur;
  int _lectures = 0;
  bool _pret = false;
  Duration _duree = Duration.zero;
  Duration _position = Duration.zero;
  bool _enLecture = false;

  @override
  void initState() {
    super.initState();
    unawaited(_preparer());
  }

  @override
  void dispose() {
    _lecteur?.dispose();
    super.dispose();
  }

  Future<void> _preparer() async {
    // `isPlaceholderMedia` d'abord : `Env.supabaseUrl` lève si aucune base
    // n'est configurée, et l'argument d'un appel s'évalue avant d'entrer dans
    // `urlAbsolue` — un média pas encore produit n'a pas besoin d'une base
    // pour être reconnu comme tel.
    if (widget.message.isPlaceholderMedia) return;
    final url = widget.message.urlAbsolue(Env.supabaseUrl);
    if (url == null) return; // média pas encore produit
    try {
      await AudioSessionConfig.notevocale();
      final lecteur = AudioPlayer();
      _lecteur = lecteur;
      final duree = await lecteur.setUrl(url);
      lecteur.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      lecteur.playerStateStream.listen((etat) {
        if (!mounted) return;
        setState(() => _enLecture = etat.playing && etat.processingState != ProcessingState.completed);
        if (etat.processingState == ProcessingState.completed) {
          lecteur.seek(Duration.zero);
          lecteur.pause();
        }
      });
      if (mounted) {
        setState(() {
          _pret = true;
          _duree = duree ?? Duration.zero;
        });
      }
    } catch (_) {
      // Un vocal illisible ne casse pas le fil : la bulle reste, muette.
      _lecteur = null;
    }
  }

  Future<void> _basculer() async {
    final lecteur = _lecteur;
    if (lecteur == null) return;
    if (lecteur.playing) {
      await lecteur.pause();
      return;
    }
    if (lecteur.processingState == ProcessingState.completed) {
      await lecteur.seek(Duration.zero);
    }
    _lectures++;
    // Deuxième écoute : c'est l'interaction cachée. Rien ne le signale.
    if (_lectures >= 2) widget.onReecoute?.call();
    await lecteur.play();
  }

  String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;
    final progression = (_duree.inMilliseconds == 0)
        ? 0.0
        : (_position.inMilliseconds / _duree.inMilliseconds).clamp(0.0, 1.0);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: largeurMax,
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: AppSpacing.interBulles / 2),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.bulleContact,
          borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _pret ? _basculer : null,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                _enLecture ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: _pret ? AppColors.texteContact : AppColors.texteTertiaire,
                size: 30,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: progression,
                  minHeight: 2,
                  backgroundColor: AppColors.texteTertiaire,
                  valueColor: const AlwaysStoppedAnimation(AppColors.texteContact),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            // La durée reste ici, à côté du lecteur : c'est une propriété du
            // vocal, pas du fil. L'heure, elle, vit dans le pied de groupe
            // commun posé par `_Element` — plus à côté de la durée, où elle
            // avait survécu à la refonte qui l'avait sortie des autres bulles.
            Text(
              _mmss(_enLecture || _position > Duration.zero ? _position : _duree),
              style: AppText.horodatage.copyWith(color: AppColors.texteSecondaire),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trois points. Aucune différence visuelle entre un typing réel et un faux :
/// c'est tout l'intérêt du second.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l, vertical: AppSpacing.interBulles),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.bulleContact,
            borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
                final opacite = 0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.texteSecondaire.withValues(alpha: opacite),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}

/// Carte d'enregistrement de contact.
///
/// Posée **dans le fil**, jamais en modale : c'est un objet de messagerie, pas
/// une interruption. Elle reste consultable après coup, et son état suit celui
/// du contact.
///
/// Le motif est générique et resservira tel quel : Karim au chapitre 3, et
/// surtout le suspect au chapitre 4 — où la **même carte anodine** devient
/// inquiétante, parce que personne ne lui a donné ce numéro. C'est sa banalité
/// qui fera l'effet : ne rien lui ajouter de spécial.
class ContactCard extends StatelessWidget {
  const ContactCard({
    super.key,
    required this.nom,
    required this.numero,
    required this.enregistre,
    required this.onEnregistrer,
  });

  /// Nom affiché : `display_name_initial` tant qu'on n'a pas enregistré.
  final String nom;
  final String? numero;
  final bool enregistre;
  final VoidCallback onEnregistrer;

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: largeurMax,
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: AppSpacing.interGroupes / 2),
        decoration: BoxDecoration(
          color: AppColors.bulleContact,
          borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
          border: Border.all(color: AppColors.separateurLigne),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.fond,
                    child: Icon(
                      enregistre ? Icons.person : Icons.help_outline,
                      size: 20,
                      color: AppColors.texteTertiaire,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nom,
                            style: AppText.titreConversation
                                .copyWith(color: AppColors.textePrincipal)),
                        if (numero != null) ...[
                          const SizedBox(height: 2),
                          Text(numero!,
                              style: AppText.apercuConversation
                                  .copyWith(color: AppColors.texteSecondaire)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _filet(),
            if (enregistre)
              // Une fois enregistrée, la carte reste — mais elle ne propose
              // plus rien. Elle devient une trace, comme dans une messagerie.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Center(
                  child: Text('Contact enregistré',
                      style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
                ),
              )
            else ...[
              // Actions empilées, pleine largeur : « Enregistrer le contact »
              // passe sur deux lignes dès qu'on le met sur une demi-largeur, et
              // une carte de messagerie n'a pas de libellés qui débordent.
              _action('Enregistrer le contact', AppColors.textePrincipal, onEnregistrer),
              _filet(),
              // « Plus tard » n'a aucun effet : la carte reste, l'histoire
              // continue. C'est un geste, pas un choix — rien à envoyer.
              _action('Plus tard', AppColors.texteSecondaire, () {}),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filet() => Container(height: 0.5, color: AppColors.separateurLigne);

  Widget _action(String libelle, Color couleur, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m + 2),
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size.fromHeight(0),
        ),
        child: Text(libelle, style: AppText.libelleChoix.copyWith(color: couleur)),
      );
}
