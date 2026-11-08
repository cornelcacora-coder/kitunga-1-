import 'package:flutter_test/flutter_test.dart';
import 'package:kitunga/flutter_flow/nav/web_admin_only.dart';

void main() {
  String? go(String url) => webAdminRedirect(Uri.parse(url));

  test('pages d\'administration permises sur le web', () {
    for (final url in [
      '/admin',
      '/supervisionDashboard',
      '/forgotPassword',
      '/forgotPasswordLink',
      '/sign?accessibility=Admin',
      '/addProfile?partnerRef=User%2Fabc',
    ]) {
      expect(go(url), isNull, reason: url);
    }
  });

  test('partie client renvoyée vers la connexion admin', () {
    for (final url in [
      '/',
      '',
      '/intro',
      '/onboarding',
      '/login',
      '/sign',
      '/sign?accessibility=User',
      '/addProfile',
      '/home',
      '/cartLast',
      '/shopDetailPage?userRef=x',
      '/inconnue',
    ]) {
      expect(go(url), kWebAdminHome, reason: url);
    }
  });
}
