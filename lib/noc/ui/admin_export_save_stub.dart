import 'dart:typed_data';

/// Hors navigateur (application mobile) : l'export n'est pas proposé.
void saveAdminFile(Uint8List bytes, String name, String mime) =>
    throw UnsupportedError('Export disponible sur le site d\'administration.');
