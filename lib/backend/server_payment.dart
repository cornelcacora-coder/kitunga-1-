import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Paiement MTN contrôlé par le serveur (firebase/functions/kitunga).
/// Activé : kitungaStartPayment et kitungaConfirmPayment doivent être en
/// ligne AVANT la publication de l'application qui contient ce réglage.
/// Le stock est réservé (décrémenté) à la confirmation du paiement.
const kServerPayment = true;

const _functionsUrl = 'https://us-west1-kitunga-xtvpe4.cloudfunctions.net';

class ServerPaymentException implements Exception {
  ServerPaymentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Résultat final : status = 'paid' | 'paid_refund' | 'failed' | 'pending'.
typedef ServerPaymentResult = ({
  String status,
  String? orderPath,
  String? reason,
  double amount,
});

/// Appel d'une fonction « onCall » par HTTP (protocole callable Firebase).
Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data,
    {String? appCheckToken, bool public = false}) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null && !public) {
    throw ServerPaymentException('Connexion requise.');
  }
  final http.Response res;
  try {
    res = await http
        .post(
          Uri.parse('$_functionsUrl/$name'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
            if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 60));
  } catch (_) {
    throw ServerPaymentException(
        'Impossible de joindre Kitunga. Vérifiez votre connexion internet.');
  }
  final Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw ServerPaymentException(
        'Le service Kitunga est indisponible. Réessayez plus tard.');
  }
  if (body['error'] != null) {
    throw ServerPaymentException(
        '${body['error']['message'] ?? 'Le paiement a échoué.'}');
  }
  return Map<String, dynamic>.from(body['result'] as Map);
}

/// Appelle une Cloud Function Kitunga. Les erreurs sont levées en
/// [ServerPaymentException], avec un message à montrer tel quel.
/// [appCheckToken] : jeton App Check facultatif (module commercial).
Future<Map<String, dynamic>> kitungaCallFunction(
        String name, Map<String, dynamic> data,
        {String? appCheckToken}) =>
    _call(name, data, appCheckToken: appCheckToken);

/// Lecture publique (ex. bannières d'accueil) : possible sans être connecté.
Future<Map<String, dynamic>> kitungaCallPublicFunction(
        String name, Map<String, dynamic> data) =>
    _call(name, data, public: true);

/// Lance le paiement puis attend la validation du client (code PIN MTN).
/// Le serveur recalcule prix, frais et stock ; il crée la commande.
Future<ServerPaymentResult> kitungaServerPay({
  required DocumentReference sellerRef,
  required String zone,
  required String deliveryLocation,
  required String phone,
  String operator = 'MTN',
  Map<String, double>? deliveryPoint,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final start = await _call('kitungaStartPayment', {
    if (deliveryPoint != null) 'deliveryPoint': deliveryPoint,
    'sellerPath': sellerRef.path,
    'zone': zone,
    'deliveryLocation': deliveryLocation,
    'phone': phone,
    'operator': operator,
  });
  final referenceId = start['referenceId'] as String;
  final amount = (start['amount'] as num).toDouble();
  final end = DateTime.now().add(timeout);
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    Map<String, dynamic> r;
    try {
      r = await _call('kitungaConfirmPayment', {'referenceId': referenceId});
    } on ServerPaymentException {
      // Réseau coupé pendant l'attente : on réessaie. Le serveur termine
      // de toute façon les paiements validés (toutes les 5 minutes).
      if (DateTime.now().isAfter(end))
        r = {'status': 'pending'};
      else
        continue;
    }
    final status = r['status'] as String;
    if (status != 'pending' || DateTime.now().isAfter(end)) {
      return (
        status: status,
        orderPath: r['orderPath'] as String?,
        reason: r['reason'] as String?,
        amount: amount,
      );
    }
  }
}
