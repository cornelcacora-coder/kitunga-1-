import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';

/// Messagerie Kitunga : conversations liées aux commandes (client,
/// commerce, livreur) et annonces de l'équipe. Le serveur vérifie les
/// droits, enregistre les messages et prévient le destinataire.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    messagesBackendOverride;

/// Désactive les rafraîchissements périodiques dans les tests.
@visibleForTesting
bool messagesNoPolling = false;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    messagesBackendOverride != null
        ? messagesBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const _red = Color(0xFFE51A1A);

const kChatRoleLabels = {
  'client': 'Client',
  'commerce': 'Commerce',
  'livreur': 'Livreur',
  'admin': 'Kitunga',
  'support': 'Support Kitunga',
  'destinataire': 'Kitunga',
  'kitunga': 'Équipe Kitunga',
};

List<Map<String, dynamic>> _list(dynamic v) => (v as List? ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

String _time(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final now = DateTime.now();
  final hm = '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return hm;
  }
  return '${d.day}/${d.month} $hm';
}

void _snack(BuildContext context, String m) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));

/// Ouvre la conversation avec un autre acteur de la commande
/// (with : 'client', 'commerce' ou 'livreur').
Future<void> openOrderChat(
    BuildContext context, String orderId, String withRole) async {
  try {
    final r = await _call(
        'kitungaOpenOrderChat', {'orderId': orderId, 'with': withRole});
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => KitungaChatPage(
            conversationId: '${r['conversationId']}',
            title: kChatRoleLabels[withRole] ?? 'Conversation')));
  } on ServerPaymentException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, 'Connexion impossible. Réessayez.');
  }
}

/// L'équipe (admin ou support) écrit directement à une personne.
Future<void> openStaffDirectChat(BuildContext context, String uid) async {
  try {
    final r = await _call('kitungaStaffOpenDirect', {'uid': uid});
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => KitungaChatPage(
            conversationId: '${r['conversationId']}',
            title: '${r['title'] ?? 'Message direct'}')));
  } on ServerPaymentException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, 'Connexion impossible. Réessayez.');
  }
}

/// Ouvre une conversation existante (équipe Kitunga : litige, boîte).
Future<void> openConversation(
        BuildContext context, String conversationId, String title) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            KitungaChatPage(conversationId: conversationId, title: title)));

