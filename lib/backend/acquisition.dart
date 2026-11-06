import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '/backend/server_payment.dart' show kitungaCallFunction;

/// Code commercial reçu à l'installation (module commercial).
///
/// Au premier lancement sur Android, lit le code transmis par Google Play
/// (Install Referrer), le garde sur le téléphone et l'envoie au serveur dès
/// qu'un utilisateur est connecté (visiteur ou compte). Le serveur revérifie
/// tout : ce code n'est qu'une indication. Rien ici ne doit jamais bloquer ni
/// ralentir l'application : toute erreur est ignorée et retentée plus tard.
class KitungaAcquisition {
  KitungaAcquisition._();

  static const _installKey = 'kitunga_installation_id';
  static const _referralKey = 'kitunga_referral';
  static const _referrerReadKey = 'kitunga_referrer_read';
  static const _touchSentKey = 'kitunga_touch_sent';
  static const _manualCodeKey = 'kitunga_manual_code';
  static const _claimDoneKey = 'kitunga_claim_done';
  static const _claimAttemptsKey = 'kitunga_claim_attempts';
  static const _maxClaimAttempts = 5;
  static const _activationDoneKey = 'kitunga_activation_done';
  static const _activationAttemptsKey = 'kitunga_activation_attempts';
  static const _maxActivationAttempts = 5;
  static bool _appCheckReady = false;
  static final _codePattern = RegExp(r'^KTG\d{3,6}-[2-9A-HJKMNP-Z]{4}$');

  static bool _started = false;
  static bool _syncing = false;

