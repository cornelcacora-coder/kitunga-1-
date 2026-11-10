import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/upload_data.dart';

/// Retours et échanges (boutiques et magasins) : demande du client dans les
/// 7 jours après la livraison, décision du commerce
/// (firebase/functions/kitunga/returns.js).

/// Tests : remplace le serveur.
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    returnsBackendOverride;

/// Tests : remplace la photo (renvoie l'adresse envoyée).
Future<String?> Function()? returnsPhotoOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    returnsBackendOverride != null
        ? returnsBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const kReturnDays = 7;
const kReturnCategories = ['Boutique', 'Magasin'];
const kReturnReasons = {
  'size': 'Taille ou pointure qui ne convient pas',
  'defect': 'Article abîmé ou défectueux',
  'not_as_described': 'Différent de la description',
  'wrong_item': 'Mauvais article reçu',
  'other': 'Autre raison',
};

String _wishLabel(String? w) =>
    w == 'refund' ? 'Remboursement' : 'Échange';

/// Retour encore possible pour cette commande (hors catégorie du commerce).
bool kitungaReturnOpen(OrdersRecord order, [DateTime? now]) {
  if (!['Livrer', 'Reçu'].contains(order.status)) return false;
  if ('${order.snapshotData['return_status'] ?? ''}'.isNotEmpty) return false;
  final at = order.snapshotData['delivered_at'] as DateTime?;
  if (at == null) return true;
  return (now ?? DateTime.now()).difference(at) <=
      const Duration(days: kReturnDays);
}

/// Client : demande de retour ou suivi de la demande, sur sa commande.
class KitungaReturnSection extends StatelessWidget {
  const KitungaReturnSection(
      {super.key, required this.order, this.sellerCategory});

  final OrdersRecord order;

  /// Catégorie du commerce (lue si absente).
  final String? sellerCategory;

  @override
  Widget build(BuildContext context) {
    if (order.userRef != currentUserReference &&
        returnsBackendOverride == null) {
      return const SizedBox.shrink();
    }
    final status = '${order.snapshotData['return_status'] ?? ''}';
    if (status.isNotEmpty) return _ReturnStatus(order: order);
    if (!kitungaReturnOpen(order)) return const SizedBox.shrink();
    if (sellerCategory != null) {
      return kReturnCategories.contains(sellerCategory)
          ? _ReturnButton(order: order)
          : const SizedBox.shrink();
    }
    final ref = order.sellerRef;
    if (ref == null) return const SizedBox.shrink();
    return StreamBuilder<UserRecord>(
      stream: UserRecord.getDocument(ref),
      builder: (context, snap) =>
          kReturnCategories.contains(snap.data?.category)
              ? _ReturnButton(order: order)
              : const SizedBox.shrink(),
    );
  }
}

class _ReturnButton extends StatelessWidget {
  const _ReturnButton({required this.order});

  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.primaryText,
          minimumSize: const Size.fromHeight(46.0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.0)),
        ),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: theme.secondaryBackground,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
          builder: (_) => Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: _ReturnSheet(order: order),
          ),
        ),
        icon: const Icon(Icons.assignment_return_outlined),
        label: const Text('Retourner ou échanger un article'),
      ),
    );
  }
}

