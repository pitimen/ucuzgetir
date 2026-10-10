import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  static const String _storageKey = 'favorite_product_ids';

  final Set<String> _productIds = <String>{};
  Set<String> get productIds => Set.unmodifiable(_productIds);
  bool isLoading = true;
  String? errorMessage;
  Future<void>? _loadFuture;

  bool contains(String productId) => _productIds.contains(productId);

  Future<void> load({bool retry = false}) {
    if (retry) {
      _loadFuture = null;
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    return _loadFuture ??= _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    errorMessage = null;
    try {
      final preferences = await SharedPreferences.getInstance();
      _productIds
        ..clear()
        ..addAll(preferences.getStringList(_storageKey) ?? const []);
    } catch (error, stackTrace) {
      developer.log(
        'Favoriler yüklenemedi.',
        name: 'ucuzgetir.favorites',
        error: error,
        stackTrace: stackTrace,
      );
      errorMessage = 'Favoriler bu cihazda yüklenemedi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(String productId) async {
    if (isLoading) await load();
    if (errorMessage != null) {
      throw Exception('Favoriler yüklenemedi.');
    }

    final wasFavorite = _productIds.contains(productId);
    if (wasFavorite) {
      _productIds.remove(productId);
    } else {
      _productIds.add(productId);
    }
    errorMessage = null;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(
        _storageKey,
        _productIds.toList()..sort(),
      );
      if (!saved) throw Exception('Favoriler cihaza kaydedilemedi.');
    } catch (error, stackTrace) {
      if (wasFavorite) {
        _productIds.add(productId);
      } else {
        _productIds.remove(productId);
      }
      errorMessage = 'Favoriler kaydedilemedi. Lütfen yeniden deneyin.';
      developer.log(
        'Favoriler kaydedilemedi.',
        name: 'ucuzgetir.favorites',
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
      rethrow;
    }
  }
}
