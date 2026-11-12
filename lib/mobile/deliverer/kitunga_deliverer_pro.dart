import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/upload_data.dart';
import '/mobile/components/finance/kitunga_earnings.dart'
    show fcfaOf, openKitungaEarnings;
import '/mobile/components/support/kitunga_support.dart'
    show openKitungaSupport;

/// Espace professionnel du livreur : documents et vérification,
/// performances, sécurité (alerte, contact d'urgence), et la rubrique
/// « Mon activité » qui les regroupe.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    proBackendOverride;

/// Remplace la photo d'un document dans les tests.
@visibleForTesting
Future<String?> Function()? proPhotoOverride;

Future<Map<String, dynamic>> proCall(String name, Map<String, dynamic> data) =>
    proBackendOverride != null
        ? proBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const _red = Color(0xFFE51A1A);
const _redDark = Color(0xFFB0101A);
const _green = Color(0xFF17A35B);
const _orange = Color(0xFFE08A00);

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

Future<void> _guard(BuildContext context, Future<void> Function() action,
    String done) async {
  try {
    await action();
    if (context.mounted) _snack(context, done);
  } on ServerPaymentException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, 'Connexion impossible. Réessayez.');
  }
}

PreferredSizeWidget _bar(BuildContext context, String title) {
  final theme = FlutterFlowTheme.of(context);
  return AppBar(
    backgroundColor: theme.secondaryBackground,
    foregroundColor: theme.primaryText,
    elevation: 0,
    title: Text(title,
        style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
  );
}

/// État de vérification : libellé, couleur, explication.
const kVerification = {
  'verified': ('Compte vérifié', _green,
      'Vos documents sont validés par Kitunga.'),
  'pending': ('Vérification en cours', _orange,
      'Kitunga vérifie vos documents. Vous serez prévenu.'),
  'missing': ('Documents à compléter', _red,
      'Déposez vos documents obligatoires pour être vérifié.'),
  'rejected': ('Document refusé', _red,
      'Un document a été refusé : déposez-en un nouveau.'),
  'expired': ('Document expiré', _red,
      'Un document a expiré : renouvelez-le.'),
};

const _docStatus = {
  'approved': ('Validé', _green),
  'pending': ('En vérification', _orange),
  'rejected': ('Refusé', _red),
  'expired': ('Expiré', _red),
  'missing': ('À déposer', Color(0xFF8A94A6)),
};

// ── Documents ────────────────────────────────────────────────────────────

class DelivererDocumentsPage extends StatefulWidget {
  const DelivererDocumentsPage({super.key});

  @override
  State<DelivererDocumentsPage> createState() => _DelivererDocumentsState();
}

class _DelivererDocumentsState extends State<DelivererDocumentsPage> {
  late Future<Map<String, dynamic>> _data = proCall('kitungaMyDocuments', {});

  void _reload() {
    setState(() {
      _data = proCall('kitungaMyDocuments', {});
    });
  }

  Future<void> _submit(Map<String, dynamic> d) async {
    final number = TextEditingController(text: '${d['number'] ?? ''}');
    DateTime? expires;
    String? photo;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${d['label']}',
                  style: GoogleFonts.interTight(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('doc-photo'),
                onPressed: () async {
                  final url = await _photo(c);
                  if (url != null) set(() => photo = url);
                },
                icon: Icon(photo == null
                    ? Icons.add_a_photo_rounded
                    : Icons.check_circle_rounded),
                label: Text(photo == null
                    ? 'Photographier le document'
                    : 'Photo prête (changer)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: number,
                decoration: const InputDecoration(
                    labelText: 'Numéro du document (facultatif)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final p = await showDatePicker(
                      context: c,
                      firstDate: now,
                      lastDate: DateTime(now.year + 20),
                      initialDate: now.add(const Duration(days: 365)));
                  if (p != null) set(() => expires = p);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text(expires == null
                    ? 'Date d\'expiration (si indiquée)'
                    : 'Expire le ${DateFormat('d MMM yyyy', 'fr').format(expires!)}'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('doc-send'),
                style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _red,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: photo == null ? null : () => Navigator.pop(c, true),
                child: const Text('Envoyer pour vérification'),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || photo == null || !mounted) return;
    await _guard(
        context,
        () => proCall('kitungaSubmitDocument', {
              'type': d['type'],
              'photoUrl': photo,
              'number': number.text.trim(),
              if (expires != null) 'expiresAt': expires!.toIso8601String(),
            }),
        'Document envoyé : Kitunga le vérifie.');
    _reload();
  }

  Future<String?> _photo(BuildContext c) async {
    if (proPhotoOverride != null) return proPhotoOverride!();
    final media = await selectMediaWithSourceBottomSheet(
        context: c,
        maxWidth: 1800.0,
        maxHeight: 1800.0,
        imageQuality: 85,
        allowPhoto: true);
    if (media == null || media.isEmpty || !c.mounted) return null;
    if (!validateFileFormat(media.first.storagePath, c)) return null;
    final ext = media.first.storagePath.split('.').last.toLowerCase();
    // Dossier privé : seul le livreur et l'admin (par le serveur) y ont accès.
    return uploadData(
        'documents/$currentUserUid/'
        '${DateTime.now().microsecondsSinceEpoch}.$ext',
        media.first.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: _bar(context, 'Mes documents'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: TextButton(
                    onPressed: _reload,
                    child: const Text('Connexion impossible. Réessayer')));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _red));
          }
          final v = kVerification['${snap.data!['verification']}'] ??
              kVerification['missing']!;
          final docs = (snap.data!['documents'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: v.$2.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: v.$2.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(
                        snap.data!['verification'] == 'verified'
                            ? Icons.verified_rounded
                            : Icons.info_outline_rounded,
                        color: v.$2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.$1,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  color: theme.primaryText)),
                          Text(v.$3,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: theme.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final d in docs)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.alternate),
                  ),
                  child: ListTile(
                    title: Text(
                        '${d['label']}${d['required'] == true ? '' : ' (facultatif)'}',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText)),
                    subtitle: Text(
                        [
                          (_docStatus[d['status']] ?? _docStatus['missing']!)
                              .$1,
                          if (d['expiresAt'] != null)
                            'expire le ${DateFormat('d/M/yyyy').format(DateTime.parse('${d['expiresAt']}').toLocal())}',
                          if ('${d['rejectReason']}'.isNotEmpty)
                            'motif : ${d['rejectReason']}',
                        ].join(' · '),
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: (_docStatus[d['status']] ??
                                    _docStatus['missing']!)
                                .$2)),
                    trailing: TextButton(
                      key: ValueKey('doc-${d['type']}'),
                      onPressed: () => _submit(d),
                      child: Text(d['status'] == 'missing'
                          ? 'Déposer'
                          : d['status'] == 'approved'
                              ? 'Renouveler'
                              : 'Remplacer'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Performances ─────────────────────────────────────────────────────────

class DelivererPerformancePage extends StatefulWidget {
  const DelivererPerformancePage({super.key});

  @override
  State<DelivererPerformancePage> createState() => _PerformanceState();
}

class _PerformanceState extends State<DelivererPerformancePage> {
  late final Future<Map<String, dynamic>> _data =
      proCall('kitungaMyPerformance', {});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    String pct(dynamic v) => v == null ? '—' : '$v %';
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: _bar(context, 'Mes performances'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Connexion impossible.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _red));
          }
          final d = snap.data!;
          final weeks = (d['weeklyEarnings'] as List? ?? const [])
              .map((e) => (e as num).toDouble())
              .toList();
          final max = weeks.fold<double>(1, (m, v) => v > m ? v : m);
          Widget kpi(String label, String value, IconData icon, Color c) =>
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.alternate),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 18,
                        backgroundColor: c.withValues(alpha: 0.12),
                        child: Icon(icon, color: c, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value,
                              style: GoogleFonts.interTight(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: theme.primaryText)),
                          Text(label,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: theme.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          final rating = d['rating'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_red, _redDark]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFC21A), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rating == null ? 'Pas encore de note' : '$rating / 5',
                              style: GoogleFonts.interTight(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          Text('${d['ratingCount'] ?? 0} avis de clients',
                              style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  kpi('Livraisons réussies', '${d['delivered'] ?? 0}',
                      Icons.task_alt_rounded, _green),
                  kpi('Taux de réussite', pct(d['successRate']),
                      Icons.verified_rounded, _green),
                  kpi('Propositions acceptées', pct(d['acceptanceRate']),
                      Icons.thumb_up_alt_rounded, const Color(0xFF2563EB)),
                  kpi(
                      'Temps moyen',
                      d['averageMinutes'] == null
                          ? '—'
                          : '${d['averageMinutes']} min',
                      Icons.timer_rounded,
                      _orange),
                  kpi('Distance', '${d['distanceKm'] ?? 0} km',
                      Icons.route_rounded, const Color(0xFF7C3AED)),
                  kpi('Gains du mois', fcfaOf(d['monthEarnings'] as num? ?? 0),
                      Icons.payments_rounded, _red),
                ],
              ),
              const SizedBox(height: 18),
              Text('Gains des 8 dernières semaines',
                  style: GoogleFonts.interTight(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              const SizedBox(height: 10),
              Container(
                height: 170,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.alternate),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < weeks.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                  weeks[i] == 0
                                      ? ''
                                      : NumberFormat.compact(locale: 'fr')
                                          .format(weeks[i]),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: theme.secondaryText)),
                              const SizedBox(height: 2),
                              Container(
                                height: 100 * weeks[i] / max + 2,
                                decoration: BoxDecoration(
                                  color: i == weeks.length - 1
                                      ? _red
                                      : _red.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(i == weeks.length - 1 ? 'Cette' : 'S-${weeks.length - 1 - i}',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: theme.secondaryText)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                  'Le taux de réussite compte les courses livrées et celles '
                  'non reçues ou échouées. Les annulations du client, du '
                  'commerce ou de l\'admin (${d['cancelledByOthers'] ?? 0}) '
                  'ne vous sont pas imputées.',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: theme.secondaryText)),
            ],
          );
        },
      ),
    );
  }
}

