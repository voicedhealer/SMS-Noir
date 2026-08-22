import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notification locale de déblocage de chapitre.
///
/// Service à instance unique. **Un seul identifiant, jamais un par
/// chapitre** : l'histoire est linéaire — un seul « prochain chapitre »
/// peut être en attente de déblocage pour un joueur donné à un instant
/// donné. Reprogrammer écrase toujours l'ancienne notification (même id),
/// jamais n'en ajoute une seconde. Voir docs/LOGIQUE.md
/// § Notification locale de déblocage de chapitre.
///
/// La permission n'est **jamais** demandée à l'initialisation — seulement au
/// moment où l'appelant tape sur « Me prévenir » (voir [programmer]). Si
/// l'utilisateur a déjà refusé, l'OS ne réaffiche pas l'invite : on ne le
/// redemande donc jamais nous-mêmes, on relit juste le résultat.
///
/// **Aucune méthode ne lève jamais** — une plateforme sans implémentation
/// enregistrée (tests, desktop non supporté) ou une init qui échoue ne
/// doivent jamais faire planter l'écran de fin de chapitre, même principe
/// que `MusiqueNarrative` pour une musique absente ou illisible — **mais
/// jamais silencieux pour autant** : chaque échec est loggué (`debugPrint`)
/// avant d'être absorbé, pour qu'une vraie erreur de permission ou de
/// configuration sur un appareil réel ne se lise pas comme un simple refus.
class NotificationsLocales {
  NotificationsLocales._();
  static final NotificationsLocales instance = NotificationsLocales._();

  /// Identifiant unique et fixe — voir la doc de classe.
  static const _id = 7841;

  final _plugin = FlutterLocalNotificationsPlugin();
  var _pret = false;

  /// `false` dès qu'une opération échoue une fois (plateforme non supportée,
  /// plugin non enregistré) — inutile de retenter, le service se comporte
  /// alors comme s'il n'y avait jamais de notification possible.
  var _disponible = true;

  Future<bool> _assurerInitialisation() async {
    if (!_disponible) return false;
    if (_pret) return true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permissions désactivées ici volontairement : les demander à
          // l'initialisation les redemanderait au lancement de l'app, avant
          // même que le joueur ait vu le bouton. `requestPermissions`
          // ci-dessous s'en charge, seulement au tap.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _pret = true;
      return true;
    } catch (e) {
      // Jamais silencieux : sur un appareil réel, ceci serait une vraie
      // erreur de configuration (icône manquante, plugin non enregistré),
      // pas juste l'absence de plateforme de test — sans ce log, elle se
      // lirait plus tard comme un refus de permission normal, indiscernable.
      debugPrint('[NotificationsLocales] initialisation impossible : $e');
      _disponible = false;
      return false;
    }
  }

  /// Demande la permission — via l'OS, jamais redemandée s'il a déjà refusé.
  Future<bool> _permissionAccordee() async {
    try {
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              sound: true,
              badge: true,
            ) ??
            false;
      }
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationsLocales] demande de permission en échec : $e');
    }
    // Plateforme sans notifications locales connue (tests, desktop) : pas de
    // permission possible, donc pas de notification.
    return false;
  }

  /// Programme (ou reprogramme) le rappel. `titre`/`corps` viennent du
  /// contenu serveur (`chapters.notification_text`), jamais codés en dur ici.
  ///
  /// Renvoie `true` si la permission est accordée et la notification bien
  /// programmée — `false` sinon (refus, ou plateforme sans notifications),
  /// l'appelant décide seul de l'état informatif à afficher (jamais un
  /// blocage, jamais une culpabilisation).
  Future<bool> programmer({
    required DateTime quand,
    required String titre,
    required String corps,
  }) async {
    if (!await _assurerInitialisation()) return false;
    if (!await _permissionAccordee()) return false;

    try {
      // `tz.UTC` comme repère, jamais le fuseau réel de l'appareil : inutile
      // de le détecter, `TZDateTime.from` convertit `quand` en UTC en
      // interne avant de le réétiqueter — l'instant réel programmé ne
      // dépend donc pas du repère choisi, seul l'affichage en dépendrait,
      // jamais montré ici.
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: tz.TZDateTime.from(quand, tz.UTC),
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            'deblocage_chapitre',
            'Déblocage de chapitre',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        title: titre,
        body: corps,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationsLocales] programmation impossible : $e');
      return false;
    }
  }

  /// Annule le rappel programmé — appelée par `reinitialiser()` (« Effacer ma
  /// progression », Réglages) : un rappel resté programmé pour une partie
  /// effacée sonnerait plus tard pour rien. Prête aussi pour un futur
  /// déblocage anticipé par achat, qui n'existe pas encore — voir
  /// docs/LOGIQUE.md § Notification locale de déblocage de chapitre.
  Future<void> annuler() async {
    if (!await _assurerInitialisation()) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('[NotificationsLocales] annulation impossible : $e');
    }
  }

  /// `true` si un rappel est actuellement programmé — pilote l'état du
  /// bouton « Me prévenir » (déjà programmé vs pas encore).
  Future<bool> get programmee async {
    if (!await _assurerInitialisation()) return false;
    try {
      final enAttente = await _plugin.pendingNotificationRequests();
      return enAttente.any((n) => n.id == _id);
    } catch (e) {
      debugPrint(
        '[NotificationsLocales] lecture des rappels en attente impossible : $e',
      );
      return false;
    }
  }
}
