import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/store_product.dart';

class ProductCatalogService {
  ProductCatalogService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static final Uri feedUri = Uri.https(
    'www.ucuzgetir.com',
    '/GoogleMerchant.aspx',
  );

  final http.Client _client;
  final bool _ownsClient;

  Future<List<StoreProduct>> fetchProducts() async {
    final response = await _client
        .get(
          feedUri,
          headers: const {'Accept': 'application/rss+xml, application/xml'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Ürün kataloğu HTTP ${response.statusCode} yanıtı verdi.',
      );
    }

    try {
      return parseFeed(response.body);
    } on XmlParserException catch (error, stackTrace) {
      developer.log(
        'Ürün kataloğu XML olarak çözümlenemedi.',
        name: 'ucuzgetir.catalog',
        error: error,
        stackTrace: stackTrace,
      );
      throw const FormatException('Ürün kataloğu geçerli bir XML değil.');
    }
  }

  @visibleForTesting
  static List<StoreProduct> parseFeed(String document) {
    final xml = XmlDocument.parse(document);
    final productsById = <String, StoreProduct>{};

    for (final item in xml.descendants.whereType<XmlElement>()) {
      if (item.name.local != 'item') continue;

      final id = _field(item, 'id', googleNamespace: true);
      final name = _field(item, 'title', googleNamespace: true);
      final productUrl = _trustedUri(
        _field(item, 'link', googleNamespace: true),
      );
      if (id == null || name == null || productUrl == null) continue;

      final imageUrl = _trustedUri(
        _field(item, 'image_link', googleNamespace: true),
      );
      final priceText = _field(item, 'price', googleNamespace: true) ?? '';
      productsById.putIfAbsent(
        id,
        () => StoreProduct(
          id: id,
          name: name,
          description:
              _field(item, 'description', googleNamespace: true) ?? name,
          productUrl: productUrl,
          imageUrl: imageUrl,
          price: StoreProduct.parsePrice(priceText),
        ),
      );
    }

    final products = productsById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(products);
  }

  static const String googleNamespace = 'http://base.google.com/ns/1.0';

  static String? _field(
    XmlElement item,
    String localName, {
    required bool googleNamespace,
  }) {
    for (final child in item.childElements) {
      if (child.name.local != localName) continue;
      if (googleNamespace &&
          child.name.namespaceUri != ProductCatalogService.googleNamespace) {
        continue;
      }

      final value = child.innerText.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static Uri? _trustedUri(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        (uri.host != 'ucuzgetir.com' && uri.host != 'www.ucuzgetir.com')) {
      return null;
    }
    return uri;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class ProductCatalogController extends ChangeNotifier {
  ProductCatalogController(this._service);

  final ProductCatalogService _service;
  List<StoreProduct> products = const [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({bool refresh = false}) async {
    if (isLoading || (!refresh && products.isNotEmpty)) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      products = await _service.fetchProducts();
      if (products.isEmpty) {
        errorMessage = 'Mağazada şu anda görüntülenecek ürün bulunamadı.';
      }
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Ürün kataloğu yüklenemedi.',
        name: 'ucuzgetir.catalog',
        error: error,
        stackTrace: stackTrace,
      );
      errorMessage = 'Ürün kataloğu yüklenemedi. İnternet bağlantınızı kontrol edip yeniden deneyin.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