// ── Sécurité ─────────────────────────────────────────────────────────────

const kSafetyKinds = {
  'accident': ('Accident', Icons.car_crash_rounded),
  'danger': ('Situation dangereuse', Icons.warning_rounded),
  'health': ('Malaise / santé', Icons.health_and_safety_rounded),
  'other': ('Autre urgence', Icons.sos_rounded),
};

/// Envoie une alerte (après confirmation) ; « envoyée » seulement quand le
/// serveur a répondu.
Future<void> sendSafetyAlert(BuildContext context,
    {String kind = 'other', String? orderId}) async {
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.sos_rounded, color: _red, size: 40),
      title: Text('Alerte : ${kSafetyKinds[kind]!.$1}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'L\'équipe Kitunga (admins et support) sera prévenue tout de '
              'suite avec votre position. En danger immédiat, appelez aussi '
              'les secours.'),
          const SizedBox(height: 10),
          TextField(
              controller: note,
              decoration:
                  const InputDecoration(labelText: 'Précisions (facultatif)')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler')),
        FilledButton(
          key: const ValueKey('sos-confirm'),
          style: FilledButton.styleFrom(foregroundColor: Colors.white,backgroundColor: _red),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Envoyer l\'alerte'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  double? lat;
  double? lng;
  if (proBackendOverride == null) {
    try {
      final p = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      lat = p.latitude;
      lng = p.longitude;
    } catch (_) {
      // Sans position : l'alerte part quand même.
    }
  }
  if (!context.mounted) return;
  await _guard(
      context,
      () => proCall('kitungaSafetyAlert', {
            'kind': kind,
            'note': note.text.trim(),
            if (orderId != null) 'orderId': orderId,
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          }),
      'Alerte envoyée : l\'équipe Kitunga est prévenue.');
}

class DelivererSafetyPage extends StatefulWidget {
  const DelivererSafetyPage({super.key});

  @override
  State<DelivererSafetyPage> createState() => _SafetyState();
}

class _SafetyState extends State<DelivererSafetyPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = currentUserDocument?.snapshotData['emergency_contact'];
    if (c is Map) {
      _name.text = '${c['name'] ?? ''}';
      _phone.text = '${c['phone'] ?? ''}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: _bar(context, 'Sécurité'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Alerte d\'urgence',
              style: GoogleFonts.interTight(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText)),
          const SizedBox(height: 4),
          Text(
              'Prévient immédiatement les admins et le support, avec votre '
              'position et votre contact d\'urgence. Un ticket urgent est '
              'ouvert.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: theme.secondaryText)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              for (final e in kSafetyKinds.entries)
                Material(
                  color: _red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: ValueKey('sos-${e.key}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => sendSafetyAlert(context, kind: e.key),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(e.value.$2, color: _red, size: 30),
                        const SizedBox(height: 6),
                        Text(e.value.$1,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Contact d\'urgence',
              style: GoogleFonts.interTight(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText)),
          const SizedBox(height: 8),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 8),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone')),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _red, minimumSize: const Size.fromHeight(46)),
            onPressed: () => _guard(
                context,
                () => proCall('kitungaSetEmergencyContact',
                    {'name': _name.text.trim(), 'phone': _phone.text.trim()}),
                'Contact d\'urgence enregistré.'),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// ── Mon activité (rubrique du profil et du menu) ────────────────────────

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// Liens vers tout l'espace professionnel du livreur.
class DelivererActivitySection extends StatelessWidget {
  const DelivererActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final items = [
      (Icons.badge_outlined, 'Mes documents',
          () => _push(context, const DelivererDocumentsPage())),
      (Icons.insights_rounded, 'Mes performances',
          () => _push(context, const DelivererPerformancePage())),
      (Icons.account_balance_wallet_outlined, 'Mes gains et retraits',
          () => openKitungaEarnings(context)),
      (Icons.health_and_safety_outlined, 'Sécurité et urgence',
          () => _push(context, const DelivererSafetyPage())),
      (Icons.support_agent_outlined, 'Aide & support',
          () => openKitungaSupport(context)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Mon activité de livreur',
                style: GoogleFonts.inter(
                    color: theme.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 60, color: theme.alternate),
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(items[i].$1, color: _red, size: 21),
                    ),
                    title: Text(items[i].$2,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText)),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: theme.secondaryText),
                    onTap: items[i].$3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
