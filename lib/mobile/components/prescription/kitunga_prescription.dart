import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart' show currentUserUid;
import '/backend/firebase_storage/storage.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';

/// Ordonnances : le client envoie la photo de son ordonnance à la pharmacie,
/// qui la valide (7 jours, une commande) ou la refuse ; le serveur vérifie
/// au paiement (firebase/functions/kitunga/prescriptions.js).

/// Tests : remplace le serveur.
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    prescriptionBackendOverride;

/// Tests : remplace la prise de photo (renvoie l'adresse envoyée).
Future<String?> Function()? prescriptionPhotoOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    prescriptionBackendOverride != null
        ? prescriptionBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

List<Map<String, dynamic>> _list(Map<String, dynamic> r) => [
      for (final p in (r['prescriptions'] as List? ?? const []))
        Map<String, dynamic>.from(p as Map),
    ];

String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : dateTimeFormat('d MMM y', d);
}

/// Photo prise ou choisie, envoyée dans le dossier privé du client.
Future<String?> _takePrescriptionPhoto(BuildContext context) async {
  if (prescriptionPhotoOverride != null) return prescriptionPhotoOverride!();
  final media = await selectMediaWithSourceBottomSheet(
    context: context,
    maxWidth: 1800.0,
    maxHeight: 1800.0,
    imageQuality: 85,
    allowPhoto: true,
  );
  if (media == null || media.isEmpty || !context.mounted) return null;
  if (!validateFileFormat(media.first.storagePath, context)) return null;
  final ext = media.first.storagePath.split('.').last.toLowerCase();
  return uploadData(
      'prescriptions/$currentUserUid/'
      '${DateTime.now().microsecondsSinceEpoch}.$ext',
      media.first.bytes);
}

/// Avant d'ajouter un médicament sur ordonnance au panier : true si une
/// ordonnance validée est disponible chez cette pharmacie ; sinon, propose
/// de l'envoyer (ou indique qu'elle est en cours de vérification).
Future<bool> kitungaPrescriptionGate(BuildContext context,
    {required String sellerUid, required String sellerName}) async {
  List<Map<String, dynamic>> mine;
  try {
    mine = _list(await _call('kitungaMyPrescriptions', {'sellerUid': sellerUid}));
  } on ServerPaymentException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion impossible. Réessayez.')));
    }
    return false;
  }
  if (mine.any((p) => p['status'] == 'approved')) return true;
  if (!context.mounted) return false;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
    builder: (_) => Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: _PrescriptionSheet(
          sellerUid: sellerUid, sellerName: sellerName, mine: mine),
    ),
  );
  return false;
}

class _PrescriptionSheet extends StatefulWidget {
  const _PrescriptionSheet(
      {required this.sellerUid, required this.sellerName, required this.mine});

  final String sellerUid;
  final String sellerName;
  final List<Map<String, dynamic>> mine;

  @override
  State<_PrescriptionSheet> createState() => _PrescriptionSheetState();
}

class _PrescriptionSheetState extends State<_PrescriptionSheet> {
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
      final url = await _takePrescriptionPhoto(context);
      if (url != null) setState(() => _photos.add(url));
    } catch (_) {
      setState(() => _error = 'La photo n\'a pas pu être envoyée. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_photos.isEmpty) {
      return setState(() => _error = 'Ajoutez la photo de votre ordonnance.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _call('kitungaSubmitPrescription', {
        'sellerUid': widget.sellerUid,
        'photos': _photos,
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('Ordonnance envoyée à ${widget.sellerName}. Vous '
              'pourrez commander dès qu\'elle sera validée.')));
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
    final pending =
        widget.mine.where((p) => p['status'] == 'pending').toList();
    final last = widget.mine.isEmpty ? null : widget.mine.first;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 18.0, 20.0, 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.medical_information_outlined, color: theme.primary),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text('Médicament sur ordonnance',
                      style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 19.0,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (pending.isNotEmpty)
              _notice(
                  theme,
                  Icons.hourglass_top_rounded,
                  const Color(0xFF7C4DFF),
                  'Votre ordonnance est en cours de vérification par '
                  '${widget.sellerName}. Vous pourrez commander dès qu\'elle '
                  'sera validée.')
            else if (last != null && last['status'] == 'rejected')
              _notice(theme, Icons.error_outline_rounded, theme.error,
                  'Ordonnance refusée : ${last['reviewNote']}. Vous pouvez en '
                  'envoyer une nouvelle.')
            else if (last != null && last['status'] == 'expired')
              _notice(theme, Icons.event_busy_rounded, theme.error,
                  'Votre ordonnance validée a expiré. Envoyez-la de nouveau.'),
            if (pending.isEmpty) ...[
              Text(
                  'Envoyez une photo lisible de votre ordonnance à '
                  '${widget.sellerName}. Le pharmacien la vérifie, puis vous '
                  'pourrez commander pendant 7 jours. Votre photo n\'est '
                  'visible que par cette pharmacie.',
                  style: body),
              const SizedBox(height: 14.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Chip(
                      avatar: const Icon(Icons.description_outlined, size: 18.0),
                      label: Text('Photo ${i + 1}'),
                      onDeleted: _busy
                          ? null
                          : () => setState(() => _photos.removeAt(i)),
                    ),
                  if (_photos.length < 4)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _addPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_photos.isEmpty
                          ? 'Photographier l\'ordonnance'
                          : 'Ajouter une page'),
                    ),
                ],
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message au pharmacien (facultatif)',
                  hintText: 'Ex. pour mon enfant de 6 ans',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_error!,
                      style: GoogleFonts.inter(
                          color: theme.error, fontWeight: FontWeight.w600)),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  minimumSize: const Size.fromHeight(48.0),
                ),
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.0, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer à la pharmacie'),
              ),
            ] else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Compris'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notice(
          FlutterFlowTheme theme, IconData icon, Color color, String text) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10.0),
            Expanded(
                child: Text(text,
                    style: GoogleFonts.inter(
                        color: theme.primaryText, fontSize: 13.5))),
          ],
        ),
      );
}

