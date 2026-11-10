import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Notifications : centre de notifications (fonctions kitungaMyNotifications,
/// kitungaMarkNotificationsRead) et notifications push (Firebase Cloud
/// Messaging ; jeton enregistré par kitungaSaveFcmToken).

/// Tests : remplace le serveur.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    notificationsBackendOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    notificationsBackendOverride != null
        ? notificationsBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

/// Notifications du client connecté et nombre de non lues.
class KitungaNotificationStore extends ChangeNotifier {
  KitungaNotificationStore._();
  static final instance = KitungaNotificationStore._();

  List<Map<String, dynamic>> items = const [];
  int unread = 0;
  bool _pushStarted = false;

  Future<void> refresh() async {
    if (currentUserUid.isEmpty && notificationsBackendOverride == null) return;
    try {
      final r = await _call('kitungaMyNotifications', {});
      items = [
        for (final n in (r['notifications'] as List? ?? const []))
          Map<String, dynamic>.from(n as Map),
      ];
      unread = (r['unread'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {
      // Hors connexion : on garde l'état actuel.
    }
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    unread = 0;
    items = [for (final n in items) {...n, 'read': true}];
    notifyListeners();
    try {
      await _call('kitungaMarkNotificationsRead', {});
    } catch (_) {}
  }

  /// Autorisation, jeton du téléphone, réception au premier plan.
  /// Une fois par session ; sans effet sur le web.
  Future<void> startPush() async {
    if (_pushStarted || kIsWeb || currentUserUid.isEmpty) return;
    _pushStarted = true;
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token != null) {
        await _call('kitungaSaveFcmToken', {'token': token});
      }
      fm.onTokenRefresh
          .listen((t) => _call('kitungaSaveFcmToken', {'token': t}));
      // Application ouverte : la cloche se met à jour.
      FirebaseMessaging.onMessage.listen((_) => refresh());
      FirebaseMessaging.onMessageOpenedApp.listen((_) => refresh());
    } catch (e) {
      debugPrint('Notifications push indisponibles : $e');
    }
    await refresh();
  }
}

/// Cloche avec le nombre de notifications non lues.
class KitungaNotificationBell extends StatefulWidget {
  const KitungaNotificationBell(
      {super.key, this.size = 38.0, this.onSubscription});

  final double size;

  /// Ouvre le module abonnement depuis un rappel.
  final void Function(BuildContext context)? onSubscription;

  @override
  State<KitungaNotificationBell> createState() =>
      _KitungaNotificationBellState();
}

class _KitungaNotificationBellState extends State<KitungaNotificationBell> {
  @override
  void initState() {
    super.initState();
    final store = KitungaNotificationStore.instance;
    unawaited(store.startPush());
    unawaited(store.refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserUid.isEmpty && notificationsBackendOverride == null) {
      return const SizedBox.shrink();
    }
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: KitungaNotificationStore.instance,
      builder: (context, _) {
        final unread = KitungaNotificationStore.instance.unread;
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => KitungaNotificationsPage(
                  onSubscription: widget.onSubscription))),
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E242B) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2C3238)
                        : const Color(0xFFF1F4F8),
                  ),
                ),
                child: Icon(Icons.notifications_none_rounded,
                    color: theme.primaryText, size: 20.0),
              ),
              if (unread > 0)
                Positioned(
                  right: -2.0,
                  top: -2.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 1.0),
                    constraints:
                        const BoxConstraints(minWidth: 18.0, minHeight: 18.0),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(9.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(unread > 9 ? '9+' : '$unread',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Liste des notifications (marquées lues à l'ouverture).
class KitungaNotificationsPage extends StatefulWidget {
  const KitungaNotificationsPage({super.key, this.onSubscription});

  /// Ouvre le module abonnement (notification de rappel).
  final void Function(BuildContext context)? onSubscription;

  @override
  State<KitungaNotificationsPage> createState() =>
      _KitungaNotificationsPageState();
}

class _KitungaNotificationsPageState extends State<KitungaNotificationsPage> {
  final _store = KitungaNotificationStore.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store.refresh().whenComplete(() {
      if (!mounted) return;
      setState(() => _loading = false);
      _store.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text('Notifications',
            style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 19.0,
                fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          if (_loading && _store.items.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          if (_store.items.isEmpty) {
            return Center(
              child: Text('Aucune notification pour le moment.',
                  style: GoogleFonts.inter(color: theme.secondaryText)),
            );
          }
          return RefreshIndicator(
            onRefresh: _store.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 24.0),
              itemCount: _store.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8.0),
              itemBuilder: (context, i) {
                final n = _store.items[i];
                final at = DateTime.tryParse('${n['createdAt']}')?.toLocal();
                final subscription = n['kind'] == 'subscription';
                return Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: theme.primaryBackground,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                        color: n['read'] == true
                            ? theme.alternate
                            : theme.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          subscription
                              ? Icons.workspace_premium_outlined
                              : Icons.campaign_outlined,
                          color: theme.primary),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${n['title']}',
                                style: GoogleFonts.inter(
                                    color: theme.primaryText,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2.0),
                            Text('${n['body']}',
                                style: GoogleFonts.inter(
                                    color: theme.secondaryText,
                                    fontSize: 13.5)),
                            if (at != null)
                              Text(dateTimeFormat('d MMM y, HH:mm', at),
                                  style: GoogleFonts.inter(
                                      color: theme.secondaryText,
                                      fontSize: 11.5)),
                            if (subscription && widget.onSubscription != null)
                              TextButton(
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero),
                                onPressed: () =>
                                    widget.onSubscription!(context),
                                child: const Text('Renouveler mon abonnement'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
