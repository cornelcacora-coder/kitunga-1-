import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Avant chaque fichier de test : la police Poppins de l'application est
/// chargée d'avance (sinon elle arrive en cours de test et change la mise
/// en page au milieu d'une vérification).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const files = {
    'Poppins_regular': 'Poppins-Regular.ttf',
    'Poppins_300': 'Poppins-Light.ttf',
    'Poppins_500': 'Poppins-Medium.ttf',
    'Poppins_600': 'Poppins-SemiBold.ttf',
    'Poppins_700': 'Poppins-Bold.ttf',
    'Poppins_italic': 'Poppins-Italic.ttf',
    'Poppins_500italic': 'Poppins-MediumItalic.ttf',
  };
  for (final e in files.entries) {
    final f = File('assets/google_fonts/${e.value}');
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    await (FontLoader(e.key)..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  }
  await testMain();
}