/// Pages d'une ordonnance en plein écran (zoom).
void showPrescriptionPhotos(BuildContext context, List<String> photos) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Ordonnance')),
      body: PageView(
        children: [
          for (final url in photos)
            InteractiveViewer(
              maxScale: 6.0,
              child: Center(child: Image.network(url)),
            ),
        ],
      ),
    ),
  ));
}

// ── Pharmacie : ordonnances à vérifier ──────────────────────────────────

class SellerPrescriptionsPage extends StatefulWidget {
  const SellerPrescriptionsPage({super.key});

  @override
  State<SellerPrescriptionsPage> createState() =>
      _SellerPrescriptionsPageState();
}

class _SellerPrescriptionsPageState extends State<SellerPrescriptionsPage> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      _list(await _call('kitungaSellerPrescriptions', {}));

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _review(Map<String, dynamic> p, bool approve) async {
    String? note;
    if (!approve) {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Refuser l\'ordonnance'),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 300,
            decoration: const InputDecoration(
                labelText: 'Motif (envoyé au client)',
                hintText: 'Ex. ordonnance illisible, date dépassée…'),
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
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _call('kitungaReviewPrescription', {
        'id': p['id'],
        'decision': approve ? 'approve' : 'reject',
        if (note != null) 'note': note,
      });
      messenger.showSnackBar(SnackBar(
          content: Text(approve
              ? 'Ordonnance validée : le client peut commander (7 jours).'
              : 'Ordonnance refusée.')));
      _reload();
    } on ServerPaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Connexion impossible. Réessayez.')));
    }
  }

  void _zoom(String url) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('Ordonnance')),
          body: InteractiveViewer(
            maxScale: 6.0,
            child: Center(child: Image.network(url)),
          ),
        ),
      ));

  static const _labels = {
    'pending': ('À vérifier', Color(0xFF7C4DFF)),
    'approved': ('Validée', Color(0xFF1E9E5A)),
    'rejected': ('Refusée', Color(0xFFD32F2F)),
    'used': ('Commandée', Color(0xFF1565C0)),
    'expired': ('Expirée', Color(0xFF6F737C)),
  };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final small = GoogleFonts.inter(color: theme.secondaryText, fontSize: 13.0);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text('Ordonnances',
            style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 19.0,
                fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          if (snap.hasError) {
            return Center(
                child: TextButton(
                    onPressed: _reload, child: Text('${snap.error}')));
          }
          final list = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 32.0),
              children: [
                Text(
                    'Vérifiez chaque ordonnance avant que le client puisse '
                    'commander ses médicaments. Une ordonnance validée sert '
                    'pour une seule commande, pendant 7 jours.',
                    style: small),
                const SizedBox(height: 14.0),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: Text('Aucune ordonnance reçue.',
                        textAlign: TextAlign.center, style: small),
                  ),
                for (final p in list) ...[
                  _card(theme, small, p),
                  const SizedBox(height: 12.0),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(FlutterFlowTheme theme, TextStyle small, Map<String, dynamic> p) {
    final st = _labels[p['status']] ?? _labels['expired']!;
    final photos = [for (final x in (p['photos'] as List? ?? const [])) '$x'];
    final phone = '${p['clientPhone'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${p['clientName'] ?? ''}'.isEmpty
                        ? 'Client'
                        : '${p['clientName']}',
                    style: GoogleFonts.interTight(
                        color: theme.primaryText,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8.0),
              Flexible(
                child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                    color: st.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.0)),
                child: Text(st.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: st.$2,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700)),
              ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Text('Reçue le ${_day(p['createdAt'])}'
              '${p['status'] == 'approved' ? ' · valable jusqu\'au ${_day(p['expiresAt'])}' : ''}',
              style: small),
          if ('${p['note'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Text('« ${p['note']} »',
                style: small.copyWith(fontStyle: FontStyle.italic)),
          ],
          if ('${p['reviewNote'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Text('Motif du refus : ${p['reviewNote']}', style: small),
          ],
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              for (var i = 0; i < photos.length; i++)
                OutlinedButton.icon(
                  onPressed: () => _zoom(photos[i]),
                  icon: const Icon(Icons.zoom_in_rounded, size: 18.0),
                  label: Text('Voir la page ${i + 1}'),
                ),
              if (phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchURL('tel:$phone'),
                  icon: const Icon(Icons.call_rounded, size: 18.0),
                  label: const Text('Appeler le client'),
                ),
            ],
          ),
          if (p['status'] == 'pending') ...[
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E9E5A)),
                    onPressed: () => _review(p, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Valider'),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.error),
                    onPressed: () => _review(p, false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
