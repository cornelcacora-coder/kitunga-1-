import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/firebase_storage/storage.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/upload_data.dart';

/// Support Kitunga dans l'application (clients, vendeurs, livreurs) :
/// mes demandes, nouvelle demande (avec photo), fil de discussion avec le
/// support. Les tickets sont traités par l'équipe dans l'espace /support.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    supportBackendOverride;

/// Remplace la photo jointe dans les tests (adresse renvoyée).
@visibleForTesting
Future<String?> Function()? supportPhotoOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    supportBackendOverride != null
        ? supportBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const _red = Color(0xFFE51A1A);

const kTicketCategories = {
  'commande': 'Commande',
  'livraison': 'Livraison',
  'paiement': 'Paiement / remboursement',
  'compte': 'Compte / abonnement',
  'produit': 'Produit',
  'autre': 'Autre',
};

const kTicketStatus = {
  'open': ('Ouverte', Color(0xFFE08A00)),
  'in_progress': ('En cours', Color(0xFF2563EB)),
  'waiting_user': ('Réponse reçue', Color(0xFF17A35B)),
  'escalated': ('Transmise', Color(0xFF7C3AED)),
  'resolved': ('Résolue', Color(0xFF8A94A6)),
};

List<Map<String, dynamic>> _list(dynamic v) => (v as List? ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

String _date(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

Future<String?> _pickPhoto(BuildContext context) async {
  if (supportPhotoOverride != null) return supportPhotoOverride!();
  final media = await selectMedia(
      maxWidth: 1280.0, maxHeight: 1280.0, imageQuality: 80, multiImage: false);
  if (media == null || media.isEmpty) return null;
  if (!context.mounted ||
      !validateFileFormat(media.first.storagePath, context)) {
    return null;
  }
  return uploadData(media.first.storagePath, media.first.bytes);
}

/// Ouvre « Mes demandes ».
Future<void> openKitungaSupport(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const KitungaSupportPage()));

/// Nouvelle demande, éventuellement liée à une commande ; ouvre ensuite
/// son fil.
Future<void> openNewTicket(BuildContext context,
    {String? orderId, String? orderRef, String category = 'commande'}) async {
  final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => KitungaNewTicketPage(
              orderId: orderId, orderRef: orderRef, category: category)));
  if (created == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KitungaTicketPage(ticketId: '${created['ticketId']}')));
}

// ── Mes demandes ─────────────────────────────────────────────────────────

class KitungaSupportPage extends StatefulWidget {
  const KitungaSupportPage({super.key});

  @override
  State<KitungaSupportPage> createState() => _KitungaSupportPageState();
}

class _KitungaSupportPageState extends State<KitungaSupportPage> {
  List<Map<String, dynamic>>? _tickets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _call('kitungaMyTickets', const {});
      if (mounted) {
        setState(() {
          _tickets = _list(r['tickets']);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Connexion impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final tickets = _tickets;
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Aide & support',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('support-new'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
        onPressed: () async {
          await openNewTicket(context);
          _load();
        },
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Nouvelle demande'),
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded,
                      color: _red, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Un problème avec une commande, un paiement ou votre '
                        'compte ? Écrivez-nous : l\'équipe Kitunga vous '
                        'répond ici.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: theme.primaryText)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!, style: GoogleFonts.inter(color: _red)),
            if (tickets == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: _red)),
              )
            else if (tickets != null && tickets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text('Aucune demande pour le moment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: theme.secondaryText)),
              )
            else
              for (final t in tickets ?? const <Map<String, dynamic>>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: theme.secondaryBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: t['unread'] == true
                              ? _red.withValues(alpha: 0.5)
                              : theme.alternate),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                KitungaTicketPage(ticketId: '${t['id']}')));
                        _load();
                      },
                      title: Text('${t['number']} · ${t['subject']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontWeight: t['unread'] == true
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: theme.primaryText)),
                      subtitle: Text('${t['lastMessage'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: theme.secondaryText)),
                      trailing: _StatusChip(status: '${t['status']}'),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = kTicketStatus[status] ?? (status, const Color(0xFF8A94A6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: s.$2.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(s.$1,
          style: GoogleFonts.inter(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: s.$2)),
    );
  }
}

// ── Nouvelle demande ─────────────────────────────────────────────────────

class KitungaNewTicketPage extends StatefulWidget {
  const KitungaNewTicketPage(
      {super.key, this.orderId, this.orderRef, this.category = 'commande'});

  final String? orderId;
  final String? orderRef;
  final String category;

  @override
  State<KitungaNewTicketPage> createState() => _KitungaNewTicketPageState();
}

