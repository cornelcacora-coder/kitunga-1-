import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Téléchargement d'un fichier généré dans le navigateur.
void saveAdminFile(Uint8List bytes, String name, String mime) {
  final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  // Laisse le temps au navigateur de lire le fichier avant de le libérer.
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
