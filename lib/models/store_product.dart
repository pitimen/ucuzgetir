class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.productUrl,
    required this.imageUrl,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final Uri productUrl;
  final Uri? imageUrl;
  final double? price;

  static double? parsePrice(String value) {
    final match = RegExp(r'^\s*(\d+(?:[.,]\d{1,2})?)').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  String get formattedPrice {
    final value = price;
    if (value == null) return 'Fiyatı mağazada görüntüleyin';
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ₺';
  }
}
