import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/mobile/common/my_profile/my_profile_widget.dart' show KitungaAvatar;
import '/mobile/main_app/order_view/order_view_widget.dart'
    show kitungaPageBar;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_model.dart';
export 'edit_profile_model.dart';

const _red = Color(0xFFE51A1A);

/// « Modifier le profil » : photo, nom, téléphone, présentation.
/// La photo n'est remplacée que si une nouvelle a été choisie.
class EditProfileWidget extends StatefulWidget {
  const EditProfileWidget({super.key});

  static String routeName = 'EditProfile';
  static String routePath = '/editProfile';

  @override
  State<EditProfileWidget> createState() => _EditProfileWidgetState();
}

class _EditProfileWidgetState extends State<EditProfileWidget> {
  late EditProfileModel _model;
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  /// Second numéro (facultatif) : autre opérateur, numéro de travail…
  late final TextEditingController _phone2 = TextEditingController(
      text: '${currentUserDocument?.snapshotData['phone_number_2'] ?? ''}');

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditProfileModel());
    _model.nameTextController ??=
        TextEditingController(text: currentUserDisplayName);
    _model.telephoneTextController ??=
        TextEditingController(text: currentPhoneNumber);
    _model.bioTextController ??= TextEditingController(
        text: valueOrDefault(currentUserDocument?.bio, ''));
  }

  @override
  void dispose() {
    _phone2.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final media = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: true,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (media == null ||
        media.isEmpty ||
        !media.every((m) => validateFileFormat(m.storagePath, context))) {
      return;
    }
    setState(() => _model.isDataUploading_userPictureUpladed = true);
    String? url;
    try {
      url = await uploadData(media.first.storagePath, media.first.bytes);
    } finally {
      if (mounted) {
        setState(() => _model.isDataUploading_userPictureUpladed = false);
      }
    }
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La photo n\'a pas pu être envoyée. Réessayez.')));
      return;
    }
    setState(() => _model.uploadedFileUrl_userPictureUpladed = url!);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final photo = _model.uploadedFileUrl_userPictureUpladed;
      await currentUserReference!.update({
        ...createUserRecordData(
          displayName: _model.nameTextController!.text.trim(),
          phoneNumber: _model.telephoneTextController!.text.trim(),
          bio: _model.bioTextController!.text.trim(),
          // Pas de nouvelle photo : on garde l'ancienne.
          photoUrl: photo.isNotEmpty ? photo : null,
        ),
        'phone_number_2': _phone2.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
      context.safePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrement impossible. Vérifiez votre '
              'connexion et réessayez.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    InputDecoration deco(String label, IconData icon, {String? hint}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: theme.secondaryText, size: 20),
          filled: true,
          fillColor: theme.secondaryBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.alternate)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1.4)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1.4)),
        );
    final uploading = _model.isDataUploading_userPictureUpladed;
    final newPhoto = _model.uploadedFileUrl_userPictureUpladed;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
        appBar: kitungaPageBar(context, 'Modifier le profil'),
        body: AuthUserStreamWidget(
          builder: (context) => Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: Stack(children: [
                    KitungaAvatar(
                        url: newPhoto.isNotEmpty ? newPhoto : currentUserPhoto,
                        name: currentUserDisplayName),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: _red,
                        shape: const CircleBorder(
                            side: BorderSide(color: Colors.white, width: 3)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: uploading ? null : _pickPhoto,
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: uploading
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.photo_camera_rounded,
                                    color: Colors.white, size: 19),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: uploading ? null : _pickPhoto,
                    style: TextButton.styleFrom(foregroundColor: _red),
                    child: Text('Changer la photo',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _model.nameTextController,
                  focusNode: _model.nameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: deco('Nom et prénom', Icons.person_outline,
                      hint: 'Ex. BITODI Cornelca'),
                  validator: (v) => (v ?? '').trim().length < 2
                      ? 'Indiquez votre nom.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model.telephoneTextController,
                  focusNode: _model.telephoneFocusNode,
                  keyboardType: TextInputType.phone,
                  decoration: deco('Téléphone principal', Icons.phone_outlined,
                      hint: 'Ex. 06 123 45 67'),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.isEmpty) return null;
                    return digits.length < 9
                        ? 'Numéro incomplet (9 chiffres).'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone2,
                  keyboardType: TextInputType.phone,
                  decoration: deco('Autre numéro (facultatif)',
                      Icons.phone_android_outlined,
                      hint: 'Ex. 05 123 45 67 (Airtel)'),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.isEmpty) return null;
                    return digits.length < 9
                        ? 'Numéro incomplet (9 chiffres).'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model.bioTextController,
                  focusNode: _model.bioFocusNode,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: deco('Présentation (facultatif)',
                      Icons.notes_rounded),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving || uploading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text('Enregistrer',
                            style: GoogleFonts.poppins(
                                fontSize: 15.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
