import 'package:flutter/material.dart';

import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_kit.dart';

export 'admin_layout.dart';
export '/noc/ui/admin_kit.dart';

/// Éléments communs des pages d'administration (images, listes, fenêtres).
/// Le cadre (menu, barre du haut) est dans admin_layout.dart.
// ── Images ───────────────────────────────────────────────────────────────

/// Image d'une catégorie, d'un produit ou d'un partenaire : image incluse
/// dans l'application (« asset:… ») ou adresse en ligne.
class AdminImage extends StatelessWidget {
  const AdminImage(this.src,
      {super.key,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.icon = Icons.image_outlined});

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('asset:')) {
      return Image.asset(src.substring(6),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _empty());
    }
    if (src.startsWith('http')) {
      return KitungaImage(src,
          width: width, height: height, fallbackIcon: icon, placeholder: _empty());
    }
    return _empty();
  }

  Widget _empty() => Container(
        width: width,
        height: height,
        color: const Color(0xFFEDEDF1),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFFA5A8B0), size: 26.0),
      );
}

/// Remplace le choix d'image dans les tests (adresse renvoyée directement).
@visibleForTesting
Future<String?> Function()? adminImagePickerOverride;

/// Choisit une image dans la galerie et l'envoie dans le dossier de l'admin
/// (Firebase Storage). Renvoie son adresse, ou null si annulé ou en échec.
Future<String?> pickAdminImage(BuildContext context) async {
  if (adminImagePickerOverride != null) return adminImagePickerOverride!();
  final messenger = ScaffoldMessenger.of(context);
  final files = await selectMedia(
    mediaSource: MediaSource.photoGallery,
    maxWidth: 1600.0,
    imageQuality: 85,
  );
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  if (!context.mounted || !validateFileFormat(file.storagePath, context)) {
    return null;
  }
  if (file.bytes.length > 10 * 1024 * 1024) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Image trop lourde (10 Mo au maximum).'),
        backgroundColor: kSalesDeepRed));
    return null;
  }
  messenger.showSnackBar(const SnackBar(
      content: Text('Envoi de l\'image…'), duration: Duration(seconds: 2)));
  try {
    final url = await uploadData(file.storagePath, file.bytes);
    if (url == null) throw 'échec';
    return url;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('L\'image n\'a pas pu être envoyée. Réessayez.'),
        backgroundColor: kSalesDeepRed));
    return null;
  }
}

/// Zone d'image d'un formulaire : aperçu et bouton « Changer l'image ».
class AdminImageField extends StatelessWidget {
  const AdminImageField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.height = 140.0,
    this.background,
    this.fit = BoxFit.cover,
    this.allowRemove = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final double height;
  final Color? background;
  final BoxFit fit;
  final bool allowRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: salesBody(color: kSalesInk, size: 13.0)),
        const SizedBox(height: 6.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            height: height,
            width: double.infinity,
            color: background ?? const Color(0xFFEDEDF1),
            padding: fit == BoxFit.contain ? const EdgeInsets.all(12.0) : null,
            child: AdminImage(value, height: height, fit: fit),
          ),
        ),
        const SizedBox(height: 6.0),
        Wrap(
          spacing: 8.0,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 18.0),
              label: Text(value.isEmpty ? 'Ajouter une image' : 'Changer l\'image'),
              style: OutlinedButton.styleFrom(foregroundColor: kSalesRed),
              onPressed: () async {
                final url = await pickAdminImage(context);
                if (url != null) onChanged(url);
              },
            ),
            if (allowRemove && value.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(''),
                child: const Text('Retirer'),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Éléments communs des listes ──────────────────────────────────────────

/// Barre de recherche des listes.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField(
      {super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320.0,
      child: TextField(
        onChanged: onChanged,
        decoration: salesInput('Rechercher', hint: hint).copyWith(
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

/// Menu d'actions d'une ligne : voir, modifier, supprimer, etc.
class AdminRowActions extends StatelessWidget {
  const AdminRowActions({super.key, required this.actions});

  final List<({String label, IconData icon, VoidCallback onTap, bool danger})>
      actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: kSalesMuted),
      onSelected: (i) => actions[i].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actions[i].icon,
                    size: 18.0,
                    color: actions[i].danger ? kSalesRed : kSalesInk),
                const SizedBox(width: 10.0),
                Flexible(
                  child: Text(actions[i].label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: actions[i].danger ? kSalesRed : kSalesInk)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

typedef AdminAction = ({
  String label,
  IconData icon,
  VoidCallback onTap,
  bool danger
});

AdminAction viewAction(VoidCallback f) =>
    (label: 'Voir', icon: Icons.visibility_outlined, onTap: f, danger: false);
AdminAction editAction(VoidCallback f) =>
    (label: 'Modifier', icon: Icons.edit_outlined, onTap: f, danger: false);
AdminAction deleteAction(VoidCallback f, {String label = 'Supprimer'}) =>
    (label: label, icon: Icons.delete_outline_rounded, onTap: f, danger: true);

/// Bouton principal d'une page (« Ajouter … »).
Widget adminAddButton(String label, VoidCallback onPressed) =>
    FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: kSalesRed,
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      ),
      icon: const Icon(Icons.add_rounded),
      label: Text(label),
      onPressed: onPressed,
    );

/// Fenêtre de formulaire (titre, contenu défilant, boutons).
class AdminFormDialog extends StatelessWidget {
  const AdminFormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saving = false,
    this.saveLabel = 'Enregistrer',
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 12.0, 8.0),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: salesTitle(19.0))),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in children) ...[
                      c,
                      const SizedBox(height: 14.0),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 20.0),
              // Passe à la ligne sur un écran étroit au lieu de déborder.
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kSalesRed),
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(
                            width: 18.0,
                            height: 18.0,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.0, color: Colors.white))
                        : Text(saveLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé : valeur » des fiches.
class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130.0,
              child: Text(label, style: salesBody(size: 13.0))),
          Expanded(
            child: Text(value.trim().isEmpty ? '—' : value,
                style: salesBody(color: kSalesInk, size: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// Confirmation simple. true si confirmé.
Future<bool> adminConfirm(BuildContext context,
    {required String title,
    required String message,
    String confirm = 'Supprimer'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Statut d'un compte (champ account_status).
const accountStatusStyle = <String, StatusStyle>{
  'active': (label: 'Actif', color: Color(0xFF1E9E5A)),
  'suspended': (label: 'Suspendu', color: Color(0xFFE08A00)),
};

/// Nombre entier saisi (vide = null).
int? parseInt(String v) =>
    int.tryParse(v.replaceAll(RegExp(r'[\s  .]'), ''));

/// Page rafraîchie quand l'admin revient sur l'onglet.
typedef AdminReload = void Function();

/// Indique le nombre d'éléments affichés.
String countLabel(int n, String singular, String plural) =>
    '$n ${n > 1 ? plural : singular}';

/// Formulaire : ligne de deux champs sur grand écran, une colonne sinon.
class AdminFieldRow extends StatelessWidget {
  const AdminFieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 420.0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 14.0),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12.0),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

/// Dernière mise à jour d'une donnée (pour les en-têtes de liste).
String nowLabel() => 'Mis à jour à ${DateFormat('HH:mm', 'fr').format(DateTime.now())}';
