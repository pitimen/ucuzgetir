import 'package:flutter_test/flutter_test.dart';
import 'package:ucuzgetir_app/models/store_product.dart';
import 'package:ucuzgetir_app/services/product_catalog_service.dart';

void main() {
  group('ProductCatalogService.parseFeed', () {
    test('parses namespaced products and their prices', () {
      final products = ProductCatalogService.parseFeed(_feed);

      expect(products, hasLength(2));
      final product = products.singleWhere((item) => item.id == '0007902');
      expect(product.name, 'Ülker Çokoprens 81 gr 18 adet');
      expect(product.price, 285.12);
      expect(product.formattedPrice, '285,12 ₺');
      expect(
        product.imageUrl,
        Uri.parse('https://www.ucuzgetir.com/ResimKucult.ashx?f=example.jpg'),
      );
      expect(
        product.productUrl,
        Uri.parse(
          'https://www.ucuzgetir.com/ulker-cokoprens-81-gr-18-adet-0007902',
        ),
      );
    });

    test('ignores products with links outside the store', () {
      final document = _feed.replaceFirst(
        'https://www.ucuzgetir.com/ulker-cokoprens-81-gr-18-adet-0007902',
        'https://example.com/product',
      );

      final products = ProductCatalogService.parseFeed(document);

      expect(products, hasLength(1));
      expect(products.single.id, '0009200');
    });

    test('ignores duplicate product identifiers', () {
      final document = _feed.replaceFirst('</channel>', '''
    <item>
      <g:id>0007902</g:id>
      <g:title>Duplicate</g:title>
      <g:link>https://www.ucuzgetir.com/duplicate</g:link>
      <g:price>1.00 TRY</g:price>
    </item>
  </channel>''');

      final products = ProductCatalogService.parseFeed(document);

      expect(products, hasLength(2));
      expect(
        products.firstWhere((product) => product.id == '0007902').name,
        'Ülker Çokoprens 81 gr 18 adet',
      );
    });
  });

  group('StoreProduct.parsePrice', () {
    test('rejects empty and malformed values', () {
      expect(StoreProduct.parsePrice(''), isNull);
      expect(StoreProduct.parsePrice('fiyat sorunuz'), isNull);
    });
  });
}

const String _feed = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">
  <channel>
    <item>
      <g:id>0007902</g:id>
      <g:title>Ülker Çokoprens 81 gr 18 adet</g:title>
      <g:description>Ülker Çokoprens</g:description>
      <g:link>https://www.ucuzgetir.com/ulker-cokoprens-81-gr-18-adet-0007902</g:link>
      <g:image_link>https://www.ucuzgetir.com/ResimKucult.ashx?f=example.jpg</g:image_link>
      <g:price>285.12 TRY</g:price>
    </item>
    <item>
      <g:id>0009200</g:id>
      <g:title>Ülker Çizi Kraker 70 gr 24 adet</g:title>
      <g:description>Ülker Çizi Kraker</g:description>
      <g:link>https://www.ucuzgetir.com/ulker-cizi-kraker-70-gr-24-adet-0009200</g:link>
      <g:image_link>https://www.ucuzgetir.com/ResimKucult.ashx?f=example.jpg</g:image_link>
      <g:price>323.28 TRY</g:price>
    </item>
  </channel>
</rss>
''';
