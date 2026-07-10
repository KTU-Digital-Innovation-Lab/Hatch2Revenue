/// An owner-priced feed type. Workers pick from these when logging
/// feed — the cost is computed from [pricePerBag] and cannot be
/// entered by hand, so recorded spend always matches official prices.
class FeedCatalogItem {
  final String id;
  final String feedName;
  final double pricePerBag;
  final double kgPerBag;
  final double? marketMin;
  final double? marketMax;

  const FeedCatalogItem({
    required this.id,
    required this.feedName,
    required this.pricePerBag,
    required this.kgPerBag,
    this.marketMin,
    this.marketMax,
  });

  factory FeedCatalogItem.fromMap(Map<String, dynamic> map) {
    double? d(v) => v == null ? null : (v as num).toDouble();
    return FeedCatalogItem(
      id: map['id'] as String,
      feedName: (map['feedName'] ?? map['feed_name']) as String,
      pricePerBag: d(map['pricePerBag'] ?? map['price_per_bag'])!,
      kgPerBag: d(map['kgPerBag'] ?? map['kg_per_bag']) ?? 50,
      marketMin: d(map['marketMin'] ?? map['market_min']),
      marketMax: d(map['marketMax'] ?? map['market_max']),
    );
  }

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'feedName': feedName,
        'pricePerBag': pricePerBag,
        'kgPerBag': kgPerBag,
        'marketMin': marketMin,
        'marketMax': marketMax,
      };
}
