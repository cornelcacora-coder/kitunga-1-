import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_kit.dart';

/// Vérification des documents des livreurs (admin) : photo, numéro,
/// expiration ; valider ou refuser avec un motif.
Future<void> showAdminDocuments(BuildContext context,
        {String? uid, String? name}) =>
    showDialog(
        context: context,
        builder: (_) => _DocumentsDialog(uid: uid, name: name));

const _status = {
  'pending': ('À vérifier', AdminColors.orange),
  'approved': ('Validé', AdminColors.green),
  'rejected': ('Refusé', AdminColors.red),
  'expired': ('Expiré', AdminColors.red),
};

class _DocumentsDialog extends StatefulWidget {
  const _DocumentsDialog({this.uid, this.name});

  final String? uid;
  final String? name;

  @override
  State<_DocumentsDialog> createState() => _DocumentsDialogState();
}

class _DocumentsDialogState extends State<_DocumentsDialog> {
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() => salesCall('kitungaAdminDocuments',
      {if (widget.uid != null) 'uid': widget.uid});

  Future<void> _review(Map<String, dynamic> d, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await askText(context, 'Refuser : ${d['label']}',
          label: 'Motif (le livreur le verra)');
      if (reason == null || reason.trim().isEmpty) return;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaAdminReviewDocument', {
              'id': d['id'],
              'approve': approve,
              if (reason != null) 'reason': reason.trim(),
            }),
        approve ? 'Document validé.' : 'Document refusé : le livreur est '
            'prévenu.');
    if (ok) {
      setState(() {
        _data = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name == null
          ? 'Documents à vérifier'
          : 'Documents · ${widget.name}'),
      content: SizedBox(
        width: 620,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Lecture impossible.', style: salesBody());
            }
            if (!snap.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }
            final docs = listOf(snap.data!['documents']);
            if (docs.isEmpty) {
              return Text(
                  widget.uid == null
                      ? 'Aucun document en attente.'
                      : 'Aucun document déposé.',
                  style: salesBody());
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final d in docs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network('${d['photoUrl']}',
                              width: 150,
                              height: 100,
                              fit: BoxFit.cover,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.fallback,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 150,
                                  height: 100,
                                  child: Icon(Icons.broken_image_outlined))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${d['label']} · ${d['name']}',
                                  style: salesTitle(14)),
                              Text(
                                  [
                                    (_status[d['status']]?.$1 ??
                                        '${d['status']}'),
                                    if ('${d['number']}'.isNotEmpty)
                                      'n° ${d['number']}',
                                    if (d['expiresAt'] != null)
                                      'expire le ${dateFr(d['expiresAt'] as String?)}',
                                    if ('${d['rejectReason']}'.isNotEmpty)
                                      'motif : ${d['rejectReason']}',
                                  ].join(' · '),
                                  style: salesBody(size: 12.5).copyWith(
                                      color: _status[d['status']]?.$2)),
                              TextButton(
                                onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                        child: InteractiveViewer(
                                            child: Image.network(
                                                '${d['photoUrl']}',
                                                webHtmlElementStrategy:
                                                    WebHtmlElementStrategy
                                                        .fallback)))),
                                child: const Text('Agrandir'),
                              ),
                              if (d['status'] == 'pending')
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: AdminColors.green),
                                      onPressed: () => _review(d, true),
                                      child: const Text('Valider'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _review(d, false),
                                      child: const Text('Refuser'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer')),
      ],
    );
  }
}