/// Nombre total de messages non lus (pour les badges).
Future<int> kitungaUnreadMessages() async {
  try {
    final r = await _call('kitungaMyConversations', const {});
    return (r['unread'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
}

// ── Liste des conversations ──────────────────────────────────────────────

class KitungaConversationsPage extends StatefulWidget {
  const KitungaConversationsPage({super.key, this.showAppBar = false});

  /// Barre de titre (page ouverte seule) ; dans un onglet : titre intégré.
  final bool showAppBar;

  @override
  State<KitungaConversationsPage> createState() =>
      _KitungaConversationsPageState();
}

class _KitungaConversationsPageState extends State<KitungaConversationsPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    if (!messagesNoPolling) {
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _call('kitungaMyConversations', const {});
      if (mounted) {
        setState(() {
          _items = _list(r['conversations']);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connexion perdue. Tirez pour réessayer.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final items = _items;
    final body = RefreshIndicator(
      color: _red,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, widget.showAppBar ? 8 : MediaQuery.paddingOf(context).top + 16,
            16, 24),
        children: [
          if (!widget.showAppBar)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text('Messages',
                  style: GoogleFonts.interTight(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!,
                  style: GoogleFonts.inter(color: _red, fontSize: 13)),
            ),
          if (items == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: _red)),
            )
          else if (items != null && items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: _red.withValues(alpha: 0.08),
                    child: const Icon(Icons.forum_outlined,
                        color: _red, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text('Aucune conversation',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: theme.primaryText)),
                  const SizedBox(height: 4),
                  Text(
                      'Écrivez au client, au commerce ou au livreur depuis '
                      'une commande (bouton « Message »).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: theme.secondaryText)),
                ],
              ),
            )
          else
            for (final c in items ?? const <Map<String, dynamic>>[])
              _ConversationTile(
                c: c,
                onOpen: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => KitungaChatPage(
                          conversationId: '${c['id']}',
                          title: c['kind'] == 'announcement'
                              ? 'Annonces Kitunga'
                              : c['kind'] == 'direct'
                                  ? 'Équipe Kitunga'
                                  : '${kChatRoleLabels[c['withRole']] ?? ''} · '
                                      '${c['title']}')));
                  _load();
                },
              ),
        ],
      ),
    );
    if (!widget.showAppBar) return body;
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Messages',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
      ),
      body: body,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.c, required this.onOpen});

  final Map<String, dynamic> c;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final unread = (c['unread'] as num?)?.toInt() ?? 0;
    final announce = c['kind'] == 'announcement';
    final direct = c['kind'] == 'direct';
    final role = '${c['withRole'] ?? ''}';
    final icon = announce
        ? Icons.campaign_rounded
        : direct
            ? Icons.support_agent_rounded
        : role == 'livreur'
            ? Icons.delivery_dining_rounded
            : role == 'commerce'
                ? Icons.storefront_rounded
                : Icons.person_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: unread > 0 ? _red.withValues(alpha: 0.4) : theme.alternate),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onOpen,
          leading: CircleAvatar(
            backgroundColor: _red.withValues(alpha: 0.1),
            child: Icon(icon, color: _red),
          ),
          title: Text(
              announce
                  ? 'Annonces Kitunga'
                  : direct
                      ? 'Équipe Kitunga'
                      : '${kChatRoleLabels[role] ?? ''} · ${c['title']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                  color: theme.primaryText)),
          subtitle: Text('${c['lastMessage'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.inter(fontSize: 13, color: theme.secondaryText)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_time(c['lastAt'] as String?),
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: theme.secondaryText)),
              if (unread > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _red, borderRadius: BorderRadius.circular(20)),
                  child: Text('$unread',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Conversation ─────────────────────────────────────────────────────────

class KitungaChatPage extends StatefulWidget {
  const KitungaChatPage(
      {super.key, required this.conversationId, required this.title});

  final String conversationId;
  final String title;

  @override
  State<KitungaChatPage> createState() => _KitungaChatPageState();
}

class _KitungaChatPageState extends State<KitungaChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>>? _messages;
  bool _open = true;
  bool _sending = false;
  bool _offline = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    if (!messagesNoPolling) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _call('kitungaConversationMessages',
          {'conversationId': widget.conversationId});
      if (!mounted) return;
      final before = _messages?.length ?? 0;
      setState(() {
        _messages = _list(r['messages']);
        _open = r['open'] != false;
        _offline = false;
      });
      if ((_messages?.length ?? 0) != before) _toBottom();
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _call('kitungaSendMessage',
          {'conversationId': widget.conversationId, 'text': text});
      _text.clear();
      await _load();
    } on ServerPaymentException catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {
      // Rien n'est considéré envoyé sans réponse du serveur.
      if (mounted) {
        _snack(context, 'Message non envoyé : vérifiez votre connexion.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final messages = _messages;
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text(widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          if (_offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3E0),
              padding: const EdgeInsets.all(8),
              child: Text('Connexion perdue : nouvel essai en cours…',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12.5)),
            ),
          Expanded(
            child: messages == null
                ? const Center(child: CircularProgressIndicator(color: _red))
                : messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              'Aucun message. Écrivez le premier : il sera '
                              'notifié aussitôt.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: theme.secondaryText)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) => _Bubble(m: messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              color: theme.secondaryBackground,
              child: _open
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('chat-input'),
                            controller: _text,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Votre message…',
                              isDense: true,
                              filled: true,
                              fillColor: theme.primaryBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          key: const ValueKey('chat-send'),
                          style: IconButton.styleFrom(backgroundColor: _red),
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          'Conversation fermée : lecture seule.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: theme.secondaryText, fontSize: 13)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});

  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mine = m['mine'] == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? _red : theme.secondaryBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: theme.alternate),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                  [
                    kChatRoleLabels[m['fromRole']] ?? '',
                    if ('${m['fromName'] ?? ''}'.isNotEmpty &&
                        m['fromRole'] != 'admin')
                      '${m['fromName']}',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _red)),
            Text('${m['text'] ?? ''}',
                style: GoogleFonts.inter(
                    fontSize: 14.5,
                    color: mine ? Colors.white : theme.primaryText)),
            const SizedBox(height: 2),
            Text(_time(m['at'] as String?),
                style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.8)
                        : theme.secondaryText)),
          ],
        ),
      ),
    );
  }
}
