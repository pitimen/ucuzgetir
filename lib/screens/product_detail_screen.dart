import 'package:flutter/material.dart';

import '../models/store_product.dart';
import '../services/favorites_store.dart';
import 'store_web_view_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    required this.product,
    required this.favorites,
    super.key,
  });

  final StoreProduct product;
  final FavoritesStore favorites;

  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      await favorites.toggle(product.id);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favori değişikliği kaydedilemedi. Yeniden deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    final canDisplayImage =
        imageUrl != null && !imageUrl.path.toLowerCase().endsWith('.svg');

    return Scaffold(
      appBar: AppBar(title: const Text('Ürün detayı')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 280,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: canDisplayImage
                    ? Image.network(
                        imageUrl.toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const _DetailPlaceholder(),
                      )
                    : const _DetailPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Stok kodu: ${product.id}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            product.formattedPrice,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          const Text(
            'Fiyat ve stok bilgisi üyeliğinize ve sipariş anındaki duruma göre değişebilir; kesin tutar mağazada gösterilir.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: favorites,
            builder: (context, _) {
              final isFavorite = favorites.contains(product.id);
              return OutlinedButton.icon(
                onPressed: () => _toggleFavorite(context),
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                label: Text(
                  isFavorite ? 'Favorilerimden çıkar' : 'Favorilerime ekle',
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => StoreWebViewScreen(
                    initialUrl: product.productUrl,
                    title: 'Mağazada ürünü aç',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('Mağazada görüntüle ve sepete ekle'),
          ),
        ],
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.shopping_basket_outlined,
        size: 72,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
      ),
    );
  }
}
