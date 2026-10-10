import 'package:flutter/material.dart';

import '../models/store_product.dart';
import '../services/favorites_store.dart';
import '../services/product_catalog_service.dart';
import 'barcode_scanner_screen.dart';
import 'product_detail_screen.dart';
import 'store_web_view_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    required this.controller,
    required this.favorites,
    required this.favoritesOnly,
    super.key,
  });

  final ProductCatalogController controller;
  final FavoritesStore favorites;
  final bool favoritesOnly;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;

    final value = code.trim();
    setState(() {
      _query = value;
      _searchController.text = value;
    });

    final match = widget.controller.products.where(
      (product) => product.id.toLowerCase() == value.toLowerCase(),
    );
    if (match.isNotEmpty) {
      _openProduct(match.first);
    }
  }

  void _openProduct(StoreProduct product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductDetailScreen(product: product, favorites: widget.favorites),
      ),
    );
  }

  Future<void> _searchStoreForBarcode() async {
    final uri = Uri.https('www.ucuzgetir.com', '/Default.aspx', {
      'urunadi': _searchController.text.trim(),
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoreWebViewScreen(initialUrl: uri, title: 'Mağazada ara'),
      ),
    );
  }

  Future<void> _toggleFavorite(StoreProduct product) async {
    try {
      await widget.favorites.toggle(product.id);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favori değişikliği kaydedilemedi. Yeniden deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.favoritesOnly ? 'Favorilerim' : 'Ürün kataloğu';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!widget.favoritesOnly)
            IconButton(
              tooltip: 'Barkod tara',
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.favoritesOnly
                    ? 'Favorilerimde ara'
                    : 'Ürün veya stok kodu ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              if (widget.controller.isLoading &&
                  widget.controller.products.isEmpty) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              return const SizedBox(height: 2);
            },
          ),
          AnimatedBuilder(
            animation: Listenable.merge([widget.controller, widget.favorites]),
            builder: (context, _) {
              final controllerError = widget.controller.errorMessage;
              if (controllerError != null &&
                  widget.controller.products.isNotEmpty) {
                return MaterialBanner(
                  content: Text(
                    '$controllerError Gösterilen fiyatlar yenilenmemiş olabilir.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => widget.controller.load(refresh: true),
                      child: const Text('Yeniden dene'),
                    ),
                  ],
                );
              }

              final favoritesError = widget.favorites.errorMessage;
              if (widget.favoritesOnly && favoritesError != null) {
                return MaterialBanner(
                  content: Text(favoritesError),
                  actions: [
                    TextButton(
                      onPressed: () => widget.favorites.load(retry: true),
                      child: const Text('Yeniden dene'),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                widget.controller,
                widget.favorites,
              ]),
              builder: (context, _) => _buildProductList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context) {
    final controller = widget.controller;
    if (controller.products.isEmpty) {
      return _messageList(
        context,
        icon: controller.errorMessage == null
            ? Icons.inventory_2_outlined
            : Icons.cloud_off_outlined,
        message:
            controller.errorMessage ??
            (controller.isLoading ? 'Ürünler yükleniyor…' : 'Ürün bulunamadı.'),
        actionLabel: controller.errorMessage == null ? null : 'Yeniden dene',
        onAction: controller.errorMessage == null
            ? null
            : () => controller.load(refresh: true),
      );
    }

    final normalizedQuery = _normalize(_query.trim());
    final favoriteIds = widget.favorites.productIds;
    final products = controller.products.where((product) {
      if (widget.favoritesOnly && !favoriteIds.contains(product.id)) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      return _normalize(product.name).contains(normalizedQuery) ||
          product.id.toLowerCase().contains(normalizedQuery);
    }).toList();

    if (products.isEmpty) {
      final noFavorites =
          widget.favoritesOnly &&
          favoriteIds.isEmpty &&
          normalizedQuery.isEmpty;
      return _messageList(
        context,
        icon: noFavorites ? Icons.favorite_border : Icons.search_off,
        message: noFavorites
            ? 'Kaydettiğiniz ürünler burada görünür.'
            : 'Aramanızla eşleşen ürün bulunamadı.',
        actionLabel: !widget.favoritesOnly && _query.trim().isNotEmpty
            ? 'Mağazada bu kodla ara'
            : null,
        onAction: !widget.favoritesOnly && _query.trim().isNotEmpty
            ? _searchStoreForBarcode
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.load(refresh: true),
      child: CustomScrollView(
        key: PageStorageKey<String>(
          widget.favoritesOnly ? 'favorite-products' : 'all-products',
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 900 ? 4 : (width >= 580 ? 3 : 2);

                return SliverGrid.builder(
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 258,
                  ),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCard(
                      product: product,
                      isFavorite: widget.favorites.contains(product.id),
                      onTap: () => _openProduct(product),
                      onFavoriteTap: () => _toggleFavorite(product),
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'Fiyat ve stok bilgisi, üyeliğinize ve sipariş anındaki duruma göre değişebilir. Kesin tutar mağazada gösterilir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList(
    BuildContext context, {
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: Colors.black45),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final StoreProduct product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    final canDisplayImage =
        imageUrl != null && !imageUrl.path.toLowerCase().endsWith('.svg');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: canDisplayImage
                        ? Image.network(
                            imageUrl.toString(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const _ProductPlaceholder(),
                          )
                        : const _ProductPlaceholder(),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      tooltip: isFavorite
                          ? 'Favorilerden çıkar'
                          : 'Favorilere ekle',
                      onPressed: onFavoriteTap,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.formattedPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.shopping_basket_outlined,
        size: 44,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
      ),
    );
  }
}
