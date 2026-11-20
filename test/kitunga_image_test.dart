import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitunga/flutter_flow/flutter_flow_util.dart';
import 'package:kitunga/mobile/components/kitunga_image/kitunga_image.dart';

/// Images fournies avec l'application (plus de dépendance au stockage
/// FlutterFlow).
void main() {
  test('les images de l\'application ne passent pas par le proxy', () {
    expect(getCORSProxyUrl('assets/images/app/emptycart.png'),
        'assets/images/app/emptycart.png');
  });

  testWidgets('KitungaImage affiche une image de l\'application',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: KitungaImage('assets/images/zones/bacongo.jpg',
            width: 100.0, height: 80.0)));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/images/zones/bacongo.jpg');
  });
}
