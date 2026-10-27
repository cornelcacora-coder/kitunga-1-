import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/schema/structs/index.dart';
import '/auth/firebase_auth/auth_util.dart';

double? calculateSubtotal(List<CartRecord>? cartItems) {
// 1. Protection contre la liste nulle ou vide
  if (cartItems == null || cartItems.isEmpty) {
    return 0.0;
  }

  // 2. Calcul avec fold
  return cartItems.fold<double>(0.0, (double sum, item) {
    // Note: Si 'price' est marqué comme non-nullable dans FF,
    // retire le '?? 0.0' pour enlever l'erreur "dead_null_aware".
    // On ajoute .toDouble() au cas où c'est un entier en DB.

    final price = (item.price).toDouble();
    final quantity = item
        .quantity; // Si FF dit que c'est non-nullable, pas de ?? ici non plus

    return sum + (price * quantity);
  });
}

double? calculateGrandTotal(
  List<CartRecord>? cartItems,
  double shippingFee,
) {
  if (cartItems == null || cartItems.isEmpty) {
    return 0.0;
  }
  // 1. On calcule le sous-total (Prix * Quantité)
  double subtotal = cartItems.fold<double>(0.0, (double sum, item) {
    final double price = (item.price).toDouble();
    final int quantity = item.quantity;
    return sum + (price * quantity);
  });

  // 2. On ajoute les frais fixes une seule fois au total
  return subtotal + shippingFee;
}

double? calculateSellerResponseTime(List<OrdersRecord>? commandes) {
  if (commandes == null || commandes.isEmpty) {
    return 0.0;
  }

  double totalMinutes = 0.0;
  int count = 0;

  for (var cmd in commandes) {
    if (cmd.createdAt != null && cmd.respondedAt != null) {
      final difference = cmd.respondedAt!.difference(cmd.createdAt!);
      totalMinutes += difference.inMinutes.toDouble();
      count++;
    }
  }

  if (count == 0) {
    return 0.0;
  }
  return totalMinutes / count;
}

double? calculateErrorRate(List<SystemLogsRecord>? logs) {
  if (logs == null || logs.isEmpty) {
    return 0.0;
  }

  int errorCount = 0;

  for (var log in logs) {
    // Supposons que vous avez un champ 'status' ou 'isError' dans votre log
    if (log.status == 'error') {
      errorCount++;
    }
  }

  // Calcul du pourcentage
  return (errorCount / logs.length) * 100;
}