  /// Identifiant d'installation : tiré au hasard une fois, jamais un
  /// identifiant matériel. Perdu si l'application est désinstallée.
  static Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_installKey, id);
    }
    return id;
  }

  /// Code commercial gardé sur le téléphone, ou null.
  static Future<String?> savedCode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_referralKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Format d'un code commercial (KTG001-X7P9), après mise en majuscules.
  static bool isValidCode(String code) =>
      _codePattern.hasMatch(code.trim().toUpperCase());

  /// Code saisi à l'inscription (iPhone, lien non utilisé…).
  static Future<void> rememberManualCode(String code) async {
    final value = code.trim().toUpperCase();
    if (!_codePattern.hasMatch(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manualCodeKey, value);
  }

  /// Envoie tout de suite (après l'inscription), sans attendre le résultat.
  static Future<void> syncNow() => _sync();

  /// À appeler une fois au démarrage, sans attendre le résultat.
  static void start() {
    if (_started) return;
    _started = true;
    _run();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _sync();
    });
  }

  /// App Check (Play Integrity) : seulement sur Android. Pas de rafraîchis-
  /// sement automatique, pour ménager le quota Play Integrity ; un jeton à
  /// usage unique est demandé pour l'activation. En version de test (debug),
  /// fournisseur « debug » (Play Integrity refuse les APK hors Google Play).
  static Future<void> _activateAppCheck() async {
    if (_appCheckReady || kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
    _appCheckReady = true;
  }

  static Future<void> _run() async {
    try {
      await _activateAppCheck();
    } catch (_) {
      // App Check indisponible : l'activation restera non vérifiée.
    }
    try {
      await _readInstallReferrer();
    } catch (_) {
      // Service Google Play indisponible : nouvel essai au prochain lancement.
    }
    await _sync();
  }

  static Future<void> _readInstallReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_referrerReadKey) == true) return;
    final details = await PlayInstallReferrer.installReferrer;
    await prefs.setBool(_referrerReadKey, true);
    final referral = parseInstallReferrer(
      details.installReferrer,
      clickAtSeconds: details.referrerClickTimestampServerSeconds > 0
          ? details.referrerClickTimestampServerSeconds
          : details.referrerClickTimestampSeconds,
    );
    if (referral != null) {
      await prefs.setString(_referralKey, jsonEncode(referral));
    }
  }

  /// Extrait le code du texte transmis par Google Play, ou null.
  @visibleForTesting
  static Map<String, dynamic>? parseInstallReferrer(String? referrer,
      {int clickAtSeconds = 0}) {
    if (referrer == null || referrer.isEmpty) return null;
    Map<String, String> params;
    try {
      params = Uri.splitQueryString(referrer);
    } catch (_) {
      return null;
    }
    final code = (params['kitunga_code'] ?? '').trim().toUpperCase();
    if (!_codePattern.hasMatch(code)) return null;
    final click = params['kitunga_click'] ?? '';
    return {
      'code': code,
      'source': 'install_referrer',
      if (RegExp(r'^[A-Za-z0-9]{10,40}$').hasMatch(click)) 'clickId': click,
      if (clickAtSeconds > 0) 'referrerClickAt': clickAtSeconds,
    };
  }

  /// Envoie le premier contact, puis demande l'attribution du compte client.
  static Future<void> _sync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final touchPending = await _sendTouch(prefs);
      if (!touchPending) await _sendActivation(prefs);
      // Un visiteur (compte anonyme) n'est pas encore un client.
      if (!user.isAnonymous && !touchPending) await _claim(prefs);
    } catch (_) {
      // Réseau ou serveur indisponible : nouvel essai plus tard.
    } finally {
      _syncing = false;
    }
  }

  /// Premier contact de l'appareil (une seule fois). Renvoie true s'il reste
  /// à envoyer (échec réseau) : l'attribution attend alors le prochain essai.
  static Future<bool> _sendTouch(SharedPreferences prefs) async {
    if (prefs.getBool(_touchSentKey) == true) return false;
    final raw = prefs.getString(_referralKey);
    if (raw == null) return false;
    try {
      final referral = jsonDecode(raw) as Map<String, dynamic>;
      await kitungaCallFunction('kitungaRecordTouch', {
        ...referral,
        'installationId': await installationId(),
      });
      // Accepté ou refusé par le serveur : la réponse est définitive.
      await prefs.setBool(_touchSentKey, true);
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Activation attestée par App Check (Play Integrity), une fois par
  /// installation, seulement si un code commercial est présent.
  static Future<void> _sendActivation(SharedPreferences prefs) async {
    if (prefs.getBool(_activationDoneKey) == true) return;
    if (prefs.getString(_referralKey) == null &&
        prefs.getString(_manualCodeKey) == null) {
      return;
    }
    String? token;
    try {
      if (_appCheckReady) {
        token = await FirebaseAppCheck.instance.getLimitedUseToken();
      }
    } catch (_) {
      token = null; // Play Integrity indisponible : activation non vérifiée.
    }
    try {
      final result = await kitungaCallFunction('kitungaRecordActivation',
          {'installationId': await installationId()},
          appCheckToken: token);
      if (result['verified'] == true) {
        await prefs.setBool(_activationDoneKey, true);
        return;
      }
    } catch (_) {
      return; // Réseau ou serveur : nouvel essai plus tard, sans compter.
    }
    final attempts = (prefs.getInt(_activationAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_activationAttemptsKey, attempts);
    if (attempts >= _maxActivationAttempts) {
      await prefs.setBool(_activationDoneKey, true);
    }
  }

  /// Attribution du compte au commercial (confirmée par le serveur).
  static Future<void> _claim(SharedPreferences prefs) async {
    if (prefs.getBool(_claimDoneKey) == true) return;
    final manualCode = prefs.getString(_manualCodeKey);
    final hasReferral = prefs.getString(_referralKey) != null;
    if (!hasReferral && manualCode == null) return;
    final result = await kitungaCallFunction('kitungaClaimAttribution', {
      'installationId': await installationId(),
      if (manualCode != null) 'code': manualCode,
    });
    // « Pas un client » juste après l'inscription : le profil n'est peut-être
    // pas encore enregistré. Quelques nouveaux essais, puis on s'arrête.
    if (result['status'] == 'not_a_client') {
      final attempts = (prefs.getInt(_claimAttemptsKey) ?? 0) + 1;
      await prefs.setInt(_claimAttemptsKey, attempts);
      if (attempts < _maxClaimAttempts) return;
    }
    await prefs.setBool(_claimDoneKey, true);
  }
}