class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({required this.order});

  final OrdersRecord order;

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  String? _reason;
  String _wish = 'exchange';
  final _note = TextEditingController();
  final List<String> _photos = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    setState(() => _busy = true);
    try {
      String? url;
      if (returnsPhotoOverride != null) {
        url = await returnsPhotoOverride!();
      } else {
        final media = await selectMediaWithSourceBottomSheet(
          context: context,
          maxWidth: 1400.0,
          maxHeight: 1400.0,
          imageQuality: 85,
          allowPhoto: true,
        );
        if (media != null &&
            media.isNotEmpty &&
            mounted &&
            validateFileFormat(media.first.storagePath, context)) {
          url = await uploadData(media.first.storagePath, media.first.bytes);
        }
      }
      if (url != null) setState(() => _photos.add(url!));
    } catch (_) {
      setState(() => _error = 'La photo n\'a pas pu être envoyée.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_reason == null) {
      return setState(() => _error = 'Choisissez le motif du retour.');
    }
    if (_reason == 'other' && _note.text.trim().isEmpty) {
      return setState(() => _error = 'Expliquez la raison du retour.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _call('kitungaRequestReturn', {
        'orderId': widget.order.reference.id,
        'reason': _reason,
        'wish': _wish,
        'note': _note.text.trim(),
        'photos': _photos,
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
          content: Text('Demande envoyée au commerce. Vous serez fixé dans '
              'le suivi de la commande.')));
    } on ServerPaymentException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final body = GoogleFonts.inter(color: theme.secondaryText, fontSize: 13.5);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 18.0, 20.0, 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Retour ou échange',
                style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 19.0,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4.0),
            Text(
                'Possible pendant $kReturnDays jours après la livraison. '
                'L\'article doit être rendu dans son état d\'origine.',
                style: body),
            const SizedBox(height: 12.0),
            for (final e in kReturnReasons.entries)
              InkWell(
                onTap: _busy ? null : () => setState(() => _reason = e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Icon(
                        _reason == e.key
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: _reason == e.key
                            ? theme.primary
                            : theme.secondaryText,
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                          child: Text(e.value,
                              style: GoogleFonts.inter(
                                  color: theme.primaryText, fontSize: 14.5))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10.0),
            Text('Vous souhaitez', style: body),
            const SizedBox(height: 6.0),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'exchange',
                    icon: Icon(Icons.swap_horiz_rounded),
                    label: Text('Un échange')),
                ButtonSegment(
                    value: 'refund',
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Un remboursement')),
              ],
              selected: {_wish},
              onSelectionChanged:
                  _busy ? null : (v) => setState(() => _wish = v.first),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Précisions',
                hintText: 'Ex. je voudrais la taille M à la place du S',
              ),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Chip(
                    avatar: const Icon(Icons.image_outlined, size: 18.0),
                    label: Text('Photo ${i + 1}'),
                    onDeleted: () => setState(() => _photos.removeAt(i)),
                  ),
                if (_photos.length < 4)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Photo de l\'article (facultatif)'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(_error!,
                    style: GoogleFonts.inter(
                        color: theme.error, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 14.0),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                minimumSize: const Size.fromHeight(48.0),
              ),
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Suivi de la demande (client).
class _ReturnStatus extends StatelessWidget {
  const _ReturnStatus({required this.order});

  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final d = order.snapshotData;
    final status = '${d['return_status']}';
    final wish = _wishLabel('${d['return_wish']}');
    final (color, text) = switch (status) {
      'requested' => (
          const Color(0xFF7C4DFF),
          'Demande de retour envoyée ($wish). Le commerce vous répond bientôt.'
        ),
      'accepted' => (
          const Color(0xFF1E9E5A),
          d['return_wish'] == 'refund'
              ? 'Retour accepté : rendez l\'article au commerce. Kitunga vous '
                  'rembourse ensuite par Mobile Money.'
              : 'Échange accepté : le commerce vous contacte pour l\'échange.'
        ),
      _ => (
          theme.error,
          'Retour refusé : ${d['return_decision_note'] ?? ''}'
        ),
    };
    return Container(
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment_return_outlined, color: color),
          const SizedBox(width: 10.0),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      color: theme.primaryText, fontSize: 13.5))),
        ],
      ),
    );
  }
}

/// Commerce : demande de retour à traiter (ou décision prise).
class KitungaSellerReturnCard extends StatelessWidget {
  const KitungaSellerReturnCard({super.key, required this.order});

  final OrdersRecord order;

  static bool showsFor(OrdersRecord order) =>
      '${order.snapshotData['return_status'] ?? ''}'.isNotEmpty;

  Future<void> _decide(BuildContext context, bool accept) async {
    String? note;
    if (!accept) {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Refuser le retour'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 300,
            decoration: const InputDecoration(
                labelText: 'Motif (envoyé au client)',
                hintText: 'Ex. article porté, délai dépassé…'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Refuser')),
          ],
        ),
      );
      if (note == null || note.isEmpty) return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _call('kitungaDecideReturn', {
        'orderId': order.reference.id,
        'decision': accept ? 'accept' : 'refuse',
        if (note != null) 'note': note,
      });
      messenger.showSnackBar(SnackBar(
          content: Text(accept ? 'Retour accepté.' : 'Retour refusé.')));
    } on ServerPaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Connexion impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final d = order.snapshotData;
    final status = '${d['return_status']}';
    final photos = [for (final p in (d['return_photos'] as List? ?? const [])) '$p'];
    final small = GoogleFonts.inter(color: theme.primaryText, fontSize: 13.0);
    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              status == 'requested'
                  ? 'Demande de retour · ${_wishLabel('${d['return_wish']}')}'
                  : status == 'accepted'
                      ? 'Retour accepté (${_wishLabel('${d['return_wish']}')})'
                      : 'Retour refusé',
              style: GoogleFonts.inter(
                  color: theme.primaryText,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4.0),
          Text('Motif : ${kReturnReasons[d['return_reason']] ?? ''}',
              style: small),
          if ('${d['return_note'] ?? ''}'.isNotEmpty)
            Text('« ${d['return_note']} »',
                style: small.copyWith(fontStyle: FontStyle.italic)),
          if (photos.isNotEmpty)
            Wrap(
              spacing: 6.0,
              children: [
                for (var i = 0; i < photos.length; i++)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => Scaffold(
                                  backgroundColor: Colors.black,
                                  appBar: AppBar(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white),
                                  body: InteractiveViewer(
                                      child: Center(
                                          child: Image.network(photos[i]))),
                                ))),
                    icon: const Icon(Icons.image_outlined, size: 18.0),
                    label: Text('Photo ${i + 1}'),
                  ),
              ],
            ),
          if (status == 'requested') ...[
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E9E5A)),
                    onPressed: () => _decide(context, true),
                    child: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.error),
                    onPressed: () => _decide(context, false),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
            if (d['return_wish'] == 'refund')
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                    'Accepté : le client rend l\'article, Kitunga le '
                    'rembourse (articles, sans la livraison).',
                    style: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 12.0)),
              ),
          ],
        ],
      ),
    );
  }
}
