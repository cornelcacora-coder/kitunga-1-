import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../schema/structs/index.dart';

import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

class MoMoCallCall {
  // ── Vraie API MTN MoMo Congo (Production) ──────────────────────────────────
  static const String _baseUrl = 'https://proxy.momoapi.mtn.com';
  static const String _apiUser = '5d06e82a-3eb2-4fb1-a138-b5eaae47e143';
  static const String _apiKey = 'db57126d1df64f0e909eb52ffcbc8687';
  static const String _subscriptionKey = 'b9b0c0284c1744eaae459c5ad23aa873';
  static const String _targetEnv = 'mtncongo';

  /// Helper de log uniquement en mode debug
  static void _log(String tag, dynamic value) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MoMo][$tag] $value');
    }
  }

  static Future<ApiCallResponse> call({
    String? phoneNumber,
    double? amount,
    String? orderId,
  }) async {
    // Aucun montant par défaut : on ne débite jamais un montant arbitraire.
    if (amount == null || amount <= 0) {
      return ApiCallResponse(
        {
          'status': 'failed',
          'message': 'Montant de paiement invalide. Veuillez vérifier votre panier.',
          'step': 'validation',
        },
        {},
        400,
      );
    }

    final client = http.Client();

    try {
      // ── ÉTAPE 1 : Obtenir le token Bearer MTN MoMo ─────────────────────────
      final tokenUri = Uri.parse('$_baseUrl/collection/token/');
      final basicAuth = base64Encode(utf8.encode('$_apiUser:$_apiKey'));

      _log('TOKEN_URL', tokenUri);

      final tokenRes = await client.post(
        tokenUri,
        headers: {
          'Ocp-Apim-Subscription-Key': _subscriptionKey,
          'Authorization': 'Basic $basicAuth',
          'Content-Length': '0',
        },
      ).timeout(const Duration(seconds: 20));

      _log('TOKEN_STATUS', tokenRes.statusCode);
      _log('TOKEN_BODY', tokenRes.body);
      _log('TOKEN_HEADERS', tokenRes.headers);

      if (tokenRes.statusCode != 200) {
        String errMsg = 'Impossible d\'obtenir l\'autorisation auprès du serveur MTN (${tokenRes.statusCode}).';
        try {
          final errBody = jsonDecode(tokenRes.body);
          if (errBody['message'] != null) errMsg = errBody['message'].toString();
          if (errBody['error'] != null) errMsg += ' | ${errBody['error']}';
        } catch (_) {
          if (tokenRes.body.isNotEmpty) {
            errMsg += ' | Détail brut: ${tokenRes.body.substring(0, tokenRes.body.length.clamp(0, 300))}';
          }
        }
        _log('TOKEN_ERROR', errMsg);
        return ApiCallResponse(
          {'status': 'failed', 'message': errMsg, 'step': 'token'},
          {},
          tokenRes.statusCode == 200 ? 400 : tokenRes.statusCode,
        );
      }

      final tokenData = jsonDecode(tokenRes.body);
      final accessToken = tokenData['access_token'] as String;
      _log('TOKEN_OK', 'token_type=${tokenData['token_type']} expires_in=${tokenData['expires_in']}');

      // ── ÉTAPE 2 : Formater le numéro de téléphone (MSISDN Congo) ───────────
      String cleanPhone = (phoneNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      _log('PHONE_RAW', phoneNumber);
      _log('PHONE_CLEAN_BEFORE', cleanPhone);

      if (cleanPhone.startsWith('00242')) {
        cleanPhone = cleanPhone.substring(2);
      }
      if (cleanPhone.startsWith('242')) {
        // Déjà au format international
      } else if (cleanPhone.startsWith('06') && cleanPhone.length == 9) {
        cleanPhone = '242$cleanPhone';   // 06XXXXXXX → 24206XXXXXXX
      } else if (cleanPhone.startsWith('6') && cleanPhone.length == 8) {
        cleanPhone = '2420$cleanPhone';  // 6XXXXXXX  → 24206XXXXXXX
      } else if (cleanPhone.startsWith('6') && cleanPhone.length == 9) {
        cleanPhone = '242$cleanPhone';   // 6XXXXXXXX → 2426XXXXXXXX
      } else if (cleanPhone.isNotEmpty) {
        cleanPhone = '242$cleanPhone';
      }

      // Numéro invalide : on refuse plutôt que d'envoyer la demande à un tiers.
      if (cleanPhone.length < 11) {
        _log('PHONE_INVALID', 'longueur insuffisante: $cleanPhone');
        return ApiCallResponse(
          {
            'status': 'failed',
            'message':
                'Numéro Mobile Money invalide. Veuillez renseigner un numéro MTN valide (ex : 06 XXX XX XX).',
            'step': 'validation',
          },
          {},
          400,
        );
      }
      _log('PHONE_FINAL', cleanPhone);

      final refId = const Uuid().v4();
      final payAmount = amount.toInt().toString();
      final rawOrderId = orderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      // Nettoyage strict de l'orderId : suppression de '#' et tout symbole non alphanumérique.
      // Le WAF F5 d'MTN rejette la requête avec "Request Rejected" si externalId contient des caractères tels que '#'.
      final cleanOrderId = rawOrderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final safeOrderId = cleanOrderId.isNotEmpty ? cleanOrderId : 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final externalId = 'Kitunga-$safeOrderId';

      _log('PAY_AMOUNT', payAmount);
      _log('PAY_REF_ID', refId);
      _log('PAY_ORDER_ID', safeOrderId);
      _log('PAY_EXTERNAL_ID', externalId);
      _log('PAY_TARGET_ENV', _targetEnv);

      // ── ÉTAPE 3 : Envoyer le RequestToPay ──────────────────────────────────
      final payUri = Uri.parse('$_baseUrl/collection/v1_0/requesttopay');
      final payloadMap = {
        "amount": payAmount,
        "currency": "XAF", // Vraie devise Congo Franc CFA
        "externalId": externalId,
        "payer": {
          "partyIdType": "MSISDN",
          "partyId": cleanPhone,
        },
        "payerMessage": "Kitunga",
        "payeeNote": "Payement venant de Kitunga",
      };
      final payloadStr = jsonEncode(payloadMap);
      final payloadBytes = utf8.encode(payloadStr);

      _log('PAY_URL', payUri);
      _log('PAY_PAYLOAD', payloadStr);

      final payRes = await client.post(
        payUri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Reference-Id': refId,
          'X-Target-Environment': _targetEnv,
          'Ocp-Apim-Subscription-Key': _subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: payloadBytes,
      ).timeout(const Duration(seconds: 20));

      _log('PAY_STATUS', payRes.statusCode);
      _log('PAY_BODY', payRes.body);
      _log('PAY_HEADERS', payRes.headers);

      if (payRes.statusCode != 202) {
        String msg = 'La demande de paiement n\'a pas pu être initiée (code ${payRes.statusCode}).';
        String rawDetail = payRes.body.isEmpty ? 'réponse vide' : payRes.body.substring(0, payRes.body.length.clamp(0, 300));
        try {
          final errJson = jsonDecode(payRes.body);
          if (errJson['message'] != null) {
            msg = errJson['message'].toString();
          } else if (errJson['code'] != null) {
            msg = 'Erreur MTN: ${errJson['code']}';
          }
        } catch (_) {
          if (rawDetail.contains('Request Rejected')) {
            msg = 'La demande a été rejetée par la passerelle de sécurité MTN.';
          } else {
            msg += ' | $rawDetail';
          }
        }
        _log('PAY_ERROR', msg);
        _log('PAY_ERROR_RAW', rawDetail);
        return ApiCallResponse(
          {
            'status': 'failed',
            'message': msg,
            'step': 'requesttopay',
            'httpCode': payRes.statusCode,
            'rawDetail': rawDetail,
          },
          {},
          400, // Toujours retourner 400 en cas d'échec pour garantir que ApiCallResponse.succeeded soit false
        );
      }

      _log('PAY_OK', 'RequestToPay accepté (202). Début du polling...');

      // ── ÉTAPE 4 : Polling du statut (30 tentatives × 3s = max 90s) ─────────
      // Laisse le temps au client de saisir son code PIN sur son téléphone.
      int attempts = 0;
      const maxAttempts = 30;
      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
        attempts++;

        try {
          final statusUri = Uri.parse('$_baseUrl/collection/v1_0/requesttopay/$refId');
          final statusRes = await client.get(
            statusUri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'X-Target-Environment': _targetEnv,
              'Ocp-Apim-Subscription-Key': _subscriptionKey,
            },
          ).timeout(const Duration(seconds: 10));

          _log('POLL_ATTEMPT', '$attempts/$maxAttempts status=${statusRes.statusCode}');
          _log('POLL_BODY', statusRes.body);

          if (statusRes.statusCode == 200) {
            final statusData = jsonDecode(statusRes.body);
            final statusStr = statusData['status'] as String?;
            _log('POLL_STATUS_STR', statusStr);

            if (statusStr == 'SUCCESSFUL') {
              return ApiCallResponse(
                {
                  'status': 'success',
                  'orderId': safeOrderId,
                  'referenceId': refId,
                  'message': 'Paiement validé avec succès sur votre compte MTN Mobile Money !',
                },
                {},
                200,
              );
            } else if (statusStr == 'FAILED') {
              final reason = statusData['reason'] as String? ?? '';
              _log('POLL_FAILED_REASON', reason);
              String frenchReason = 'La transaction a été refusée ou a échoué.';
              if (reason.contains('LOW_BALANCE')) {
                frenchReason = 'Solde insuffisant sur votre compte Mobile Money. Veuillez recharger et réessayer.';
              } else if (reason.contains('NOT_ALLOWED') || reason.contains('LIMIT')) {
                frenchReason = 'Plafond ou restriction atteinte sur votre compte Mobile Money.';
              } else if (reason.contains('PAYER_NOT_FOUND')) {
                frenchReason = 'Ce numéro de téléphone n\'est pas reconnu par MTN Mobile Money.';
              } else if (reason.contains('REJECTED') || reason.contains('CANCELLED')) {
                frenchReason = 'Le paiement a été rejeté ou annulé depuis votre téléphone.';
              } else if (reason.contains('TIMEOUT')) {
                frenchReason = 'Délai de saisie du code PIN dépassé. Veuillez réessayer.';
              } else if (reason.isNotEmpty) {
                frenchReason = 'Échec du paiement: $reason';
              }

              return ApiCallResponse(
                {
                  'status': 'failed',
                  'reason': reason,
                  'referenceId': refId,
                  'message': frenchReason,
                },
                {},
                400,
              );
            }
            // statusStr == 'PENDING' → continuer le polling
          }
        } catch (pollErr) {
          _log('POLL_EXCEPTION', pollErr);
        }
      }

      // Timeout de polling : la requête MTN a été acceptée mais le paiement
      // n'est pas confirmé. On ne le considère PAS comme réussi, sinon une
      // commande serait créée sans que l'argent soit encaissé.
      _log('POLL_TIMEOUT', 'Aucun résultat après ${maxAttempts * 3}s. Paiement non confirmé.');
      return ApiCallResponse(
        {
          'status': 'pending',
          'orderId': safeOrderId,
          'referenceId': refId,
          'message':
              'Le paiement n\'a pas été confirmé à temps, votre commande n\'a donc pas été enregistrée. '
              'Si votre compte a été débité, contactez le support en indiquant la référence : $refId',
        },
        {},
        408,
      );
    } catch (e, stack) {
      _log('GLOBAL_ERROR', e);
      _log('GLOBAL_STACK', stack);
      return ApiCallResponse(
        {
          'status': 'failed',
          'message': 'Erreur de connexion au serveur de paiement. Vérifiez votre réseau et réessayez.',
          'errorDetail': e.toString(),
        },
        {},
        500,
      );
    } finally {
      client.close();
    }
  }

  static String? status(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.status''',
      ));
  static String? orderId(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.orderId''',
      ));
  static String? message(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.message''',
      ));
  static String? referenceId(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.referenceId''',
      ));
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  if (item is DocumentReference) {
    return item.path;
  }
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
