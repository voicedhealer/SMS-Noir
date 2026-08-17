import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de l'application.
///
/// **Pas cloisonnés par joueur, volontairement** — contrairement au LocalStore.
/// Couper le son ou ralentir le rythme est une préférence de la personne qui
/// tient le téléphone, pas de la partie en cours : la perdre en réinitialisant
/// sa progression serait absurde, et pour quelqu'un qui a besoin du réglage
/// d'accessibilité, franchement pénible.
class Reglages {
  const Reglages({this.sons = true, this.vibrations = true, this.rythmeLent = false});

  /// Sons de messagerie et musique. Coupés, la vibration prend le relais à la
  /// réception — c'est le même chemin que le mode silencieux du téléphone.
  final bool sons;

  final bool vibrations;

  /// Ralentir le rythme : le texte des écrans narratifs s'affiche d'un coup au
  /// lieu de s'écrire. Double le réglage système, pour qui ne l'a pas activé
  /// partout mais en a besoin ici.
  final bool rythmeLent;

  Reglages copyWith({bool? sons, bool? vibrations, bool? rythmeLent}) => Reglages(
        sons: sons ?? this.sons,
        vibrations: vibrations ?? this.vibrations,
        rythmeLent: rythmeLent ?? this.rythmeLent,
      );
}

class ReglagesNotifier extends Notifier<Reglages> {
  static const _cleSons = 'reglage_sons';
  static const _cleVibrations = 'reglage_vibrations';
  static const _cleRythme = 'reglage_rythme_lent';

  SharedPreferences? _prefs;

  @override
  Reglages build() {
    _charger();
    return const Reglages();
  }

  Future<void> _charger() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    state = Reglages(
      sons: p.getBool(_cleSons) ?? true,
      vibrations: p.getBool(_cleVibrations) ?? true,
      rythmeLent: p.getBool(_cleRythme) ?? false,
    );
  }

  Future<void> poserSons(bool v) async {
    state = state.copyWith(sons: v);
    await _prefs?.setBool(_cleSons, v);
  }

  Future<void> poserVibrations(bool v) async {
    state = state.copyWith(vibrations: v);
    await _prefs?.setBool(_cleVibrations, v);
  }

  Future<void> poserRythmeLent(bool v) async {
    state = state.copyWith(rythmeLent: v);
    await _prefs?.setBool(_cleRythme, v);
  }
}

final reglagesProvider =
    NotifierProvider<ReglagesNotifier, Reglages>(ReglagesNotifier.new);
