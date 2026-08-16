import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    enregistrerSonsSysteme(engineBridge)
  }

  /// Sons courts du système, joués par identifiant.
  ///
  /// `AudioServicesPlaySystemSound` respecte l'interrupteur silencieux et le
  /// volume d'interface : c'est exactement le comportement attendu d'un bip de
  /// messagerie. Les identifiants employés sont choisis côté Dart — voir
  /// `services/system_sounds.dart`, qui exclut délibérément le tri-tone SMS.
  private func enregistrerSonsSysteme(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SystemSounds") else {
      return
    }
    let canal = FlutterMethodChannel(
      name: "numero_inconnu/system_sounds",
      binaryMessenger: registrar.messenger()
    )
    canal.setMethodCallHandler { appel, resultat in
      guard appel.method == "play",
            let arguments = appel.arguments as? [String: Any],
            let identifiant = arguments["id"] as? UInt32
      else {
        resultat(FlutterMethodNotImplemented)
        return
      }
      AudioServicesPlaySystemSound(SystemSoundID(identifiant))
      resultat(nil)
    }
  }
}
