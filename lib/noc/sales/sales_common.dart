import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/server_payment.dart';

/// Éléments communs de l'interface admin du module commercial : appels au
/// serveur, libellés, dates (heure de Brazzaville) et composants visuels.

const kSalesRed = Color(0xFFE51A1A);
const kSalesDeepRed = Color(0xFF9E0E0E);
const kSalesInk = Color(0xFF17181C);
const kSalesMuted = Color(0xFF6B6F76);
const kSalesSurface = Color(0xFFF6F6F8);

// ── Serveur ──────────────────────────────────────────────────────────────

/// Remplace le serveur dans les tests d'interface (données fictives).
@visibleForTesting
Future<Map<String, dynamic>> Function(String function, Map<String, dynamic> data)?
    salesBackendOverride;

/// Lecture (fonction kitungaSalesAdminQuery, réservée à l'admin).
Future<Map<String, dynamic>> salesQuery(String view,
        [Map<String, dynamic> extra = const {}]) =>
    salesCall('kitungaSalesAdminQuery', {'view': view, ...extra});

/// Action (fonctions du module) ; le serveur revérifie tout.
Future<Map<String, dynamic>> salesCall(
        String function, Map<String, dynamic> data) =>
    salesBackendOverride != null
        ? salesBackendOverride!(function, data)
        : kitungaCallFunction(function, data);

List<Map<String, dynamic>> listOf(dynamic v) => (v as List? ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

// ── Formats ──────────────────────────────────────────────────────────────

String fcfa(num? v) =>
    '${NumberFormat.decimalPattern('fr').format(v ?? 0)} F';

/// Date ISO affichée à l'heure de Brazzaville (UTC+1).
String dateFr(String? iso, {bool withTime = false}) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  final local = d.toUtc().add(const Duration(hours: 1));
  return DateFormat(withTime ? 'd MMM yyyy, HH:mm' : 'd MMM yyyy', 'fr')
      .format(local);
}

/// Début du jour [day] à Brazzaville, en ISO (UTC).
String brazzavilleDayStart(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day)
        .subtract(const Duration(hours: 1))
        .toIso8601String();

/// Fin incluse du jour [day] à Brazzaville = début du lendemain.
String brazzavilleDayEnd(DateTime day) =>
    brazzavilleDayStart(DateTime(day.year, day.month, day.day + 1));

/// Jour (à Brazzaville) d'une date ISO, pour préremplir un sélecteur.
DateTime? brazzavilleDay(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return null;
  final local = d.toUtc().add(const Duration(hours: 1));
  return DateTime(local.year, local.month, local.day);
}

// ── Libellés ─────────────────────────────────────────────────────────────

typedef StatusStyle = ({String label, Color color});

const _grey = Color(0xFF8A8F98);
const _green = Color(0xFF1E9E5A);
const _blue = Color(0xFF2F6FDB);
const _orange = Color(0xFFE08A00);

const campaignStatus = <String, StatusStyle>{
  'draft': (label: 'Brouillon', color: _grey),
  'scheduled': (label: 'Programmée', color: _blue),
  'active': (label: 'Active', color: _green),
  'paused': (label: 'En pause', color: _orange),
  'completed': (label: 'Terminée', color: kSalesInk),
  'archived': (label: 'Archivée', color: _grey),
};

/// Mêmes transitions que le serveur (model.js).
const campaignTransitions = <String, List<String>>{
  'draft': ['scheduled', 'active', 'archived'],
  'scheduled': ['draft', 'active', 'paused', 'completed'],
  'active': ['paused', 'completed'],
  'paused': ['active', 'completed'],
  'completed': ['archived'],
  'archived': [],
};

const campaignActionLabel = <String, String>{
  'draft': 'Repasser en brouillon',
  'scheduled': 'Programmer',
  'active': 'Activer',
  'paused': 'Mettre en pause',
  'completed': 'Clôturer',
  'archived': 'Archiver',
};

const agentStatus = <String, StatusStyle>{
  'active': (label: 'Actif', color: _green),
  'suspended': (label: 'Suspendu', color: _orange),
  'archived': (label: 'Archivé', color: _grey),
};

const assignmentStatus = <String, StatusStyle>{
  'active': (label: 'En cours', color: _green),
  'ended': (label: 'Terminée', color: _grey),
  'cancelled': (label: 'Annulée', color: kSalesRed),
};

const commissionStatus = <String, StatusStyle>{
  'pending': (label: 'En attente', color: _orange),
  'approved': (label: 'Validée', color: _green),
  'reserved': (label: 'En versement', color: _blue),
  'paid': (label: 'Payée', color: Color(0xFF136B3D)),
  'rejected': (label: 'Rejetée', color: kSalesRed),
  'reversed': (label: 'Annulée', color: _grey),
};