class _KitungaNewTicketPageState extends State<KitungaNewTicketPage> {
  late String _category =
      kTicketCategories.containsKey(widget.category) ? widget.category : 'autre';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _photos = <String>[];
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      return _snack(context, 'Décrivez votre demande.');
    }
    setState(() => _busy = true);
    try {
      final r = await _call('kitungaCreateTicket', {
        'category': _category,
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
        if (widget.orderId != null) 'orderId': widget.orderId,
        'photos': _photos,
      });
      if (mounted) Navigator.pop(context, r);
    } on ServerPaymentException catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {
      if (mounted) {
        _snack(context, 'Demande non envoyée : vérifiez votre connexion.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Nouvelle demande',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.orderRef != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Chip(
                avatar: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text('Commande ${widget.orderRef}'),
              ),
            ),
          DropdownButtonFormField<String>(
            key: const ValueKey('ticket-category'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Sujet'),
            items: [
              for (final e in kTicketCategories.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            maxLength: 120,
            decoration:
                const InputDecoration(labelText: 'Titre (facultatif)'),
          ),
          TextField(
            key: const ValueKey('ticket-message'),
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            decoration: const InputDecoration(
                labelText: 'Votre message',
                alignLabelWithHint: true,
                hintText: 'Expliquez ce qui se passe…'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _photos)
                InputChip(
                  avatar: const Icon(Icons.image_rounded, size: 18),
                  label: const Text('Photo jointe'),
                  onDeleted: () => setState(() => _photos.remove(p)),
                ),
              if (_photos.length < 4)
                ActionChip(
                  avatar: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: const Text('Ajouter une photo'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final url = await _pickPhoto(context);
                          if (url != null && mounted) {
                            setState(() => _photos.add(url));
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('ticket-send'),
            style: FilledButton.styleFrom(
                backgroundColor: _red,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Envoyer au support'),
          ),
        ],
      ),
    );
  }
}

// ── Fil d'une demande ────────────────────────────────────────────────────

class KitungaTicketPage extends StatefulWidget {
  const KitungaTicketPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<KitungaTicketPage> createState() => _KitungaTicketPageState();
}

class _KitungaTicketPageState extends State<KitungaTicketPage> {
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = const [];
  final _reply = TextEditingController();
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    if (supportBackendOverride == null) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r =
          await _call('kitungaTicketThread', {'ticketId': widget.ticketId});
      if (!mounted) return;
      setState(() {
        _ticket = Map<String, dynamic>.from(r['ticket'] as Map);
        _messages = _list(r['messages']);
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _call('kitungaTicketReply',
          {'ticketId': widget.ticketId, 'text': _reply.text.trim()});
      _reply.clear();
      await _load();
    } on ServerPaymentException catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {
      if (mounted) _snack(context, 'Réponse non envoyée.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final t = _ticket;
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text(t == null ? 'Demande' : 'Demande ${t['number']}',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
        actions: [
          if (t != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: _StatusChip(status: '${t['status']}')),
            ),
        ],
      ),
      body: t == null
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      Text('${t['subject']}',
                          style: GoogleFonts.interTight(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.primaryText)),
                      Text(
                          [
                            '${t['categoryLabel'] ?? ''}',
                            if ('${t['orderRef'] ?? ''}'.isNotEmpty)
                              'Commande ${t['orderRef']}',
                          ].join(' · '),
                          style: GoogleFonts.inter(
                              fontSize: 13, color: theme.secondaryText)),
                      const SizedBox(height: 14),
                      for (final m in _messages) _TicketBubble(m: m),
                      if (t['status'] == 'resolved')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                              'Demande résolue. Répondez si le problème '
                              'persiste : elle sera rouverte.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: theme.secondaryText)),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    color: theme.secondaryBackground,
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('ticket-reply'),
                            controller: _reply,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Votre réponse…',
                              isDense: true,
                              filled: true,
                              fillColor: theme.primaryBackground,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: _red),
                          onPressed: _busy ? null : _send,
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TicketBubble extends StatelessWidget {
  const _TicketBubble({required this.m});

  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final mine = m['mine'] == true;
    final photos = (m['photos'] as List? ?? const []).cast<dynamic>();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? _red : theme.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: theme.alternate),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                  m['fromRole'] == 'system'
                      ? 'Kitunga'
                      : '${m['fromName'] ?? 'Support Kitunga'}',
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _red)),
            Text('${m['text'] ?? ''}',
                style: GoogleFonts.inter(
                    fontSize: 14.5,
                    color: mine ? Colors.white : theme.primaryText)),
            for (final p in photos)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network('$p',
                      height: 140,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy:
                          WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined)),
                ),
              ),
            Text(_date(m['at'] as String?),
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
