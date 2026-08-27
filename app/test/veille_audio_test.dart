import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/services/indicateur_sonore.dart';
import 'package:numero_inconnu/services/musique_narrative.dart';
import 'package:numero_inconnu/services/veille_audio.dart';

/// Envoie un vrai message de cycle de vie, par le canal que la plateforme
/// utilise. Pas d'appel direct à `didChangeAppLifecycleState` : c'est Flutter
/// qui décide des états intermédiaires (`resumed` → `inactive` → `hidden` →
/// `paused`), et ce sont eux qui font tout l'intérêt du test — un observateur
/// qui ne regarderait que `paused` couperait trop tard, un qui couperait sur
/// `inactive` couperait à chaque bannière de notification.
Future<void> cycleDeVie(AppLifecycleState etat) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage(etat.toString()),
          (_) {},
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Deux instances globales : on repart d'une app au premier plan, sans
    // source enregistrée, quoi qu'ait laissé le test précédent.
    VeilleAudio.instance.desinstaller();
    VeilleAudio.instance.installer();
    await cycleDeVie(AppLifecycleState.resumed);
    IndicateurSonore.instance.couperTout();
  });

  tearDown(() {
    VeilleAudio.instance.desinstaller();
    IndicateurSonore.instance.couperTout();
  });

  test('l\'app passe en arrière-plan : tout son narratif se tait', () async {
    // Le bug d'origine : la musique de l'écran de fin continuait de jouer,
    // téléphone rangé, jusqu'à ce que le processus soit tué. Le `dispose()` de
    // l'écran ne s'était jamais déclenché — l'écran était toujours monté.
    var musiqueCoupee = false;
    var vocalMisEnPause = false;
    IndicateurSonore.instance.signaler(() => musiqueCoupee = true);
    IndicateurSonore.instance.signaler(() => vocalMisEnPause = true);

    await cycleDeVie(AppLifecycleState.paused);

    // Chaque source reçoit l'arrêt qu'elle a elle-même enregistré : coupure
    // nette pour une musique, pause pour un vocal. La veille ne connaît aucun
    // des deux — elle passe par le registre, et c'est tout l'intérêt.
    expect(musiqueCoupee, isTrue);
    expect(vocalMisEnPause, isTrue);
    expect(IndicateurSonore.instance.enCours.value, isFalse);
  });

  test('une simple interruption (`inactive`) ne coupe rien', () async {
    // `inactive` ne veut pas dire « parti » : bannière de notification, centre
    // de contrôle, appel entrant. Y couper la musique ferait de chaque
    // notification reçue une coupure de mise en scène.
    var coupee = false;
    IndicateurSonore.instance.signaler(() => coupee = true);

    await cycleDeVie(AppLifecycleState.inactive);

    expect(coupee, isFalse);
    expect(IndicateurSonore.instance.enCours.value, isTrue);
    expect(VeilleAudio.instance.avantPlan, isTrue);
  });

  test('la coupure n\'a lieu qu\'une fois par départ', () async {
    // Flutter émet `inactive`, `hidden` PUIS `paused` pour un seul et même
    // départ. Couper à chacun rappellerait l'arrêt de sources déjà arrêtées.
    var coupures = 0;
    IndicateurSonore.instance.signaler(() => coupures++);

    await cycleDeVie(AppLifecycleState.paused);

    expect(coupures, 1);
  });

  test('le retour au premier plan ne relance rien', () async {
    // La décision : rien ne repart tout seul. Le joueur qui revient sur
    // l'écran de fin a déjà lu le cliffhanger — la musique par-dessus ne
    // serait plus une mise en scène, juste une surprise.
    var relances = 0;
    IndicateurSonore.instance.signaler(() => relances++);
    await cycleDeVie(AppLifecycleState.paused);

    await cycleDeVie(AppLifecycleState.resumed);

    expect(IndicateurSonore.instance.enCours.value, isFalse,
        reason: 'aucune source ne s\'est réinscrite d\'elle-même');
    expect(relances, 1, reason: 'le retour n\'a rien rappelé du tout');
    expect(VeilleAudio.instance.avantPlan, isTrue);
  });

  test('l\'app fermée pour de bon coupe aussi', () async {
    var coupee = false;
    IndicateurSonore.instance.signaler(() => coupee = true);

    await cycleDeVie(AppLifecycleState.detached);

    expect(coupee, isTrue);
  });

  test('aucune musique ne démarre pendant que l\'app est en arrière-plan',
      () async {
    // La fenêtre que le seul observateur ne peut pas fermer : `demarrer()` est
    // asynchrone, et une musique lancée juste avant le départ commencerait à
    // jouer APRÈS le passage de `couperTout()`, sans s'être enregistrée nulle
    // part. D'où le garde dans `demarrer()`, vérifié ici — la seule partie
    // testable sans plateforme, puisqu'elle rend la main avant même de créer
    // un lecteur.
    await cycleDeVie(AppLifecycleState.paused);

    await MusiqueNarrative.instance.demarrer('https://exemple.test/fin.mp3');

    expect(MusiqueNarrative.instance.joue, isFalse);
    expect(IndicateurSonore.instance.enCours.value, isFalse,
        reason: 'un lecteur enregistré ici jouerait dans la poche du joueur');
  });

  test('avantPlan suit l\'état de l\'app', () async {
    expect(VeilleAudio.instance.avantPlan, isTrue);
    await cycleDeVie(AppLifecycleState.paused);
    expect(VeilleAudio.instance.avantPlan, isFalse);
    await cycleDeVie(AppLifecycleState.resumed);
    expect(VeilleAudio.instance.avantPlan, isTrue);
  });
}
