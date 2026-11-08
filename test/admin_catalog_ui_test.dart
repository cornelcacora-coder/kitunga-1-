import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/kitunga_categories.dart';
import 'package:kitunga/noc/admin/admin_categories_widget.dart';
import 'package:kitunga/noc/admin/admin_clients_widget.dart';
import 'package:kitunga/noc/admin/admin_partners_widget.dart';
import 'package:kitunga/noc/admin/admin_products_widget.dart';
import 'package:kitunga/noc/admin/admin_shell.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Catalogue, partenaires et clients de l'admin, avec un serveur simulé.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  const img = 'https://firebasestorage.googleapis.com/v0/b/x/o/a.png';

  final categories = [
    {'id': 'c1', 'name': 'Boutique', 'color': '#FFE4E1', 'order': 0,
      'active': true, 'sellers': 0,
      'image': 'asset:assets/images/categories/boutique.png'},
    {'id': 'c2', 'name': 'Restaurant', 'color': '#FFEBD6', 'order': 1,
      'active': true, 'sellers': 2,
      'image': 'asset:assets/images/categories/restaurant.png'},
    {'id': 'c3', 'name': 'Boulangerie', 'color': '#E2F5E9', 'order': 2,
      'active': false, 'sellers': 0, 'image': ''},
  ];
  final sellers = [
    {'uid': 'shop', 'role': 'Seller', 'displayName': 'Chez Paul',
      'email': 'paul@test.cg', 'phone': '061234567', 'category': 'Restaurant',
      'bio': '', 'horraire': '8h-22h', 'photoUrl': '', 'businessCover': '',
      'verified': true, 'accountStatus': 'active', 'products': 3},
    {'uid': 'shop2', 'role': 'Seller', 'displayName': 'Ancien commerce',
      'email': '', 'phone': '', 'category': 'Restaurant', 'bio': '',
      'horraire': '', 'photoUrl': '', 'businessCover': '', 'verified': false,
      'accountStatus': 'suspended', 'accountStatusReason': 'Fermé',
      'products': 0},
  ];

  Map<String, dynamic> fake(String function, Map<String, dynamic> data) {
    if (function != 'kitungaCatalogQuery') return {'ok': true, 'uid': 'new'};
    switch (data['view']) {
      case 'categories':
        return {'categories': categories};
      case 'products':
        return {'products': [
          {'id': 'p1', 'name': 'Poulet DG', 'price': 5000, 'quantity': 0,
            'published': true, 'express': true, 'tag': 'Tendance',
            'section': 'Plats', 'unit': '', 'prodImg': '', 'description': '',
            'createdAt': '2026-11-02T10:00:00Z',
            'seller': {'uid': 'shop', 'name': 'Chez Paul',
              'category': 'Restaurant'}},
          {'id': 'p2', 'name': 'Jus', 'price': 500, 'quantity': 12,
            'published': false, 'express': false, 'tag': '', 'section': '',
            'unit': '', 'prodImg': img, 'description': '', 'seller': null},
        ]};
      case 'partners':
        return {'partners': data['role'] == 'Seller' ? sellers : <Object>[]};
      case 'clients':
        return {'total': 1, 'clients': [
          {'uid': 'marie', 'displayName': 'Marie Ngoma', 'email': 'm@test.cg',
            'phone': '061234567', 'photoUrl': '', 'accountStatus': 'active',
            'createdAt': '2026-11-01T10:00:00Z',
            'subscribeCloseAt': '2099-01-01T00:00:00Z'},
        ]};
    }
    return {};
  }

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    salesBackendOverride = (function, data) async {
      calls.add((function, data));
      return fake(function, data);
    };
    adminImagePickerOverride = () async => img;
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: page,
    ));
    await tester.pumpAndSettle();
  }

  /// Action d'une ligne : pastille du tableau (infobulle) ou menu « Actions »
  /// (cartes des catégories).
  Future<void> rowAction(WidgetTester tester, String label, {int at = 0}) async {
    final dots = find.byTooltip(label);
    if (find.byTooltip('Actions').evaluate().isEmpty) {
      await tester.ensureVisible(dots.at(at));
      await tester.pumpAndSettle();
      await tester.tap(dots.at(at));
    } else {
      await tester.tap(find.byTooltip('Actions').at(at));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
    }
    await tester.pumpAndSettle();
  }

  /// Champs de la fenêtre ouverte (et non ceux de la page derrière).
  Finder dialogFields() => find.descendant(
      of: find.byType(Dialog), matching: find.byType(TextField));

  (String, Map<String, dynamic>) last(String function) =>
      calls.lastWhere((c) => c.$1 == function);

  for (final size in const [Size(1280, 900), Size(400, 860)]) {
    final w = size.width.toInt();

    testWidgets('menu : sections dépliables ($w px)', (tester) async {
      await open(tester, const AdminCategoriesWidget(), size);
      if (size.width < AdminShell.wideBreakpoint) {
        await tester.tap(find.byTooltip('Menu'));
        await tester.pumpAndSettle();
      }
      // Section de la page ouverte dépliée, les autres repliées.
      expect(find.text('Catégories'), findsWidgets);
      expect(find.text('Produits'), findsOneWidget);
      expect(find.text('Livreurs'), findsNothing);
      await tester.tap(find.text('Partenaires'));
      await tester.pumpAndSettle();
      expect(find.text('Livreurs'), findsOneWidget);
      expect(find.text('Commerçants & boutiques'), findsOneWidget);
      await tester.tap(find.text('Gestion'));
      await tester.pumpAndSettle();
      expect(find.text('Module commercial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('catégories : voir, ajouter, modifier, supprimer ($w px)',
        (tester) async {
      await open(tester, const AdminCategoriesWidget(), size);
      expect(find.text('Restaurant'), findsOneWidget);
      expect(find.text('2 commerces'), findsOneWidget);
      expect(find.text('Masquée'), findsOneWidget);

      // Ajouter : image obligatoire, puis enregistrement.
      await tester.tap(find.text('Nouvelle catégorie'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogFields().first, 'Épicerie');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Ajoutez une image.'), findsOneWidget);
      await tester.tap(find.text('Ajouter une image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final created = last('kitungaSaveCategory').$2;
      expect(created['name'], 'Épicerie');
      expect(created['image'], img);
      expect(created['order'], 3);
      expect(created.containsKey('id'), isFalse);

      // Modifier : l'image est changée.
      await rowAction(tester, 'Modifier', at: 1);
      await tester.tap(find.text('Changer l\'image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final edited = last('kitungaSaveCategory').$2;
      expect(edited['id'], 'c2');
      expect(edited['name'], 'Restaurant');
      expect(edited['image'], img);

      // Supprimer une catégorie utilisée : choix du remplacement.
      await rowAction(tester, 'Supprimer', at: 1);
      expect(find.textContaining('2 commerces utilisent'), findsOneWidget);
      await tester.tap(find.text('Nouvelle catégorie').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boutique').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déplacer et supprimer'));
      await tester.pumpAndSettle();
      expect(last('kitungaDeleteCategory').$2,
          {'id': 'c2', 'reassignTo': 'c1'});

      // Voir.
      await rowAction(tester, 'Voir', at: 0);
      expect(find.text('Voir les commerces'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('produits : emplacement, ajouter, modifier, supprimer ($w px)',
        (tester) async {
      await open(tester, const AdminProductsWidget(), size);
      expect(find.text('Restaurant › Chez Paul › Plats'), findsOneWidget);
      expect(find.text('Commerce supprimé'), findsOneWidget);
      expect(find.text('Brouillon'), findsOneWidget);
      expect(find.text('⚡ Express'), findsOneWidget);
      expect(find.text('Stock : 0'), findsOneWidget);

      await tester.tap(find.text('Nouveau produit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez le commerce.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chez Paul · Restaurant').last);
      await tester.pumpAndSettle();
      final fields = dialogFields();
      await tester.enterText(fields.at(0), 'Riz parfumé');
      await tester.enterText(fields.at(1), '1 500');
      await tester.enterText(fields.at(2), '20');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Ajoutez une photo avant de publier ce produit.'),
          findsOneWidget);
      await tester.tap(find.text('Ajouter une image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final saved = last('kitungaSaveProduct').$2;
      expect(saved['sellerUid'], 'shop');
      expect(saved['name'], 'Riz parfumé');
      expect(saved['price'], 1500);
      expect(saved['quantity'], 20);
      expect(saved['published'], isTrue);
      expect(saved['prodImg'], img);

      await rowAction(tester, 'Modifier', at: 1);
      expect(find.text('Modifier le produit'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final edited = last('kitungaSaveProduct').$2;
      expect(edited['id'], 'p2');
      expect(edited['published'], isFalse);
      expect(edited['price'], 500);

      await rowAction(tester, 'Supprimer', at: 0);
      await tester.enterText(find.byType(TextField).last, 'Doublon');
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(last('kitungaDeleteProduct').$2, {'id': 'p1', 'reason': 'Doublon'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('commerçants : voir, ajouter, modifier, supprimer ($w px)',
        (tester) async {
      await open(tester, const AdminPartnersWidget(role: 'Seller'), size);
      expect(find.text('Chez Paul'), findsOneWidget);
      expect(find.text('Suspendu'), findsOneWidget);
      expect(find.text('3 produits'), findsOneWidget);

      // Tri par nom : « Ancien commerce » (shop2) puis « Chez Paul » (shop).
      await rowAction(tester, 'Modifier', at: 1);
      await tester.tap(find.text('Ajouter une image').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final edited = last('kitungaSavePartner').$2;
      expect(edited['uid'], 'shop');
      expect(edited['photoUrl'], img);
      expect(edited['category'], 'Restaurant');

      await rowAction(tester, 'Supprimer', at: 0);
      await tester.enterText(find.byType(TextField).last, 'Fermeture');
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(last('kitungaSetAccountStatus').$2,
          {'userUid': 'shop', 'status': 'suspended', 'reason': 'Fermeture'});

      await rowAction(tester, 'Réactiver', at: 0);
      await tester.tap(find.text('Réactiver').last);
      await tester.pumpAndSettle();
      expect(last('kitungaSetAccountStatus').$2,
          {'userUid': 'shop2', 'status': 'active'});

      await tester.tap(find.text('Nouveau commerce'));
      await tester.pumpAndSettle();
      final f = dialogFields();
      await tester.enterText(f.at(0), 'Pressing Éclat');
      await tester.enterText(f.at(1), 'eclat@test.cg');
      await tester.enterText(f.at(2), 'secret12');
      await tester.tap(find.text('Créer le compte'));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez la catégorie.'), findsOneWidget);
      await tester.tap(find.widgetWithText(
          DropdownButtonFormField<String>, 'Catégorie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boutique').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer le compte'));
      await tester.pumpAndSettle();
      final created = last('kitungaCreatePartner').$2;
      expect(created['role'], 'Seller');
      expect(created['email'], 'eclat@test.cg');
      expect(created['category'], 'Boutique');
      expect(created['subscribeType'], 'Mensuel - 250F');
      expect(tester.takeException(), isNull);
    });

    testWidgets('livreurs et clients ($w px)', (tester) async {
      await open(tester, const AdminPartnersWidget(role: 'Deliver'), size);
      expect(find.text('Aucun livreur'), findsOneWidget);
      expect(find.text('Nouveau livreur'), findsOneWidget);

      await open(tester, const AdminClientsWidget(), size);
      expect(find.text('Marie Ngoma'), findsOneWidget);
      expect(find.text('Abonné'), findsOneWidget);
      await rowAction(tester, 'Offrir un abonnement');
      await tester.tap(find.text('90 jours'));
      await tester.enterText(find.byType(TextField).last, 'Geste commercial');
      await tester.tap(find.text('Offrir'));
      await tester.pumpAndSettle();
      expect(last('kitungaGrantSubscription').$2,
          {'userUid': 'marie', 'days': 90, 'reason': 'Geste commercial'});
      await rowAction(tester, 'Modifier');
      await tester.enterText(dialogFields().first, 'Marie N.');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(last('kitungaSavePartner').$2,
          {'uid': 'marie', 'displayName': 'Marie N.', 'phone': '061234567'});
      expect(tester.takeException(), isNull);
    });
  }

  test('catégories de l\'application : serveur, sinon les 5 d\'origine',
      () async {
    final store = KitungaCategoryStore.instance..resetForTest();
    KitungaCategoryStore.fetchOverride = () async => throw 'hors ligne';
    expect(store.list.map((c) => c.name),
        ['Boutique', 'Restaurant', 'Pharmacie', 'Magasin', 'Fast Food']);
    await Future<void>.delayed(Duration.zero);
    expect(store.list.length, 5);

    store.resetForTest();
    KitungaCategoryStore.fetchOverride = () async => {'categories': [
          {'name': 'Boutique', 'image': 'asset:assets/images/categories/boutique.png',
            'color': '#FFE4E1'},
          {'name': 'Boulangerie', 'image': img, 'color': 'xx'},
          {'name': ''},
        ]};
    store.list;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final l = store.list;
    expect(l.map((c) => c.name), ['Boutique', 'Boulangerie']);
    expect(l[0].image, 'assets/images/categories/boutique.png');
    expect(l[0].pastel, const Color(0xFFFFE4E1));
    expect(l[1].image, img);
    expect(l[1].pastel, const Color(0xFFF2F2F5));
    KitungaCategoryStore.fetchOverride = null;
  });
}
