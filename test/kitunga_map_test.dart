import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:kitunga/mobile/components/delivery/kitunga_map.dart';

void main() {
  setUp(() {
    kitungaGoogleMapsOverride = () async => false;
    kitungaMapShowTiles = false;
  });
  tearDown(() => kitungaGoogleMapsOverride = null);

  Widget app(ll.LatLng rider) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: KitungaMapView(
              follow: true,
              fitPoints: [rider, const ll.LatLng(-4.2860, 15.2450)],
              markers: [
                KitungaMapMarker(
                    id: 'rider',
                    point: rider,
                    icon: Icons.delivery_dining_rounded,
                    color: Colors.green,
                    round: true),
              ],
            ),
          ),
        ),
      );

  testWidgets('suit le livreur, garde la vue après un geste, Recentrer',
      (tester) async {
    await tester.pumpWidget(app(const ll.LatLng(-4.2560, 15.2850)));
    await tester.pump();
    expect(find.text('Recentrer'), findsNothing);

    // Le livreur avance : pas de bouton, la carte suit toute seule.
    await tester.pumpWidget(app(const ll.LatLng(-4.2600, 15.2800)));
    await tester.pump();
    expect(find.text('Recentrer'), findsNothing);

    // L'utilisateur déplace la carte : il garde sa vue.
    await tester.drag(find.byType(KitungaMapView), const Offset(80, 40));
    await tester.pump();
    expect(find.text('Recentrer'), findsOneWidget);

    // Nouvelle position : la vue de l'utilisateur est conservée.
    await tester.pumpWidget(app(const ll.LatLng(-4.2650, 15.2750)));
    await tester.pump();
    expect(find.text('Recentrer'), findsOneWidget);

    await tester.tap(find.text('Recentrer'));
    await tester.pump();
    expect(find.text('Recentrer'), findsNothing);
  });
}
