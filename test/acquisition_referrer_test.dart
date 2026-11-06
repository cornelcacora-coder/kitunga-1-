import 'package:flutter_test/flutter_test.dart';
import 'package:kitunga/backend/acquisition.dart';

void main() {
  const parse = KitungaAcquisition.parseInstallReferrer;

  test('lit le code et le clic transmis par Google Play', () {
    final r = parse(
        'utm_source=kitunga&utm_medium=commercial&kitunga_code=ktg001-x7p9'
        '&kitunga_click=AbC123def456GHI',
        clickAtSeconds: 1762430000);
    expect(r, {
      'code': 'KTG001-X7P9',
      'source': 'install_referrer',
      'clickId': 'AbC123def456GHI',
      'referrerClickAt': 1762430000,
    });
  });

  test('installation sans code commercial : rien', () {
    expect(parse('utm_source=google-play&utm_medium=organic'), isNull);
    expect(parse(''), isNull);
    expect(parse(null), isNull);
  });

  test('code ou clic invalide : ignoré', () {
    expect(parse('kitunga_code=KTG001-X0P9'), isNull);
    expect(parse('kitunga_code=<script>'), isNull);
    expect(parse('kitunga_code=KTG001-X7P9&kitunga_click=a b'), {
      'code': 'KTG001-X7P9',
      'source': 'install_referrer',
    });
    expect(parse('%%%'), isNull);
  });
}