const payoutStatus = <String, StatusStyle>{
  'requested': (label: 'Demandé', color: _orange),
  'approved': (label: 'Validé', color: _blue),
  'paid': (label: 'Payé', color: _green),
  'rejected': (label: 'Refusé', color: kSalesRed),
};

const commissionType = <String, String>{
  'activation': 'Activation',
  'first_subscription': 'Premier abonnement',
  'reversal': 'Contrepassation',
};

const commissionFlag = <String, String>{
  'shared_payer': 'Même numéro MTN pour plusieurs clients',
  'agent_not_active': 'Commercial suspendu ou archivé',
  'assignment_cancelled': 'Affectation annulée',
};

const planLabel = <String, String>{
  'monthly': 'Mensuel (250 F)',
  'quarterly': 'Trimestriel (500 F)',
  'annual': 'Annuel (1000 F)',
};

String payoutMethodLabel(Map? m) {
  if (m == null) return 'Aucun moyen de paiement';
  if (m['type'] == 'mobile_money') {
    return '${m['operator'] ?? 'MoMo'} Money · ${m['phone'] ?? ''}';
  }
  if (m['type'] == 'bank') {
    return '${m['bank_name'] ?? 'Banque'} · ${m['account_number'] ?? ''}';
  }
  return '—';
}

// ── Composants ───────────────────────────────────────────────────────────

class SalesCard extends StatelessWidget {
  const SalesCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.0),
      elevation: 0.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFE9E9EE)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.style, {super.key});

  final StatusStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = style ?? (label: '—', color: _grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        s.label,
        style: GoogleFonts.inter(
            color: s.color, fontSize: 12.0, fontWeight: FontWeight.w700),
      ),
    );
  }
}

TextStyle salesTitle([double size = 16.0]) => GoogleFonts.interTight(
    color: kSalesInk, fontSize: size, fontWeight: FontWeight.w700);

TextStyle salesBody({Color color = kSalesMuted, double size = 13.0}) =>
    GoogleFonts.inter(color: color, fontSize: size, height: 1.4);

/// Chargement, erreur et liste vide pour une lecture du serveur.
class SalesLoader extends StatelessWidget {
  const SalesLoader({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  final Future<Map<String, dynamic>> future;
  final Widget Function(Map<String, dynamic> data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(48.0),
            child: Center(child: CircularProgressIndicator(color: kSalesRed)),
          );
        }
        if (snap.hasError) {
          return SalesEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Chargement impossible',
            text: '${snap.error}',
            action: TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          );
        }
        return builder(snap.data!);
      },
    );
  }
}

class SalesEmpty extends StatelessWidget {
  const SalesEmpty(
      {super.key, required this.icon, required this.title, this.text, this.action});

  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
      child: Column(
        children: [
          Icon(icon, size: 44.0, color: const Color(0xFFB9BCC3)),
          const SizedBox(height: 12.0),
          Text(title, style: salesTitle(15.0), textAlign: TextAlign.center),
          if (text != null) ...[
            const SizedBox(height: 6.0),
            Text(text!, style: salesBody(), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 8.0), action!],
        ],
      ),
    );
  }
}

/// Lance une action serveur ; affiche le résultat ou l'erreur. true si réussi.
Future<bool> runSalesAction(BuildContext context,
    Future<dynamic> Function() action, String success) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(
        content: Text(success), backgroundColor: const Color(0xFF136B3D)));
    return true;
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: kSalesDeepRed));
    return false;
  }
}

/// Demande un motif (ou une note). null si annulé.
Future<String?> askText(BuildContext context, String title,
        {String label = 'Motif', bool required = true, String? hint}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
          title: title, label: label, required: required, hint: hint),
    );

/// La fenêtre garde son champ jusqu'à sa disparition complète.
class _TextDialog extends StatefulWidget {
  const _TextDialog(
      {required this.title, required this.label, required this.required, this.hint});

  final String title;
  final String label;
  final bool required;
  final String? hint;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _controller = TextEditingController();
  bool _missing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 300,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          hintMaxLines: 3,
          errorText: _missing ? 'Champ obligatoire' : null,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: () {
            final v = _controller.text.trim();
            if (widget.required && v.isEmpty) {
              setState(() => _missing = true);
              return;
            }
            Navigator.pop(context, v);
          },
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

/// Champ de formulaire au style Kitunga.
InputDecoration salesInput(String label, {String? hint, String? helper}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      filled: true,
      fillColor: kSalesSurface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: kSalesRed, width: 1.5),
      ),
    );

/// Choix d'une date (affichage et retour en jour local).
Future<DateTime?> pickDay(BuildContext context, DateTime? initial) =>
    showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      locale: const Locale('fr'),
    );
